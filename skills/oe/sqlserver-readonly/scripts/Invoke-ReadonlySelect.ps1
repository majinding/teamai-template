param(
    [Parameter(Mandatory = $true)]
    [string]$ServerInstance,

    [Parameter(Mandatory = $true)]
    [string]$Database,

    [Parameter(Mandatory = $true)]
    [string]$Query,

    [ValidateRange(1, 1000)]
    [int]$MaxRows = 20,

    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 30,

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

function ConvertTo-SafeSelect {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Sql
    )

    $statement = $Sql.Trim()
    if ([string]::IsNullOrWhiteSpace($statement)) {
        throw "Query is required."
    }

    if ($statement -match '(?s)--|/\*|\*/') {
        throw "SQL comments are not supported."
    }

    if ($statement.EndsWith(";")) {
        $statement = $statement.Substring(0, $statement.Length - 1).TrimEnd()
    }
    if ($statement.Contains(";")) {
        throw "Only one SQL statement is allowed."
    }

    $scanText = [regex]::Replace($statement, "(?is)N?'(?:''|[^'])*'", "''")
    if ($scanText -notmatch '(?is)^\s*SELECT\b') {
        throw "Only a single SELECT statement is allowed."
    }

    $blocked = '(?i)\b(INSERT|UPDATE|DELETE|MERGE|EXEC|EXECUTE|ALTER|CREATE|DROP|TRUNCATE|GRANT|REVOKE|DENY|DBCC|BACKUP|RESTORE|USE|SET|WAITFOR|INTO|OPENROWSET|OPENDATASOURCE|OPENQUERY|BULK|SHUTDOWN|KILL|BEGIN|COMMIT|ROLLBACK|UNION|EXCEPT|INTERSECT|APPLY|PIVOT|UNPIVOT)\b'
    $blockedMatch = [regex]::Match($scanText, $blocked)
    if ($blockedMatch.Success) {
        throw "Blocked SQL keyword: $($blockedMatch.Value)."
    }

    if ($scanText -match '(?is)\b(?:FROM|JOIN)\s*\(') {
        throw "Derived tables and subqueries are not supported."
    }

    $identifier = '(?:\[[^\]]+\]|[A-Za-z_#][A-Za-z0-9_#$@]*)'
    $objectName = "$identifier(?:\s*\.\s*$identifier){0,2}"
    $sourcePattern = "(?i)(?<keyword>\b(?:FROM|JOIN)\s+)(?<object>$objectName)(?<hint>\s+WITH\s*\(\s*NOLOCK\s*\))?"
    $sourceMatches = [regex]::Matches($scanText, $sourcePattern)
    $sourceKeywords = [regex]::Matches($scanText, '(?i)\b(?:FROM|JOIN)\b')

    if ($sourceMatches.Count -ne $sourceKeywords.Count) {
        throw "Only simple FROM/JOIN table references are supported."
    }

    if ($scanText -match "(?is)\bFROM\s+$objectName(?:\s+(?:AS\s+)?$identifier)?\s*,") {
        throw "Comma-separated table sources are not supported; use explicit JOIN."
    }

    foreach ($match in $sourceMatches) {
        $afterObject = $scanText.Substring($match.Groups["object"].Index + $match.Groups["object"].Length)
        if ($afterObject -match '^\s*\(') {
            throw "Table-valued functions are not supported."
        }
        if (-not $match.Groups["hint"].Success -and $afterObject -match '^\s+WITH\s*\(') {
            throw "Only WITH (NOLOCK) table hints are supported."
        }
    }

    return [regex]::Replace(
        $statement,
        $sourcePattern,
        {
            param($match)
            if ($match.Groups["hint"].Success) {
                return $match.Value
            }
            return $match.Groups["keyword"].Value + $match.Groups["object"].Value + " WITH (NOLOCK)"
        }
    )
}

$safeQuery = ConvertTo-SafeSelect -Sql $Query

if ($ValidateOnly) {
    [ordered]@{
        valid = $true
        rewrittenQuery = $safeQuery
        maxRows = $MaxRows
        timeoutSeconds = $TimeoutSeconds
    } | ConvertTo-Json -Depth 4
    exit 0
}

Add-Type -AssemblyName System.Data

$connectionString = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$connectionString["Data Source"] = $ServerInstance
$connectionString["Initial Catalog"] = $Database
$connectionString["Integrated Security"] = $true
$connectionString["ApplicationIntent"] = "ReadOnly"
$connectionString["Encrypt"] = $true
$connectionString["TrustServerCertificate"] = $true
$connectionString["Application Name"] = "sqlserver-readonly"
$connectionString["Connect Timeout"] = 15

$connection = New-Object System.Data.SqlClient.SqlConnection($connectionString.ConnectionString)
$command = $connection.CreateCommand()
$reader = $null

try {
    $connection.Open()
    $command.CommandText = $safeQuery
    $command.CommandTimeout = $TimeoutSeconds
    $reader = $command.ExecuteReader()

    $rows = New-Object System.Collections.Generic.List[object]
    $truncated = $false

    while ($reader.Read()) {
        if ($rows.Count -ge $MaxRows) {
            $truncated = $true
            break
        }

        $item = [ordered]@{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            $name = $reader.GetName($i)
            if ([string]::IsNullOrWhiteSpace($name)) {
                $name = "Column$i"
            }
            if ($item.Contains($name)) {
                $name = "${name}_$i"
            }
            $item[$name] = if ($reader.IsDBNull($i)) { $null } else { $reader.GetValue($i) }
        }
        [void]$rows.Add([pscustomobject]$item)
    }

    [ordered]@{
        serverInstance = $ServerInstance
        database = $Database
        rowCount = $rows.Count
        maxRows = $MaxRows
        truncated = $truncated
        rewrittenQuery = $safeQuery
        rows = $rows
    } | ConvertTo-Json -Depth 10
}
finally {
    if ($null -ne $reader) {
        $reader.Dispose()
    }
    $command.Dispose()
    if ($connection.State -ne [System.Data.ConnectionState]::Closed) {
        $connection.Close()
    }
    $connection.Dispose()
}

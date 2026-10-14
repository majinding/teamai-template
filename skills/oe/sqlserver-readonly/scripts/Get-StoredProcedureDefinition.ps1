param(
    [Parameter(Mandatory = $false)]
    [string]$ServerInstance = $env:XXL_JOB_SQLSERVER_INSTANCE,

    [Parameter(Mandatory = $true)]
    [string]$Database,

    [Parameter(Mandatory = $true)]
    [string]$Schema,

    [Parameter(Mandatory = $true)]
    [string]$Procedure
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ServerInstance)) {
    throw "SQL Server instance is required. Pass -ServerInstance or set XXL_JOB_SQLSERVER_INSTANCE."
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

function Invoke-MetadataQuery {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandText
    )

    $command = $connection.CreateCommand()
    try {
        $command.CommandText = $CommandText
        $command.CommandTimeout = 30
        [void]$command.Parameters.Add("@schema", [System.Data.SqlDbType]::NVarChar, 128)
        [void]$command.Parameters.Add("@procedure", [System.Data.SqlDbType]::NVarChar, 128)
        $command.Parameters["@schema"].Value = $Schema
        $command.Parameters["@procedure"].Value = $Procedure

        $table = New-Object System.Data.DataTable
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
        try {
            [void]$adapter.Fill($table)
        }
        finally {
            $adapter.Dispose()
        }
        return ,$table
    }
    finally {
        $command.Dispose()
    }
}

try {
    $connection.Open()

    $definitionRows = Invoke-MetadataQuery -CommandText @"
SELECT
    s.name AS schema_name,
    p.name AS procedure_name,
    m.definition
FROM sys.procedures AS p
INNER JOIN sys.schemas AS s ON s.schema_id = p.schema_id
LEFT JOIN sys.sql_modules AS m ON m.object_id = p.object_id
WHERE s.name = @schema
  AND p.name = @procedure;
"@

    if ($definitionRows.Rows.Count -eq 0) {
        throw "Stored procedure [$Schema].[$Procedure] was not found in database [$Database] on [$ServerInstance]."
    }

    $definitionRow = $definitionRows.Rows[0]
    if ($definitionRow.IsNull("definition")) {
        throw "Stored procedure [$Schema].[$Procedure] is encrypted or VIEW DEFINITION permission is unavailable."
    }

    $parameterRows = Invoke-MetadataQuery -CommandText @"
SELECT
    prm.parameter_id,
    prm.name,
    TYPE_NAME(prm.user_type_id) AS data_type,
    prm.max_length,
    prm.precision,
    prm.scale,
    prm.is_output,
    prm.has_default_value,
    prm.default_value
FROM sys.procedures AS p
INNER JOIN sys.schemas AS s ON s.schema_id = p.schema_id
INNER JOIN sys.parameters AS prm ON prm.object_id = p.object_id
WHERE s.name = @schema
  AND p.name = @procedure
ORDER BY prm.parameter_id;
"@

    $dependencyRows = Invoke-MetadataQuery -CommandText @"
SELECT DISTINCT
    COALESCE(dep.referenced_database_name, DB_NAME()) AS database_name,
    dep.referenced_schema_name AS schema_name,
    dep.referenced_entity_name AS entity_name,
    obj.type_desc AS object_type
FROM sys.procedures AS p
INNER JOIN sys.schemas AS s ON s.schema_id = p.schema_id
INNER JOIN sys.sql_expression_dependencies AS dep
    ON dep.referencing_id = p.object_id
LEFT JOIN sys.objects AS obj
    ON obj.object_id = dep.referenced_id
WHERE s.name = @schema
  AND p.name = @procedure
  AND dep.referenced_entity_name IS NOT NULL
ORDER BY database_name, schema_name, entity_name;
"@

    $parameters = @(
        foreach ($row in $parameterRows.Rows) {
            [ordered]@{
                position = [int]$row.parameter_id
                name = [string]$row.name
                dataType = [string]$row.data_type
                maxLength = [int]$row.max_length
                precision = [int]$row.precision
                scale = [int]$row.scale
                isOutput = [bool]$row.is_output
                hasDefaultValue = [bool]$row.has_default_value
                defaultValue = if ($row.IsNull("default_value")) { $null } else { $row.default_value }
            }
        }
    )

    $dependencies = @(
        foreach ($row in $dependencyRows.Rows) {
            [ordered]@{
                database = [string]$row.database_name
                schema = if ($row.IsNull("schema_name")) { $null } else { [string]$row.schema_name }
                entity = [string]$row.entity_name
                objectType = if ($row.IsNull("object_type")) { $null } else { [string]$row.object_type }
            }
        }
    )

    [ordered]@{
        serverInstance = $ServerInstance
        database = $Database
        schema = [string]$definitionRow.schema_name
        procedure = [string]$definitionRow.procedure_name
        parameters = $parameters
        dependencies = $dependencies
        definition = [string]$definitionRow.definition
    } | ConvertTo-Json -Depth 8
}
finally {
    if ($connection.State -ne [System.Data.ConnectionState]::Closed) {
        $connection.Close()
    }
    $connection.Dispose()
}

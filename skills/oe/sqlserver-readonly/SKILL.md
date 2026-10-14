---
name: sqlserver-readonly
description: Read SQL Server metadata or run a constrained read-only SELECT using Windows integrated authentication. Use when the user asks to inspect stored procedures, parameters, dependencies, tables, views, or query data without modification, and when another skill needs verified SQL Server definitions.
argument-hint: "[Bean 名] [SP 名或 SELECT 查询]"
---

# SQL Server 只读查询

仅执行元数据读取和受限 SELECT。连接失败、权限不足或查询不满足只读规则时停止，不使用本地脚本替代数据库事实。

## 实例映射

| Bean 实例代码 | SQL Server 地址 |
|---|---|
| `OE` | `WIN-4VHK4HHRC0G.ebz-chn-qa.mkaws.com,602` |
| `OL` | `WIN-VCDGMIK6PCC.ebz-chn-qa.mkaws.com,604` |
| `FL` | `WIN-9C2M0S9L4DE.ebz-chn-qa.mkaws.com,606` |
| `FO` | `WIN-OJPFSKN352P.ebz-chn-qa.mkaws.com,607` |
| `DM` | `WIN-7KF3FO9MJUE.ebz-chn-qa.mkaws.com,608` |

按 `sqlserver-{实例代码}-{数据库名}` 解析 Bean 名：

- 实例代码通过上表解析 SQL Server 地址。
- 第二个连字符后的完整后缀是数据库名。
- 示例：`sqlserver-OE-BASKET` 对应 `WIN-4VHK4HHRC0G.ebz-chn-qa.mkaws.com,602` 的 `BASKET` 数据库。
- 用户明确提供的服务器或数据库优先；格式或实例代码无法识别时询问用户。

## 使用示例

根据 Bean 名查询 SP 定义、参数和依赖对象：

```text
/sqlserver-readonly 查询 sqlserver-OE-BASKET 中
dbo.uspOrderProcessingOrderValidationMaster 的定义、参数和依赖对象
```

查询表数据：

```text
/sqlserver-readonly 在 sqlserver-OE-BASKET 执行只读查询：
SELECT OrderId, DtInserted
FROM dbo.OrderAsyncTracker
ORDER BY DtInserted
```

查询两个表：

```text
/sqlserver-readonly 在 sqlserver-OE-BASKET 查询：
SELECT o.OrderId, c.CustomerId
FROM dbo.Orders o
INNER JOIN dbo.Customers c ON c.CustomerId = o.CustomerId
WHERE o.OrderId = '00000000-0000-0000-0000-000000000000'
```

预期行为：

- 自动将 `sqlserver-OE-BASKET` 解析为 OE 地址和 `BASKET` 数据库。
- SP 查询只读取定义，不执行 SP。
- SELECT 中的 `FROM` 和 `JOIN` 表自动追加 `WITH (NOLOCK)`。
- SELECT 默认最多返回 20 行，30 秒超时。
- 写操作、执行 SP、多语句和不支持的复杂查询会被拒绝。

## 安全边界

- 使用 Windows 集成认证、`ApplicationIntent=ReadOnly` 和参数化元数据查询。
- 不接收、保存或输出密码和连接字符串。
- 只允许元数据查询或单条简单 `SELECT`。
- 自定义 SELECT 默认最多返回 20 行，超时 30 秒。
- 自定义 SELECT 中的每个 `FROM`/`JOIN` 表由脚本自动追加 `WITH (NOLOCK)`。
- 拒绝多语句、注释、CTE、派生表、表值函数、逗号连接、`SELECT INTO`、DML、DDL、EXEC、事务及管理命令。
- 不执行用户提供的存储过程，即使名称看起来只读；仅查询其定义。

## 查询 SP 元数据

调用：

```powershell
& "<skill-dir>\scripts\Get-StoredProcedureDefinition.ps1" `
  -ServerInstance "<hostname,port>" `
  -Database "<database>" `
  -Schema "<schema>" `
  -Procedure "<procedure>"
```

结果包含：

- 按声明顺序排列的参数
- `sys.sql_expression_dependencies` 返回的依赖对象
- `sys.sql_modules` 返回的完整定义

依赖对象只用于发现范围；具体 `SELECT`、`INSERT`、`UPDATE`、`DELETE` 操作必须从 SP 定义判断。

## 查询元数据或业务数据

调用：

```powershell
& "<skill-dir>\scripts\Invoke-ReadonlySelect.ps1" `
  -ServerInstance "<hostname,port>" `
  -Database "<database>" `
  -Query "SELECT ..." `
  -MaxRows 20 `
  -TimeoutSeconds 30
```

编写简单查询并使用显式 `JOIN`，不要自行添加 NOLOCK；脚本会统一追加。需要 CTE、子查询、表值函数或其他复杂 SQL 时停止，并说明当前安全解析器不支持该查询。

## 完成标准

- 已解析并报告服务器地址与数据库。
- 查询来自 SQL Server，而不是本地缓存。
- SP 参数顺序、定义和依赖均来自同一次目标数据库查询。
- SELECT 输出不超过指定行数，并说明是否因行数限制被截断。
- 错误原样保留关键原因，但不暴露凭据或完整连接字符串。

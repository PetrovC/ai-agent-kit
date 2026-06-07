# Database — SQL Server / T-SQL Reference

## Load when

Load this reference when:
- Task targets Microsoft SQL Server / Azure SQL specifically (not generic SQL).
- Task text mentions: SQL Server, T-SQL, MSSQL, `sqlcmd`, SSMS, Azure SQL,
  stored procedure, clustered index, `MERGE`, `OUTPUT`, deadlock, isolation level.
- Changed files match `**/*.sql` and the change also carries a `dotnet`/EF Core
  signal (`**DbContext*.cs`, `**/Migrations/**`, `*.csproj` referencing
  `Microsoft.EntityFrameworkCore.SqlServer`).

---

## T-SQL specifics

- Identifiers quote with `[brackets]`, not double quotes (unless
  `QUOTED_IDENTIFIER ON`). String literals use single quotes.
- Prefer `OFFSET ... FETCH NEXT ... ROWS ONLY` for paging over `TOP` + subquery.
- `MERGE` is concise but has well-known correctness/concurrency footguns; for
  upserts prefer an explicit `UPDATE` then `INSERT ... WHERE NOT EXISTS` inside a
  transaction, or `INSERT ... ON ... ` patterns guarded by a unique index.
- Use `OUTPUT` / `OUTPUT INTO` to capture affected rows instead of a second query.
- Datatypes: prefer `datetime2`/`datetimeoffset` over legacy `datetime`;
  `decimal(p,s)` for money (never `float`); `nvarchar` for Unicode text and avoid
  `nvarchar(max)` in indexed/filterable columns.
- Always set `SET NOCOUNT ON` at the top of stored procedures and batches.

## Indexing and locking

- One **clustered** index per table — usually the primary key, but choose a
  narrow, ever-increasing key (e.g. identity/sequence) to avoid page splits.
- Add **nonclustered** indexes on foreign keys, frequent filter/join columns;
  use `INCLUDE` columns to make covering indexes instead of widening the key.
- Watch for implicit conversions (e.g. `nvarchar` param vs `varchar` column) —
  they silently disable index seeks. Match parameter types to column types.
- Default isolation is `READ COMMITTED` (lock-based). Enable
  `READ_COMMITTED_SNAPSHOT` (RCSI) to cut reader/writer blocking; understand the
  `tempdb` version-store cost before flipping it in production.
- Resolve deadlocks by accessing objects in a consistent order and keeping
  transactions short; inspect with the `system_health` extended-events session.

## EF Core ↔ SQL Server

- Provider package: `Microsoft.EntityFrameworkCore.SqlServer`. Configure with
  `options.UseSqlServer(connectionString)` (see also the
  [`dotnet/references/ef-core.md`](../../dotnet/references/ef-core.md) rules on
  layering and `AsNoTracking`).
- Map keys to `IDENTITY` by default; for client-generated keys prefer sequential
  GUIDs (`NEWSEQUENTIALID()` / a sequential-GUID generator) to avoid index
  fragmentation from random `uniqueidentifier` values.
- Use `HasColumnType("decimal(18,2)")` for money columns — the default mapping
  truncates and warns.
- Concurrency: add a `rowversion`/`timestamp` column mapped with
  `.IsRowVersion()` for optimistic concurrency.
- Connection strings belong in configuration/secrets, never in source — prefer
  Azure AD / managed-identity auth over SQL logins where available.

## Migrations

```bash
# SQL Server provider; same dotnet-ef workflow as the EF Core reference
dotnet ef migrations add <Name> --project src/Infrastructure --startup-project src/Api
dotnet ef migrations script --idempotent --output migrate.sql   # review before prod
```

- Always generate an `--idempotent` script and review it before applying to a
  shared/production database.
- Index creation on large tables: use `WITH (ONLINE = ON)` (Enterprise/Azure SQL)
  to avoid long blocking; otherwise schedule during a maintenance window.
- Keep migrations transactional; SQL Server DDL is transactional, so a failed
  batch rolls back cleanly.

## Common pitfalls

- Scalar user-defined functions in `WHERE`/`SELECT` serialize execution and kill
  performance — inline the logic or use an inline TVF.
- Parameter sniffing: a cached plan tuned for one parameter regresses for others;
  mitigate with `OPTIMIZE FOR`, `RECOMPILE`, or query-store plan forcing.
- `SELECT *` in views/procs breaks covering indexes and `SchemaBinding`; list
  columns explicitly.
- Leaving the default `varchar`/`nvarchar` length (1) when omitted in `CAST`/
  `DECLARE` silently truncates strings.
- Running cross-database/cross-collation joins without an explicit `COLLATE`
  clause raises collation-conflict errors.

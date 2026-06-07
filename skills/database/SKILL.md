---
name: database
description: >
  Use when modifying SQL or NoSQL schemas, migrations, queries, indexes,
  data access layers, transactions, or anything touching persistence.
  Covers Postgres, MySQL, SQLite, MongoDB, Redis, and ORM patterns
  (EF Core, Prisma, SQLAlchemy, sqlx, Drizzle, TypeORM, GORM).
paths:
  - "**/*.sql"
  - "**/migrations/**"
  - "**/schema.prisma"
  - "**/prisma/**"
keywords:
  - sql server
  - t-sql
  - mssql
  - sqlcmd
  - azure sql
allowed-tools:
  - "Bash(psql:*)"
  - "Bash(mysql:*)"
  - "Bash(sqlite3:*)"
  - "Bash(redis-cli:*)"
  - "Bash(mongosh:*)"
version: "1.0.0"
---

# Database Skill

## Goal
Persistence that is safe under load, evolves without downtime, and doesn't
surprise the team six months later. Schema is a contract: changes are
versioned, reviewed, and reversible.

## Quick reference

| Concept | Best practice |
|---|---|
| Schema | Normalise to 3NF, choose correct types, use UUIDs/ULIDs for public IDs |
| Indexes | Add indexes on foreign keys, filter fields, and join columns; avoid over-indexing |
| ORM | Avoid N+1 query patterns, use eager loading, run migrations in transactions |
| Key commands | Postgres: `EXPLAIN ANALYZE <query>`, `pg_dump -U <user> -d <db>` |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

## References

Load these only when signals justify it:

| Reference | Load when |
|---|---|
| [`references/sql-server.md`](references/sql-server.md) | Task targets Microsoft SQL Server / Azure SQL specifically. Task text mentions SQL Server, T-SQL, MSSQL, `sqlcmd`, stored procedure, clustered index, deadlock, isolation level. `**/*.sql` changes carrying an EF Core / `dotnet` signal. |

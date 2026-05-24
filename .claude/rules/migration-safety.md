---
paths:
  - "**/migrations/**"
  - "**/*.migration.*"
  - "**/*.sql"
  - "**/schema.prisma"
  - "**/flyway/**"
  - "**/liquibase/**"
---
# Database migration rules

Every migration must be reversible (has a `Down` / rollback).

Rules:
- Never DROP a column or table without a preceding migration that stops writing to it.
- Never rename a column in one step — add new, migrate data, drop old (3 separate migrations).
- Add indexes `CONCURRENTLY` (Postgres) to avoid table locks in production.
- Never change a column from nullable to NOT NULL without a default or backfill migration.
- Migrations run in CI — they must complete in < 30 s on an empty database.
- Never embed application logic in a migration; migrations are structural only.
- If a migration is irreversible, add a comment `-- IRREVERSIBLE: <reason>` and get explicit approval.

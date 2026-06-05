# Database Skill — Deep Reference

> Loaded on demand. The slim [`SKILL.md`](SKILL.md) covers the quick reference.

## Universal principles

- **Schema in version control.** Every change is a migration file, not a console click.
- **Migrations are append-only.** Don't rewrite history once shipped.
- **Backups exist and are tested.** A backup nobody has restored is not a backup.
- **One service owns one schema.** Cross-service joins are a smell — use APIs or events.
- **Plan for nulls.** Every nullable column needs an answer: what does null mean here?

---

## Relational schema design

- Use the right types: `uuid` for IDs (not `varchar(36)`), `timestamptz` for timestamps (not `timestamp`), `numeric(10,2)` for money (not `float`).
- `NOT NULL` by default. Justify any nullable column.
- Foreign keys with explicit `ON DELETE` / `ON UPDATE` behavior.
- Constraints in the DB, not just in the app: `CHECK (status IN ('pending','active','archived'))`, `UNIQUE`, partial indexes.
- Naming: `snake_case` for tables and columns. Plural table names (`users`, `orders`) or singular (`user`, `order`) — pick one per project and stick.
- Add `created_at`, `updated_at` (with trigger or app-level) to every "real" entity.

---

## Indexes

- **Every foreign key needs an index.** Most engines don't auto-create one.
- **Index for the query, not the column.** A composite index `(user_id, created_at DESC)` is for a specific query pattern.
- Partial indexes for selective predicates: `CREATE INDEX ... WHERE archived = false`.
- Don't index everything — every index is a write penalty and storage cost.
- Measure with `EXPLAIN ANALYZE` (Postgres) / `EXPLAIN` (MySQL) before and after.

---

## Postgres (recommended default)

- Use the JSON capabilities: `jsonb` for flexible blobs, with `GIN` indexes on queried paths.
- Use the constraint system fully: `EXCLUDE` constraints for ranges, partial unique indexes for soft-delete patterns.
- Connection pooling: PgBouncer in front of Postgres for high-concurrency services.
- `SERIALIZABLE` isolation is rarely needed — `READ COMMITTED` is the default for a reason.
- For full-text search: built-in `tsvector` is enough for many cases — reach for Elasticsearch / Meilisearch only when you've outgrown it.

---

## MySQL / MariaDB

- Use `InnoDB` (default). Avoid `MyISAM` — no transactions, no FKs.
- Set `sql_mode = STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION` minimum — silent truncations are bugs.
- `utf8mb4` everywhere — never `utf8` (which is 3-byte and breaks emojis).
- Be aware of differences from Postgres: `LIMIT/OFFSET` semantics, JSON support is weaker, no partial indexes.

---

## SQLite

- Fine for desktop apps, embedded use, tests, very small services.
- Single writer at a time — high write concurrency is not its strength.
- Enable foreign keys explicitly per connection: `PRAGMA foreign_keys = ON;`.
- Don't use it for tests of code that targets Postgres — type behavior differs (booleans, dates, locking).

---

## MongoDB

- Schema-less ≠ schema-free. Define a schema in the application layer (Mongoose, Zod, Pydantic) and validate writes.
- **Design around access patterns, not entities.** Embed when always read together; reference when independent.
- Indexes are critical — `db.collection.explain()` to verify.
- Use transactions for multi-document operations that need consistency (replica set / sharded cluster required).
- Avoid massive arrays in a document — unbounded growth = pain.
- Avoid hot-key writes — sharding distributes by the shard key.

---

## Redis

- Treat as a **cache or fast key-value store**, not a primary database (unless you've designed for persistence + failover).
- Set TTLs on cache keys — unbounded keys are a leak.
- Use the right data structure: `STRING` (counters, cached blobs), `HASH` (small objects), `SET`/`ZSET` (membership, sorted leaderboards), `STREAM` (event queue, fan-out).
- Key naming: `service:entity:id:field` (e.g., `auth:session:abc123:userid`). Predictable, scannable.
- Avoid `KEYS *` in production — use `SCAN`.
- Pipelines / multi-exec for batched writes.

---

## Migrations

### Rules

- **Forward-only by default.** Down migrations are a nice-to-have but rarely safe in production.
- **Backwards-compatible**: app at version N must work with schema at version N AND N+1.
- **Two-step refactors for renames**:
  1. Add the new column, dual-write.
  2. Backfill, switch reads to new column, deploy.
  3. Stop writing to old column.
  4. Drop old column in a later release.
- **Dangerous operations** require a plan:
  - Adding a `NOT NULL` column to a big table → add nullable, backfill, set NOT NULL.
  - Adding an index on a big table → use `CONCURRENTLY` (Postgres) / `ONLINE` (MySQL 8+).
  - Dropping a column → make sure no deployed code reads it. Wait, then drop.
- **Test on a copy of prod** before running on prod.

### Tools per stack

| Stack | Tool |
|---|---|
| .NET | EF Core Migrations |
| Python | Alembic (SQLAlchemy), Django Migrations |
| Node | Prisma Migrate, Drizzle Kit, TypeORM, Knex |
| Go | golang-migrate, sqlc + manual SQL, Atlas |
| Rust | sqlx migrate, sea-orm-migration |
| Multi-stack / DB-first | Atlas, Flyway, Liquibase |

---

## ORM patterns (cross-language)

- **Don't leak the ORM into the domain.** Domain entities are pure; map to/from persistence at the boundary.
- **Repository pattern** is useful only when it adds value (testability, abstraction over the data source). Don't wrap `db.query()` one-for-one.
- **N+1 detection**: every ORM has a way to log queries — enable it in tests and watch for N+1.
- **Read-only queries**: prefer projection (DTO / select specific columns) over loading full entities you don't need.
- **Bulk operations**: don't loop and save one-by-one — use `INSERT ... SELECT` or batch APIs.

### EF Core specifics

- Use repositories or query services defined in Application, implemented in Infrastructure.
- Don't leak `DbContext` into Domain or Application layers.
- Migrations belong in Infrastructure.
- Use explicit `IEntityTypeConfiguration<T>` over data annotations.
- Avoid lazy loading unless explicitly justified.
- Prefer `AsNoTracking()` for read-only queries.

### Prisma / Drizzle specifics

- Keep the schema file as the source of truth. Regenerate the client after every change.
- Avoid using the generated types as your domain types — map to your own.

### SQLAlchemy specifics

- 2.x-style: `Mapped[...]` + `mapped_column()`. Don't mix with 1.x legacy syntax.
- Session per request via dependency injection. Close in `finally`.

### sqlx (Rust) specifics

- Compile-time-checked queries with `query!` / `query_as!` — keeps SQL honest.
- Migrations via `sqlx-cli`. Commit them.

---

## Transactions

- Wrap multi-statement operations that need atomicity in a transaction.
- Keep transactions short. Don't make HTTP calls inside a transaction.
- Use the right isolation level. `READ COMMITTED` is the default for most engines and good enough for most apps.
- For "compare and swap" patterns: optimistic concurrency via a `version` column + `WHERE version = X` predicate, OR `SELECT ... FOR UPDATE`.

---

## Common bugs to flag

- Missing FK index causing slow joins and lock contention.
- N+1 queries from ORM lazy loading — enable eager / explicit joins.
- Timezone bugs: storing local time, comparing against UTC. Use `timestamptz` and always store in UTC.
- Float for money: `numeric` / `decimal` only.
- `SELECT *` in production code: future column additions break consumers and hurt performance.
- Unbounded `IN (...)` clauses with thousands of values — split into chunks or use a temp table.
- Soft delete via a `deleted_at` column without partial indexes — queries become slow as deleted rows accumulate.

---

## What NOT to do

- No string-concatenated SQL with user input. Parameterized queries always.
- No connection per request without pooling — you'll exhaust the server.
- No long-running transactions over external API calls.
- No "I'll add the index later" — add it in the same PR.
- No silent data loss on migration failure — wrap in a transaction where the engine supports it.
- No skipping the integration test that hits a real DB — SQLite-against-Postgres-prod is a footgun.

---

## Verification commands

```bash
# Postgres
psql -d mydb -c '\d+ users'                       # inspect schema
psql -d mydb -c 'EXPLAIN ANALYZE SELECT ...'       # query plan
pg_dump --schema-only mydb > schema.sql            # snapshot schema

# MongoDB
mongosh --eval 'db.users.getIndexes()'
mongosh --eval 'db.users.find({...}).explain("executionStats")'

# Redis
redis-cli --scan --pattern 'auth:*' | head
redis-cli memory usage 'auth:session:abc'

# Migrations (per stack)
dotnet ef migrations add InitialCreate            # .NET
alembic revision --autogenerate -m 'add user'     # Python
pnpm prisma migrate dev --name add-user           # Node (Prisma)
sqlx migrate add add_user                         # Rust
golang-migrate -path migrations -database "$URL" up
```

---

## Final response requirements

Always report:
- Schema / migration files changed.
- Online vs offline operations (any `ALTER TABLE` that locks?).
- Indexes added or removed.
- Rollback plan (especially for destructive ops).
- Data backfill needed and how it was tested.
- Any new dependency (driver, ORM, migration tool): name, version, **license (MIT only — see `dependencies` skill)**.

# Technical Decisions

Append-only log of significant technical decisions.
Each entry is immutable once dated; superseded decisions get a new entry that
references and supersedes the old one.

---

## ADR-001 — PostgreSQL on Supabase (2025-09-12)

**Context**: Need a managed Postgres with auth bundled. Comparing Supabase / Neon / RDS.

**Decision**: Supabase. We get Postgres + Auth + Storage on a single free tier, with EU regions.

**Consequences**: We're tied to Supabase's auth model (JWT signed by Supabase). If we
outgrow free tier we either pay Supabase or migrate Postgres separately.

---

## ADR-002 — CQRS-lite with handler classes, no MediatR (2025-10-04)

**Context**: We need command/query separation but want to avoid the runtime cost
and indirection of MediatR.

**Decision**: Each command / query has a `XxxHandler` class registered in DI.
Endpoints call the handler directly through constructor injection. No `IRequest<T>`,
no behaviors pipeline.

**Consequences**: Less magic, IDE navigation works. We give up cross-cutting
behaviors as MediatR pipelines — we add them explicitly per handler (logging
already done by middleware; validation done with FluentValidation invoked in
the handler entry).

---

## ADR-003 — TanStack Query for server cache; Pinia for UI state only (2025-11-20)

**Context**: Pinia was being used for both. Server cache invalidation was leaky.

**Decision**: TanStack Query owns all server cache. Pinia is for ephemeral UI state
(modal open/closed, current tab, form scratch).

**Consequences**: Simpler invalidation rules. Slight learning curve for the team.
Pinia stores shrunk by ~60%.

---

## ADR-004 — Holidays from built-in calendar code, not a paid feed (2026-04-15)

**Context**: v1.2 needs accurate national holidays for FR / BE / NL / ES / DE.
Considered: paid feed (Nager.Date premium, Calendarific) vs hand-maintained code.

**Decision**: Hand-maintained code. We update each November for the following year.

**Consequences**: Yearly maintenance task on the team. We avoid external dependency
+ latency + privacy concerns. Trade-off acceptable given the small number of countries.

---

## ADR-005 — All times stored as `timestamptz` UTC (2026-04-22)

**Context**: Bug #482 — cross-DST leaves consumed wrong days. Root cause:
inconsistent `timestamp` (no TZ) usage in some columns.

**Decision**: All temporal columns are `timestamptz`. Application code uses
`DateTimeOffset` (backend) and ISO 8601 strings (frontend). Display uses the
workspace's configured timezone.

**Consequences**: Migration `20260422_NormalizeTimestamps` converts existing columns.
Frontend formatters updated. Bug #482 closed.

# Skill & Technology Coverage Matrix

Coverage audit for the ai-agent-kit skill/subskill/subagent surface, requested by
[issue #424](https://github.com/PetrovC/ai-agent-kit/issues/424). It is the
**final expansion-phase audit**: the routing foundation (adaptive routing, skill
metadata schema, offline skill selection, routing regression fixtures, lazy
references, subagent governance, model selection policy) is in place, so this
document decides *what coverage is still missing* without bloating context.

Audited on **2026-06-07** against the skill set in [`skills/`](../../skills).
Re-run when the skill set changes materially, and align with
[ROADMAP.md](./ROADMAP.md) and [PROVIDER_PARITY.md](./PROVIDER_PARITY.md).

## How to read the matrix

Each technology area is rated:

- **Covered** — a skill (or `references/` subskill) handles it well; no action.
- **Covered (distributed)** — handled inside one or more broader skills rather
  than a dedicated skill; intentional, no action.
- **Weak** — present but shallow; candidate for a small lazy-loaded reference,
  not a new broad skill.
- **Missing** — genuine gap; candidate for a reference or (rarely) a new skill.
- **Intentionally unsupported** — deliberately out of scope; documented so it is
  not re-litigated.

Guiding rules from #424 (and `CLAUDE.md`): do **not** add a skill just because a
technology exists; prefer extending existing skills; prefer small lazy-loaded
[`references/`](./SKILL_METADATA.md#the-references-pattern) over broad
always-loaded skills; add subagents only when focused/parallel execution
genuinely helps; every new skill/reference needs activation metadata and routing
fixtures.

## Current skill surface

32 skills under `skills/` (mirrored to `.claude/`, `.agents/`, `.agy/`), most with
a `SKILL.deep.md`; `references/` subskills under `dotnet/` (clean-architecture,
ef-core, package-maintenance, testing) and `release-management/` (edge-cases);
5 subagents (`architect`, `code-reviewer`, `codebase-investigator`,
`security-reviewer`, `test-runner`).

## Matrix

### Backend

| Area | Status | Where | Action |
|---|---|---|---|
| .NET / C# / ASP.NET Core | Covered | `dotnet` | None |
| EF Core | Covered | `dotnet/references/ef-core` | None |
| Java / Kotlin (Spring, Quarkus, Ktor, JPA) | Covered | `java-kotlin` | None |
| Node.js (Express, NestJS, Fastify, Hono) | Covered | `node` | None |
| Python (FastAPI, Django, Flask) | Covered | `python` | None |
| Go | Covered | `go` | None |
| Rust | Covered | `rust` | None |

### Frontend

| Area | Status | Where | Action |
|---|---|---|---|
| Angular | Covered | `angular` | None |
| Vue | Covered | `vue` | None |
| React | Covered | `react` | None |
| Svelte | Covered | `svelte` | None |
| Accessibility | Covered | `accessibility` | None |
| State management (Redux, Zustand, Pinia, NgRx) | Covered (distributed) | `react`/`vue`/`angular`/`svelte` deep | None |
| Build tooling (Vite, webpack, esbuild) | Covered (distributed) | framework skills + `node`, `performance` | None |
| Mobile (React Native, Flutter) | Covered | `mobile-rn`, `mobile-flutter` | None |

### Data

| Area | Status | Where | Action |
|---|---|---|---|
| PostgreSQL / MySQL / SQLite | Covered | `database` | None |
| MongoDB / Redis (as store) | Covered | `database` | None |
| Migrations | Covered | `database`, `dotnet/references/ef-core` | None |
| Query optimization | Covered | `database`, `performance` | None |
| **SQL Server / T-SQL** | **Missing** | — | **Reference under `database`** (see F-1) |

### Architecture

| Area | Status | Where | Action |
|---|---|---|---|
| DDD, Clean Architecture, CQRS, Event Sourcing | Covered | `architecture`, `dotnet/references/clean-architecture` | None |
| Modular monolith / vertical slices | Covered | `architecture/SKILL.deep.md` | None |
| Microservices (when justified) | Covered | `architecture` | None |

### Infrastructure

| Area | Status | Where | Action |
|---|---|---|---|
| Docker / Kubernetes | Covered | `infrastructure` | None |
| GitHub Actions / CI-CD | Covered | `infrastructure`, `github-workflow` | None |
| Terraform / OpenTofu | Covered | `infrastructure` | None |
| Azure / AWS / GCP (provider specifics) | Weak | `infrastructure/SKILL.deep.md` | Doc-only (see F-2) |

### Quality / cross-cutting

| Area | Status | Where | Action |
|---|---|---|---|
| Testing | Covered | `testing` | None |
| Code review | Covered | `code-review`, `code-reviewer` subagent | None |
| Performance | Covered | `performance` | None |
| Observability | Covered | `observability` | None |
| Security | Covered | `security`, `security-reviewer` subagent | None |
| API design (REST) | Covered | `api-design` | None |
| GraphQL | Covered | `graphql` | None |
| Error handling / resilience | Covered | `error-handling` | None |
| Messaging / event-driven | Covered | `messaging` | None |
| i18n / l10n | Covered | `i18n` | None |
| Dependencies | Covered | `dependencies` | None |
| Monorepo | Covered | `monorepo` | None |
| Release management | Covered | `release-management` | None |

### Project types

| Area | Status | Where | Action |
|---|---|---|---|
| Monorepo | Covered | `monorepo` | None |
| Open-source tooling | Covered (distributed) | `github-workflow`, `release-management`, `dependencies` | None |
| CLI tools | Covered (distributed) | `go`, `rust` (CLI sections) | None |
| Legacy / modernization | Weak | `refactor` command, `architecture` | Doc-only (see F-3) |

### Intentionally unsupported

Documented so they are not re-proposed. Add only if a concrete, realistic project
need appears (per #424: "do not optimize for trendy technologies").

| Area | Reason |
|---|---|
| PHP / Laravel, Ruby / Rails, Elixir / Phoenix | No current target-project demand; large surface for low return. |
| Per-cloud SDK skills (separate Azure/AWS/GCP skills) | Provider consoles/SDKs change fast; IaC-first guidance in `infrastructure` is the durable layer. |
| Data engineering (Spark, dbt, Airflow), ML training | Outside the kit's app/service-engineering mission. |
| Dedicated "state management" / "build tooling" skills | Already covered distributed inside framework skills; a separate skill would duplicate and add routing noise. |

## Proposed follow-ups

Each item below has a reason and an expected routing trigger, per #424. None are
implemented here — that is out of scope for the audit issue.

### F-1 — SQL Server / T-SQL reference under `database` (recommended)

- **Type:** `references/` subskill, not a new skill.
- **Reason:** `database` enumerates Postgres, MySQL, SQLite, MongoDB, Redis but
  never SQL Server, despite first-class `dotnet`/EF Core coverage — the most
  common real-world .NET pairing. This is the only genuine *Missing* gap.
- **Routing trigger:** task keywords `sql server`, `t-sql`, `mssql`, `sqlcmd`;
  paths `**/*.sql` co-occurring with a `dotnet` signal.
- **Deliverable:** `skills/database/references/sql-server.md` with a `## Load when`
  header, plus a routing fixture asserting the `database` skill activates on a
  SQL Server task. Metadata + fixture required (per `SKILL_METADATA.md`).

### F-2 — Cloud provider notes in `infrastructure` deep (optional, doc-only)

- **Type:** Documentation only — extend `infrastructure/SKILL.deep.md`.
- **Reason:** Azure/AWS/GCP appear only lightly; no separate skills wanted (see
  *Intentionally unsupported*). Add a short "provider specifics" section
  (managed identities, IAM least-privilege, regions/cost) anchored to IaC.
- **Routing trigger:** no new trigger — rides existing `infrastructure` activation.

### F-3 — Legacy / modernization guidance (optional, doc-only)

- **Type:** Documentation only — extend `architecture/SKILL.deep.md` or the
  `refactor` command notes.
- **Reason:** Brownfield work (strangler-fig, characterization tests, incremental
  decomposition) is realistic but currently only implicit.
- **Routing trigger:** keywords `legacy`, `modernize`, `strangler`, `brownfield`
  routed to `architecture` + `testing`.

## Recommended implementation order

1. **F-1 (SQL Server reference)** — only true gap; small, high value, follows the
   established `references/` + fixture pattern.
2. **F-2 (cloud notes)** — doc-only, do when an Azure/AWS/GCP project actually
   lands.
3. **F-3 (legacy notes)** — doc-only, lowest priority.

No new broad skills and no new subagents are recommended: the existing 32 skills
plus 5 subagents already cover the kit's stated mission. The router is smart;
the ingredients are largely complete. Resist adding skills ahead of real demand.

## Acceptance-criteria mapping (#424)

- Coverage matrix listing current / missing / weak / intentionally unsupported — this document.
- Each proposed addition has a reason and expected routing trigger — F-1..F-3.
- Work split into follow-up issues by stack/domain — F-1..F-3 (open as issues before any implementation, per ROADMAP "Issue Requirement").
- No broad skill added without metadata and tests — none added here; F-1 specifies metadata + fixture.
- Recommended implementation order — see above.
- Docs checks pass — this is a docs-only addition.

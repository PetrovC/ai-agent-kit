# Changelog

## [Unreleased]

---

## [1.14.0-rc1] - 2026-05-15

### BREAKING — Codex subagents migrated from `.toml` to official `SKILL.md` format

The Rust Codex CLI does not read `.codex/agents/*.toml`. The five subagents we shipped there
(architect, code-reviewer, codebase-investigator, security-reviewer, test-runner) lived in a
directory Codex never opened — they were effectively dead config.

The official Codex spec puts skills under `.agents/skills/<name>/SKILL.md` with markdown +
`name`/`description` frontmatter and invokes them via `/skills` or `$name`. The kit now
ships them as proper skills:

- Source moved from `tooling/codex/agents/<name>.toml` → `tooling/codex/skills/<name>/SKILL.md`.
- Install target moved from `<project>/.codex/agents/` → `<project>/.agents/skills/`.
- Per-skill `model` and `model_reasoning_effort` are dropped (not in the official spec — Codex uses the session model).

**Migration:** `update.sh` / `update.ps1` automatically delete the five legacy
`.codex/agents/*.toml` files (and the directory if empty) on first run after upgrading.
Users running a custom subagent in `.codex/agents/` are preserved.

### Changed

#### Gemini `settings.json` aligned with official schema

Five keys we shipped don't exist in the Gemini CLI settings schema and were silently ignored:

- `general.defaultApprovalMode` — approval mode is a CLI flag (`--approval-mode`), not a settings key.
- `tools.sandboxNetworkAccess` — not in the schema.
- `tools.discovery.command/callCommand` — the official keys are flat: `tools.discoveryCommand` and `tools.callCommand`. We don't actually need either, so the section is removed.
- `skills.enabled` — Gemini has no native "skills" concept (the kit's tool-agnostic skills are just files Gemini reads).
- `security.environmentVariableRedaction.*` — replaced by the official `advanced.excludedEnvVars` flat list.

The redaction list (`*_SECRET`, `*_TOKEN`, `*_KEY`, `*_PASSWORD`, `OPENAI_*`, `ANTHROPIC_*`)
is preserved under the correct key.

#### Claude `settings.json`: deprecated `includeCoAuthoredBy` → `attribution`

The official settings schema marks `includeCoAuthoredBy` as deprecated. Replaced with:
```json
"attribution": { "commit": true, "pr": true }
```
Co-authoring is still enabled for both commits and PRs.

#### Documentation: Gemini subagents are now native

`GEMINI.md` previously routed to `@codebase-investigator`-style mentions as a convention.
Since April 2026 the Gemini CLI supports `@name` subagents natively (`.gemini/agents/*.md` with `name`/`description` frontmatter — which is already how this kit ships them). The doc now states this explicitly and links to the upstream subagent guide.

#### Documentation: Codex AGENTS.md cascade

`AGENTS.md` now documents the three-level cascade Codex applies:
1. `~/.codex/AGENTS.override.md` then `~/.codex/AGENTS.md` (global).
2. `AGENTS.override.md` / `AGENTS.md` from the git root down to the working directory.
3. Files closer to cwd take precedence; total content capped at `project_doc_max_bytes` (32 KiB).

### Added

#### CI: three new lint jobs

- `lint-codex-approval-policy` — fails if any `approval_policy = "..."` in `tooling/codex/*.toml` is not one of `untrusted | on-failure | on-request | never`.
- `lint-codex-skills` — every `tooling/codex/skills/*/SKILL.md` must have `name:` and `description:` frontmatter; fails if `tooling/codex/agents/` (legacy) still exists.
- `lint-gemini-subagents` — every `tooling/gemini/agents/*.md` must have `name:` and `description:` frontmatter.

---

## [1.13.1] - 2026-05-15

### Fixed

#### GitHub Actions workflow templates — invalid inputs

Three of the four templates in `prompts/github-actions/` passed inputs that don't exist in
the current upstream actions, so they would fail at workflow startup.

| File | Wrong input | Correct input |
|---|---|---|
| `codex-pr-review.yml` | `api_key:` | `openai-api-key:` |
| `codex-pr-review.yml` | `approval_policy: "never"` | removed (use `sandbox: "read-only"` + `safety-strategy: "block"`) |
| `codex-pr-review.yml` | `model: "gpt-5.5"` | commented out (non-existent model; let action default decide) |
| `gemini-pr-review.yml` | `flags: "--approval-mode yolo"` | removed (the action runs non-interactively; approval-mode CLI flag is irrelevant) |
| `gemini-pr-review.yml` | `version:` | `gemini_cli_version:` |
| `gemini-issue-triage.yml` | same as above | same fixes |

#### Codex `approval_policy` — invalid values documented

`AGENTS.md`, `tooling/codex/config.toml`, and `tooling/codex/global-config-template.toml`
documented `auto-approve` and `suggest` as valid values. The Rust Codex CLI accepts only
`untrusted` | `on-failure` | `on-request` | `never`. Comments and the CLI usage example
have been corrected. Runtime values (`"on-request"`) were already valid — no behavior change.

---

## [1.13.0] - 2026-05-15

### Changed

#### Agent model tuning — task-appropriate cost across all 15 agent files

Each of the 5 shipped agents (×3 tools = 15 files) had its model and effort level audited against its actual workload. The two most-frequently-spawned agents (`codebase-investigator`, `test-runner`) handle grep / read / shell-exec work that doesn't require deep reasoning — using a small model saves roughly an order of magnitude per invocation. The two highest-stakes agents (`architect`, `security-reviewer`) were upgraded to the most capable tier because the cost of a wrong call there is much higher than the call itself.

| Agent | Tool | Before | After | Why |
|---|---|---|---|---|
| `architect` | Claude | `claude-sonnet-4-6` | **`claude-opus-4-7`** | High-stakes, infrequent — pay for depth |
| `architect` | Gemini | `inherit` | **`gemini-2.5-pro`** | Explicit to avoid silent downgrade if user sets `gemini-2.5-flash` as default |
| `security-reviewer` | Claude | `claude-sonnet-4-6` | **`claude-opus-4-7`** | Wrong call = exploitable vulnerability shipped |
| `security-reviewer` | Gemini | `inherit` | **`gemini-2.5-pro`** | Same reason as Claude |
| `code-reviewer` | Gemini | `inherit` + `max_turns: 25` | **`gemini-2.5-pro`** + `max_turns: 20` | Explicit model; normalize to Claude's `maxTurns: 20` |
| `codebase-investigator` | Claude | `claude-sonnet-4-6` | **`claude-haiku-4-5`** | Only does `Read` / `Glob` / `Grep` — Sonnet was overkill |
| `codebase-investigator` | Gemini | `inherit` + `max_turns: 20` | **`gemini-2.5-flash`** + `max_turns: 15` | Same — search task, cheap model |
| `test-runner` | Claude | `claude-haiku-4-5-20251001` | **`claude-haiku-4-5`** | Drop date suffix → auto-rolls to latest patch |
| `test-runner` | Gemini | `inherit` | **`gemini-2.5-flash`** | Shell exec + summarize, cheap is fine |
| `test-runner` | Codex | `model_reasoning_effort: medium` | **`low`** | No reasoning needed — just run + summarize |

`maxTurns` / `max_turns` normalized across the three tools per agent (was diverging up to 25 in Gemini vs 15-20 elsewhere).

### Added

#### Model selection strategy section in README

New section under "Subagents / Agents" documents the cost rationale: cheap models for frequent / simple tasks, capable models for rare / high-stakes tasks. Includes a per-agent table showing the chosen model on each of the three tools. Projects can override per-agent by editing the `model:` line in the agent file.

### Changed (version)

- `KIT_VERSION` bumped to `1.13.0` in all four scripts.

---

## [1.12.0] - 2026-05-15

### Added

#### Three new CI jobs (`lint-yaml`, `routing-consistency`, `verify-webfetch-domains`)

Closes **C1** from the original kit audit.

| Job | What it validates |
|---|---|
| `lint-yaml` | Every `*.yml` / `*.yaml` file in the repo parses with `yq`. GitHub Actions templates in `prompts/github-actions/` and `.github/workflows/` must declare both `on` and `jobs` keys. |
| `routing-consistency` | Every skill directory under `skills/` must have a row in **all three** routing tables: `tooling/claude/CLAUDE.md` (`` `<skill>` skill ``), `tooling/codex/AGENTS.md` (`` `$<skill>` ``), and `tooling/gemini/GEMINI.md` (`skills/<skill>/SKILL.md`). Catches drift when a new skill is added but routing tables are not updated. |
| `verify-webfetch-domains` | Each `WebFetch(domain:...)` entry in `tooling/claude/settings.json` must be a plain hostname — no wildcards (`*`, `*.example.com`), no schemes (`http://`, `https://`), valid DNS character set. |

These jobs run on every push and pull request, alongside the existing `lint-skills` and `lint-rules` checks.

### Changed

#### `tooling/gemini/settings.json` — enabled checkpointing, added tool discovery placeholder

Closes **C3** from the original kit audit.

- `general.checkpointing.enabled` flipped from `false` to **`true`** — Gemini CLI now writes session checkpoints by default, allowing resume after an error or long pause (`gemini --checkpointing` is the runtime flag, see GEMINI.md).
- New `tools.discovery` block with `command` / `callCommand` placeholders for projects that expose custom tools via Gemini's tool discovery mechanism. Set to `null` by default — projects fill these to register external tools at startup.

#### `tooling/claude/settings.json` — project-level defaults

Closes **B3** from the original kit audit.

Four top-level fields added so installed projects ship with safe, explicit defaults:

| Field | Value | Why |
|---|---|---|
| `model` | `"claude-sonnet-4-6"` | Pins the default model for the project. Override per-session with `claude --model ...`. |
| `outputStyle` | `"default"` | Explicit baseline — projects can switch to `"concise"` for less verbose output. |
| `includeCoAuthoredBy` | `true` | Ensures Claude-assisted commits carry a `Co-Authored-By: Claude` trailer for attribution. |
| `cleanupPeriodDays` | `30` | Bounded retention for Claude Code's local logs and session data. |

### Changed (version)

- `KIT_VERSION` bumped to `1.12.0` in all four scripts.

---

## [1.11.0] - 2026-05-15

### Changed

#### `README.md` — major documentation pass

The README was restructured to explain **what each component is, which AI tool uses it, and why it's useful**. A new "How each feature maps to each tool" section was added covering:

- **Skills** — how they load differently per tool: Claude Code auto-loads via `paths:` frontmatter, Codex activates via `$skill-name`, Gemini reads via explicit file path
- **Hooks** — Claude Code only (lifecycle events, exit code 2 = block); explanation of why Codex/Gemini use approval modes instead
- **Rules** — Claude Code only (path-triggered auto-load); explanation of how they differ from skills
- **MCP servers** — Claude Code full support, Gemini emerging, Codex not supported; link to MCP spec
- **Subagents** — format and invocation per tool (`.md` / `.toml` / `.md`, different invocation syntax)

A new **"Official resources"** table near the top links all 7 official tool repositories and documentation sites:

| Resource | URL |
|---|---|
| Claude Code source | [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code) |
| All Anthropic repos | [github.com/orgs/anthropics/repositories](https://github.com/orgs/anthropics/repositories) |
| Codex CLI source | [github.com/openai/codex](https://github.com/openai/codex) |
| Codex GitHub Action | [github.com/openai/codex-action](https://github.com/openai/codex-action) |
| Gemini CLI source | [github.com/google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli) |
| Gemini CLI docs | [google-gemini.github.io/gemini-cli/docs](https://google-gemini.github.io/gemini-cli/docs) |
| Gemini GitHub Action | [github.com/google-github-actions/run-gemini-cli](https://github.com/google-github-actions/run-gemini-cli) |

#### `tooling/claude/CLAUDE.md` — added "How to run Claude Code" section

Added a missing `## How to run Claude Code` section (equivalent to what GEMINI.md already had) covering:
- `claude` (interactive) vs `claude --dangerously-skip-permissions` (CI/autonomous)
- `--model`, `--continue`, `--print` flags
- How Claude Code loads this file at startup and lazy-loads rules and skills
- Link to [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code)

#### `tooling/codex/AGENTS.md` — added "How to run Codex CLI" section

Added a new `## How to run Codex CLI` section covering:
- `--approval-policy` modes (default `on-request`, `auto-approve`, `never`)
- `--profile` switching (readonly, standard, deep, review)
- `--model`, `--no-project-doc` flags
- How Codex reads this file and `.codex/config.toml`
- Links to [github.com/openai/codex](https://github.com/openai/codex) and the GitHub Action

#### `tooling/gemini/GEMINI.md` — expanded "How to run" section

Extended the existing section with:
- `--checkpointing` flag (resume after error or long pause)
- `--debug` flag (verbose tool call output)
- `--model` override flag
- How Gemini loads skills via explicit file reads
- Reference links (source, docs, GitHub Action)

### Changed (version)

- `KIT_VERSION` bumped to `1.11.0` in all four scripts.

---

## [1.10.0] - 2026-05-14

### Changed

#### `code-review` skill — major expansion (114 → 240 lines)

New sections added to cover everything that matters in a real PR review:

| Section | What it covers |
|---|---|
| **PR size guidance** | >400 LOC = request a split; how to handle large/generated PRs |
| **Async and concurrency checklist** | Missing awaits, fire-and-forget, race conditions, deadlocks, thread-safety, CancellationToken propagation, listener cleanup |
| **Data and schema changes** | Reversibility, backward-compatibility, NOT NULL migration safety, CONCURRENT indexes, two-step renames, volume timing |
| **Dependency changes** | License check, maintainability signals, version pinning, bundle size impact, duplication |
| **Performance flags** | O(n²) loops, N+1 queries, missing pagination, missing cache, synchronous I/O on hot path |
| **Review comment quality** | File:line format, why-it-matters + suggestion template, tone rules (suggest vs demand, no negative attribution) |

Priority order expanded to 9 levels (added data safety and dependency changes).
Final response format adds one-line merge verdict: "Ready to merge", "Needs changes (N blockers)", "Needs discussion".

#### `vue` skill — major expansion (114 → 270 lines)

Replaced bullet lists with full working code examples throughout:

| Section | What was added |
|---|---|
| **`<script setup>` full pattern** | `defineProps<T>()`, `defineEmits<T>()`, `defineModel()` (Vue 3.4+), `computed()`, `watch()` in one coherent example |
| **Composables** | `useLeaveBalance` with async fetch, `error`/`loading`/`balance` refs, timer cleanup in `onUnmounted()`, `MaybeRef<T>` usage |
| **Pinia composition stores** | `defineStore` factory style, typed state/getters/actions, `storeToRefs()` usage in components |
| **Vue Router 4** | Typed `RouteRecordRaw`, lazy-loaded routes, `router.beforeEach` auth guard, `useRouter()`/`useRoute()`, params as props |
| **Provide / Inject (typed)** | `InjectionKey<T>` pattern for type-safe injection |
| **Performance patterns** | `shallowRef`, `markRaw`, `v-memo`, `defineAsyncComponent`, warning on reactive large arrays |
| **Nuxt 3 / SSR** | `useFetch`/`useAsyncData`, `<ClientOnly>`, `useState`, browser-only code guards |
| **Anti-patterns table** | 7 common mistakes with concrete fixes |
| **Paths extended** | Added `**/nuxt.config.*` |

#### `angular` skill — major expansion (124 → 290 lines)

Rewritten for Angular 17+ with full code examples:

| Section | What was added |
|---|---|
| **Standalone component pattern** | `standalone: true`, `ChangeDetectionStrategy.OnPush`, `inject()`, complete `input()`/`output()`/`model()` signal APIs |
| **Signals** | `signal()`, `computed()`, `effect()` with cleanup; signals vs RxJS decision table |
| **RxJS interop** | `toSignal()` (auto-unsubscribes) and `toObservable()` with usage examples |
| **New control flow** | `@if`/`@else if`/`@else`, `@for` with required `track`, `@empty`, `@switch` — replacing `*ngIf`/`*ngFor` |
| **Deferrable views** | `@defer` with `on viewport`, `@loading`/`@placeholder`/`@error` blocks, when to use |
| **Functional interceptors** | `HttpInterceptorFn`, `provideHttpClient(withInterceptors([...]))`, no class-based interceptors |
| **Functional routing** | `loadComponent`, `CanActivateFn`, `ResolveFn`, `inject()` in guards/resolvers |
| **Typed reactive forms** | `FormControl<Date \| null>`, `FormGroup<{...}>` for compile-time checked access |
| **Testing with signal inputs** | `fixture.componentRef.setInput()` for signal-based `input()` props |
| **Anti-patterns table** | 8 patterns to reject with fixes |

### Changed (version)

- `KIT_VERSION` bumped to `1.10.0` in all four scripts.

---

## [1.9.0] - 2026-05-14

### Changed

#### `architecture` skill — major rewrite (126 → 260 lines)

Replaced thin bullet-list with concrete, runnable TypeScript examples throughout:

| Section | What was added |
|---|---|
| **Layer boundaries** | Non-negotiable dependency rules (Domain → no deps, Application → Domain only, Infrastructure → ports, Interfaces → Application only) with a common-violations checklist |
| **When to use each pattern** | Decision table: layered / CQRS / domain events / event sourcing / microservice / modular monolith with default recommendation |
| **DDD — Entities vs Value Objects** | `Order` aggregate with two invariant checks (`PENDING` guard, max 20 items), domain event collection; `Money` value object (immutable, `Object.freeze`, currency equality) |
| **Aggregate rules** | One repository per root, consistency boundary, cross-aggregate via events or app services, keep aggregates small |
| **Domain events** | Dispatch pattern: raise in aggregate → save → publish → clear events |
| **CQRS** | Full TypeScript write-side (`ShipOrderCommand` + `ShipOrderHandler`) and read-side (`GetOrderDashboardHandler` with direct SQL, no domain objects) |
| **Hexagonal / Ports & Adapters** | `OrderRepository` and `EmailService` ports in Application; `PostgresOrderRepository` / `SendGridEmailService` adapters in Infrastructure; `InMemoryOrderRepository` fake for unit tests |
| **Modular monolith** | Directory layout, module communication rules (public interfaces / events only), private DB tables per module |
| **Bounded contexts** | Separate models, explicit DTOs, anti-corruption layers, `docs/ai/ARCHITECTURE.md` |
| **Decision rule for abstractions** | Three triggers (real duplication / meaningful boundary / testability); no speculative abstractions |
| **Verification** | `ARCHITECTURE.md` / `DECISIONS.md` check, cross-layer dependency check, integration test requirement |
| **Final response format** | 8-field structured response (business capability → current state → proposed change → layers → deps → not over-engineered → reversibility → validation) |

#### `ai-dev` skill — three new sections (Extended thinking, `tool_choice` modes, MCP)

| Section | What was added |
|---|---|
| **`tool_choice` modes** | `{"type": "tool", "name": "..."}` for forced structured output, `{"type": "any"}` to require a call, `{"type": "auto"}` (default) — with note that force-tool is more reliable than JSON mode |
| **Extended thinking** | `thinking: {"type": "enabled", "budget_tokens": N}` usage; `ThinkingBlock` vs `TextBlock` in response; rules: budget < max_tokens, don't show thinking to users, cache system prompt separately, include thinking blocks in multi-turn history, not available on Haiku |
| **MCP — Model Context Protocol** | When to use (runtime external tools/data, tool reuse across agents, Claude Code skills); stdio vs HTTP/SSE table; `.mcp.json` config example (filesystem, postgres); full TypeScript MCP server implementation (`ListTools` + `CallTool` handlers with `StdioServerTransport`); four security rules |

### Changed (version)

- `KIT_VERSION` bumped to `1.9.0` in all four scripts.

---

## [1.8.0] - 2026-05-14

### Added

#### New prompt: `performance-audit.md`
Structured 4-step performance investigation: baseline → classify bottleneck (DB / network / app code / frontend / caching) → targeted fixes → re-measure. Enforces "measure first" discipline and requires actual numbers in the report.

### Changed

#### `security` skill — major expansion (142 → 260 lines)

New sections added:

| Section | What it covers |
|---|---|
| OWASP Top 10 quick reference | One-line countermeasure for each of the 10 risks |
| Injection | Parameterized query examples in Python, TypeScript, .NET EF Core, Go, MongoDB |
| XSS | DOMPurify usage, CSP baseline header, `HttpOnly` cookies |
| CSRF | `SameSite=Strict`, CSRF token patterns, framework defaults |
| Authentication | JWT pitfalls (`alg:none`, short expiry, no `localStorage`), bcrypt/Argon2, session fixation, account enumeration |
| Authorization | Fail-closed pattern, ownership check in DB query, audit logging |
| CORS | Allowlist origins, never wildcard for authenticated APIs |
| Rate limiting | Per-user limits, 429 + `Retry-After`, fail-open on limiter errors |
| SSRF | Allowlist + block private IPs + DNS rebinding mitigation |

Verification section extended with `bandit` (Python static analysis) and secret-grep command.

#### `react` skill — Next.js App Router coverage expanded

The `## Next.js (App Router)` section grew from 6 bullets to full coverage:

- **Server vs Client Components**: decision tree (when to add `'use client'`)
- **Server Actions**: form mutation pattern, `useActionState`, input validation
- **Route Handlers**: `GET` / `POST` examples, when to use vs Server Actions
- **Middleware**: auth redirect pattern, `config.matcher`, performance constraints
- **Special files table**: `loading.tsx`, `error.tsx`, `not-found.tsx`, `layout.tsx`, `template.tsx`
- **Environment variables**: `NEXT_PUBLIC_*` vs server-only, `zod`-validated `env.ts` module
- **Image + font optimization**: `next/image` props, `next/font`
- **Auth pattern**: middleware + Server Component + Action layered verification
- **Metadata**: static `export const metadata` vs dynamic `generateMetadata`

### Changed (version)

- `KIT_VERSION` bumped to `1.8.0` in all four scripts.

---

## [1.7.0] - 2026-05-14

### Added

#### 3 new operational prompts

| File | When to use |
|---|---|
| `prompts/on-call.md` | Structured 5-step incident investigation: triage → scope → root cause → mitigate → post-mortem write-up |
| `prompts/dependency-update.md` | Safe single-package upgrade: changelog review → license check → baseline test → update → audit |
| `prompts/tech-debt.md` | Codebase-wide tech debt triage: outdated deps, layer violations, dead code, missing tests, oversized units — sorted by risk × effort |

Prompts are in `prompts/` — not installed into projects. Open in the kit and paste into your agent.

#### Bun and Deno runtime support in `node` skill

`skills/node/SKILL.md` updated:

- **Paths extended**: `**/bun.lockb`, `**/bunfig.toml`, `**/deno.json`, `**/deno.jsonc` — skill now auto-loads for Bun and Deno projects.
- **`allowed-tools` extended**: `Bash(bun:*)`, `Bash(deno:*)`.
- **New `## Bun` section**: drop-in replacement specifics — `bun install --frozen-lockfile`, built-in test runner, native TypeScript execution, `Bun.file()` / `Bun.serve()`, `bunfig.toml`.
- **New `## Deno` section**: Node-compatible Deno 2 — permission flags, `deno.json`, `jsr:@std/*`, `npm:` specifiers, `deno check / lint / fmt / test`.
- Description updated to include Bun, Deno, Elysia, and Hono.

### Changed

#### Version bump
- `KIT_VERSION` bumped to `1.7.0` in all four scripts: `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

---

## [1.6.0] - 2026-05-14

### Added

#### New skill: `graphql`
`skills/graphql/SKILL.md` — dedicated implementation skill for GraphQL APIs.

Covers:
- **Schema design**: type system rules, nullability conventions, custom scalars, input types, mutation payload pattern
- **Operations**: query / mutation / subscription best practices (mutations must return the mutated resource)
- **Resolvers**: thin-dispatcher pattern, context injection, service delegation
- **DataLoader**: N+1 prevention — batching pattern, per-request instantiation, missing-key handling
- **Pagination**: cursor-based (Relay spec) vs offset-based, when to use each
- **Error handling**: union types for domain errors vs bubbling for unexpected errors
- **Auth**: AuthN in HTTP middleware, AuthZ in resolvers or schema directives, field-level access
- **Code generation**: `@graphql-codegen/cli` setup (typed resolvers + client hooks), CI check for stale output
- **Server options**: Apollo Server, GraphQL Yoga, Pothos (Node); Strawberry / Ariadne (Python); gqlgen (Go); Hot Chocolate (.NET); Spring GraphQL / DGS (Java)
- **Testing**: unit (resolver + mocked context), integration (full schema execution), schema snapshot + breaking-change detection with `graphql-inspector`
- **Verification commands** for all stacks

Path-scoped: auto-loaded on `**/*.graphql`, `**/*.gql`, `**/graphql.config.*`, `**/codegen.yml`, `**/codegen.yaml`.

#### Routing — `graphql` added to all three root files
All three routing tables (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) now have a dedicated row for GraphQL:

- `api-design` row: narrowed to REST / OpenAPI contracts — GraphQL implementation removed.
- New `graphql` row: schemas, resolvers, dataloaders, subscriptions, codegen.

`skills/api-design/SKILL.md` description updated to clarify the split.

### Changed

#### Version bump
- `KIT_VERSION` bumped to `1.6.0` in all four scripts: `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

#### README skill table
- `graphql` added to the Cross-cutting row.
- `graphql` added to the `paths:`-carrying skills paragraph.

---

## [1.5.0] - 2026-05-14

### Added

#### Claude Code hooks (4 scripts in `tooling/claude/hooks/`)
Ready-to-use lifecycle hook scripts installed into `.claude/hooks/` by the install/update scripts.

| Script | Event | Mode | Purpose |
|---|---|---|---|
| `format-on-save.sh` | `PostToolUse(Edit\|Write)` | async | Runs the project's formatter (prettier, ruff, gofmt, rustfmt, dotnet format) on every saved file |
| `pre-bash-guard.sh` | `PreToolUse(Bash)` | blocking | Blocks `git push --force`, `git reset --hard`, recursive `rm -rf` outside tmp, SQL `DROP` without an approval marker |
| `notify-done.sh` | `Stop` | async | Desktop notification when Claude finishes (macOS: osascript/terminal-notifier; Linux: notify-send; Windows: PowerShell toast) |
| `session-summary.sh` | `PreCompact` | async | Saves a git status + diff snapshot to `.claude/session-log/` before context compaction |

`settings.json` updated to reference the real scripts (replaces the placeholder `echo` commands).
`install.sh` runs `chmod +x` on all `.sh` hook files after installation.

#### Claude Code rules (4 files in `tooling/claude/rules/`)
Path-scoped lightweight rule files — auto-loaded by Claude Code when a matching file is opened.

| File | Trigger paths | Coverage |
|---|---|---|
| `commit-style.md` | `**/.github/**`, `.gitignore`, `.gitattributes` | Conventional Commits, no force-push, one concern per commit |
| `test-naming.md` | `**/*.test.*`, `**/*.spec.*`, `**/tests/**` | No `.only`, no skip without issue link, deterministic tests |
| `migration-safety.md` | `**/migrations/**`, `**/*.sql`, `**/schema.prisma` | Reversible migrations, CONCURRENT indexes, no one-step column rename |
| `env-safety.md` | `**/.env*`, `**/config/**`, `**/appsettings*.json` | No hardcoded secrets, `.env.example` required, rotate leaked secrets |

#### `.mcp.json` project template (`tooling/claude/.mcp.json`)
Versioned MCP server configuration template installed at the project root (`.mcp.json`).
Includes commented examples for GitHub, filesystem, Postgres, Notion, and Linear servers with `${ENV_VAR}` expansion placeholders.

#### GitHub Actions workflow templates (`prompts/github-actions/`)
Four copy-paste CI workflow files — not installed automatically; copy to `.github/workflows/` in your project.

| File | Action used | Trigger |
|---|---|---|
| `claude-code.yml` | `anthropics/claude-code-action@v1` | `@claude` mention in issues / PRs / reviews |
| `codex-pr-review.yml` | `openai/codex-action@v1` | `@codex` mention in PR comments |
| `gemini-pr-review.yml` | `google-github-actions/run-gemini-cli@v0` | `@gemini review` in PR comments |
| `gemini-issue-triage.yml` | `google-github-actions/run-gemini-cli@v0` | New issue opened |

#### Claude agent `disallowedTools` + `permissionMode` frontmatter
All five Claude subagents now carry explicit safety guards:
- `architect`, `code-reviewer`, `codebase-investigator`: `disallowedTools: [Edit, Write, Bash, NotebookEdit]` — read-only enforcement on top of the existing `tools:` whitelist.
- `security-reviewer`: `disallowedTools: [Edit, Write, NotebookEdit]` — keeps Bash for audit commands, blocks writes.
- `test-runner`: `disallowedTools: [Edit, Write, NotebookEdit]` — can run tests, cannot modify source files.
- All five: `permissionMode: default`.

#### CI: new `lint-rules` job
Checks every file in `tooling/claude/rules/` has a `paths:` frontmatter key, and that every `tooling/claude/hooks/*.sh` has the executable bit set (mode `100755` in git).

#### CI: expanded smoke-test file coverage
Both `smoke-install` (bash) and `smoke-install-windows` (PowerShell) jobs now verify `.mcp.json`, all four hook scripts, and all four rule files are present after install.
Bash job additionally checks that hook scripts are executable after install.

### Fixed

#### `tooling/codex/config.toml` — `approval_policy` regression (introduced in v1.4.0)
- v1.4.0 changed `approval_policy` to `"suggest"` (incorrect — not a valid Rust CLI value).
- Reverted to `"on-request"` (confirmed correct per `global-config-template.toml` and official docs).
- Updated inline comment to show all valid values: `on-request | auto-approve | never`.
- Updated `sandbox_mode` inline comment: `workspace-write | read-only | danger-full-access` (removes the invalid `"none"` value listed in v1.4.0).

#### `tooling/codex/config.toml` — TOML structure: `project_doc_max_bytes` at wrong level
- `project_doc_max_bytes = 32768` was placed after the `[sandbox_workspace_write]` section header, making it a sub-key of that section instead of a root-level config key.
- Moved before the `[sandbox_workspace_write]` header.

#### `tooling/gemini/settings.json` — complete schema rewrite
The previous schema used keys that no longer exist in the current Gemini CLI. Full rewrite to the current schema:

| Old key | New key |
|---|---|
| `autoAccept` | `general.defaultApprovalMode` |
| `sandbox.enabled` | `tools.sandbox` |
| `tools.webSearch` | removed (use `tools.allowed`) |
| `tools.codeExecution` | removed |
| `tools.allowlist` | `tools.allowed` |
| `tools.excludelist` | `tools.exclude` |
| — | `general.checkpointing.enabled` (new) |
| — | `skills.enabled` (new) |
| — | `security.environmentVariableRedaction` (new) |

### Changed

#### Version bump
- `KIT_VERSION` bumped to `1.5.0` in all four scripts: `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

#### Install / update / uninstall scripts — Claude section expanded
- `install.sh` / `install.ps1`: now install `.mcp.json`, `hooks/`, and `rules/`.
- `update.sh` / `update.ps1`: now update `.mcp.json`, `hooks/`, and `rules/` using MD5 diff.
- `uninstall.sh` / `uninstall.ps1`: now remove `.mcp.json`, `.claude/hooks/`, and `.claude/rules/`.

---

## [1.4.0] - 2026-05-14

### Added

#### `paths:` and `allowed-tools:` frontmatter on 17 path-scoped skills (A1 + A2)
All language/framework skills now carry Claude Code native path-routing metadata.
When a file matching the pattern is opened, Claude Code auto-suggests the skill — no
manual routing entry needed in the project's CLAUDE.md.

Skills updated and their trigger patterns:

| Skill | Paths | Tools |
|---|---|---|
| `dotnet` | `**/*.cs`, `**/*.csproj`, `**/*.sln`, `**/global.json` | `dotnet` |
| `java-kotlin` | `**/*.java`, `**/*.kt`, `**/*.kts`, `**/build.gradle*`, `**/pom.xml` | `./gradlew`, `mvn` |
| `python` | `**/*.py`, `**/pyproject.toml`, `**/requirements*.txt` | `python3`, `uv`, `pytest`, `ruff` |
| `node` | `**/package.json`, `**/*.js`, `**/*.mjs`, `**/*.cjs` | `npm`, `pnpm`, `node`, `npx` |
| `go` | `**/*.go`, `**/go.mod` | `go` |
| `rust` | `**/*.rs`, `**/Cargo.toml` | `cargo` |
| `angular` | `**/angular.json`, `**/*.component.ts/html/scss`, `**/*.module.ts` | `ng`, `npm` |
| `vue` | `**/*.vue`, `**/vite.config.*` | `npm`, `pnpm`, `vite`, `vue-tsc` |
| `svelte` | `**/*.svelte`, `**/svelte.config.*` | `npm`, `pnpm`, `vite` |
| `react` | `**/*.jsx`, `**/*.tsx`, `**/next.config.*` | `npm`, `pnpm` |
| `mobile-flutter` | `**/*.dart`, `**/pubspec.yaml` | `flutter`, `dart` |
| `mobile-rn` | `**/app.json`, `**/*.native.ts/tsx`, `**/metro.config.*` | `npm`, `expo` |
| `database` | `**/*.sql`, `**/migrations/**`, `**/schema.prisma` | — |
| `infrastructure` | `**/Dockerfile*`, `**/*.tf`, `**/docker-compose*` | `docker`, `kubectl`, `terraform` |
| `github-workflow` | `**/.github/**` | `git`, `gh` |
| `monorepo` | `**/nx.json`, `**/turbo.json`, `**/pnpm-workspace.yaml` | `npm`, `pnpm` |
| `dependencies` | all manifest files (`package.json`, `*.csproj`, `Cargo.toml`, `go.mod`, `pom.xml`, …) | — |

Cross-cutting skills (`architecture`, `security`, `testing`, `code-review`, `observability`,
`messaging`, `error-handling`, `ai-dev`, `performance`, `accessibility`, `i18n`, `api-design`)
have no paths — they are loaded explicitly via CLAUDE.md routing.

#### `CLAUDE.local.md` support (B2)
- `CLAUDE.md` now documents that developers can create a `CLAUDE.local.md` in the project root
  for personal, gitignored preferences (local paths, aliases, verbosity level).
- `install.ps1` and `install.sh` gitignore hint now includes `CLAUDE.local.md` alongside
  `.claude/settings.local.json`, `.env`, `.env.*`.

#### Gemini CLI approval mode documentation (B4)
- `GEMINI.md` now has a `## How to run` section documenting `--approval-mode default|auto_edit|yolo`
  with a one-line description of each mode.

### Changed

#### `tooling/codex/config.toml` — Rust CLI alignment (B6)
- `approval_policy` renamed from `"on-request"` to `"suggest"` (Rust CLI canonical value).
- Inline comments added for every key documenting all valid values
  (`suggest`, `auto-edit`, `full-auto` for approval; `workspace-write`, `read-only`, `none` for sandbox).
- `web_search` comment documents `cached|enabled|disabled`.

#### Version bump
- `KIT_VERSION` bumped to `1.4.0` in `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

---

## [1.3.0] - 2026-05-14

### Added

#### New skill: `svelte`
- `skills/svelte/SKILL.md` — covers Svelte 5 and SvelteKit.
- Project structure: `src/lib/`, `src/routes/`, `src/lib/server/` layout.
- Reactivity model: compile-time rules, reassignment semantics, `$:` statements.
- Components: TypeScript, prop typing, event forwarding, `onMount` vs init guards.
- Stores: `writable`, `readable`, `derived` — when to use each; placement in `src/lib/stores/`.
- SvelteKit data loading: `+page.server.ts` (server-only) vs `+page.ts` (universal).
- Form actions: progressive-enhancement pattern with `use:enhance`, `fail()`, `redirect()`.
- Testing: Vitest + `@testing-library/svelte` for components; Playwright for E2E.
- Routing added to all three root files (CLAUDE.md, AGENTS.md, GEMINI.md).

#### New skill: `performance`
- `skills/performance/SKILL.md` — cross-stack profiling, benchmarking, and optimization.
- Universal rule: measure first, optimize the bottleneck, re-measure.
- Backend: profiling commands for .NET, Python, Go, Node, Rust; slow-query diagnosis with `EXPLAIN ANALYZE`; N+1 ORM patterns per stack; cache-aside pattern.
- Frontend: Core Web Vitals targets (LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1); bundle analysis; code splitting; virtualization.
- HTTP: compression, cache headers, pagination strategy.
- Benchmarking tools table: k6, wrk, BenchmarkDotNet, criterion, pytest-benchmark, Lighthouse CI.
- "What NOT to do" section covering common premature-optimization traps.
- Routing added to all three root files.

#### GitHub Actions CI (`.github/workflows/ci.yml`)
- `validate-example` job: runs `validate.sh` against `examples/filled-project` on every push/PR.
- `smoke-install` job (Ubuntu): installs the kit into a temp directory, verifies all expected files exist, runs dry-run update and uninstall.
- `smoke-install-windows` job (Windows): same smoke test using `install.ps1`, `update.ps1`, `uninstall.ps1`.
- `lint-skills` job: checks every `skills/*/` directory has a `SKILL.md` and that every skill has a "Final response requirements" section.

### Fixed

#### `validate.ps1` — STOP pattern precision
- Pattern was `"STOP"` (matches any word containing "STOP", e.g., "restart").
- Now aligned with `validate.sh`: uses `"^> .*STOP|⚠️.*STOP"` to match only template STOP notice lines.

#### Tool name validation in all scripts
- `install.ps1`, `install.sh`, `update.ps1`, `update.sh`, `uninstall.ps1`, `uninstall.sh` now reject unknown tool names early with a clear error message.
- Prevents silent no-ops from typos like `--tools cluade` or `--tools Codex`.

#### `README.md` — skill table gaps
- `java-kotlin` (added in v1.2.0) was missing from the Backend languages row.
- `svelte` and `performance` added to their respective rows.

#### `tooling/claude/settings.json` — WebFetch allowlist
- Added Java/Kotlin documentation domains missing after v1.2.0's `java-kotlin` skill: `kotlinlang.org`, `docs.spring.io`, `docs.gradle.org`, `maven.apache.org`, `junit.org`.

### Changed

#### `scripts/new-skill.ps1` and `new-skill.sh` — routing auto-insert
- Both scripts now insert a TODO placeholder row into all three routing tables (CLAUDE.md, AGENTS.md, GEMINI.md) immediately after scaffolding the skill file.
- Uses Python (bash) and `.Replace()` (PowerShell) to find the known anchor and insert before it.
- Prints a warning and skips gracefully if the anchor is not found.
- "Next steps" output now says to *replace* the TODO row rather than *add* a row.

#### `scripts/install.ps1` and `install.sh` — done output
- "Next steps" section now includes step 4: run `validate` to confirm templates are filled.
- Added a "Starter prompts" section listing the 5 most useful prompts with their purpose.
- "Later, to pull in kit updates…" line moved after the prompts list.

#### Version bump
- `KIT_VERSION` bumped to `1.3.0` in `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

---

## [1.2.0] - 2026-05-14

### Added

#### New skill: `java-kotlin`
- `skills/java-kotlin/SKILL.md` — covers Java and Kotlin on the JVM.
- Project structure: Clean Architecture layers adapted to Spring Boot / Ktor.
- Language guidance: Kotlin as modern default, Java for existing codebases, interop rules.
- Kotlin idioms: null safety, data classes, value classes, sealed classes, extension functions, coroutines, Flow.
- Spring Boot 3.x: controllers, `@ConfigurationProperties`, `@RestControllerAdvice`.
- JPA/Hibernate: entity mapping, Kotlin `noArg`/`allOpen` plugins, Flyway migrations.
- Build tools: Gradle Kotlin DSL (preferred) and Maven.
- Testing: JUnit 5 + MockK (Kotlin) / Mockito (Java) + Testcontainers (no H2).
- Code quality: detekt + ktlint for Kotlin, checkstyle for Java.
- Package and runtime maintenance section (same proactive protocol as dotnet).

#### Routing
- `java-kotlin` skill added to routing tables in `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`.

### Fixed

#### Template `project-template/ARCHITECTURE.md`
- Removed .NET-specific layer names (Domain/Application/Infrastructure/Interfaces) as hard defaults.
- Added multi-stack layer name examples for .NET, Python, Go, Rust, Node.
- Layers are now placeholders (`<Layer 1>`, etc.) — teams fill in their actual names.

#### `prompts/security-audit.md`
- Added missing vulnerability check commands: `pip-audit` (Python), `cargo audit` (Rust), `govulncheck ./...` (Go).

#### `skills/architecture/SKILL.md`
- Added `## Verification` section (all other skills had one; architecture was the only exception).

#### `skills/code-review/SKILL.md`
- Removed .NET-specific EF Core reference from the SQL injection check line.

#### `scripts/uninstall.ps1` / `uninstall.sh`
- Updated header comment to accurately describe surgical removal behavior.

### Changed

#### Version bump
- `KIT_VERSION` bumped to `1.2.0` in `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

---

## [1.1.0] - 2026-05-14

### Added

#### Proactive maintenance behavior (all 3 root files)
- New `## Proactive maintenance` section in `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`.
- Agents must surface outdated packages, runtime upgrades, deprecated APIs, and transitive CVEs — never apply silently.
- Explicit approval required before any out-of-scope maintenance change.
- "One concern per PR" rule enforced for maintenance items.

#### `.NET` skill — package and runtime maintenance section
- `## Package and runtime maintenance` section added to `skills/dotnet/SKILL.md`.
- Covers NuGet update protocol, `dotnet list package --outdated / --vulnerable`, .NET runtime upgrade checklist, LTS-only upgrade rule.

#### `security` skill — multi-stack rewrite
- Input validation, authentication, and verification sections now cover .NET, Python, Node, Go, and Rust.
- Stack-specific patterns in tables for each area.
- Verification commands extended: `npm audit`, `pip-audit`, `cargo audit`, `govulncheck`.

### Changed

#### Version bump
- `KIT_VERSION` bumped to `1.1.0` in `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

#### Agent model versions (Claude)
- All Sonnet agents updated from `claude-sonnet-4-5` to `claude-sonnet-4-6`.
- Test-runner agent updated from `claude-haiku-4-5` to `claude-haiku-4-5-20251001`.

#### WebFetch allowlist expanded
- `tooling/claude/settings.json` now covers documentation domains for all skills:
  `docs.python.org`, `packaging.python.org`, `pkg.go.dev`, `go.dev`, `doc.rust-lang.org`,
  `docs.rs`, `react.dev`, `nextjs.org`, `docs.flutter.dev`, `api.flutter.dev`,
  `expo.dev`, `docs.docker.com`, `kubernetes.io`, `developer.hashicorp.com`,
  `graphql.org`, `nodejs.org`.

#### Cross-tool alignment (CLAUDE.md, GEMINI.md)
- Engineering principles aligned with AGENTS.md: "One concern per PR", "Add abstractions only when...", "Avoid unrelated formatting changes".
- Security rules aligned: added "Never print...", "Do not read `.env`...", added CSP to the list.
- GEMINI.md context strategy: added step 6 (read relevant skill file), added "Do not scan entire repo" note.

### Fixed

#### Uninstall scripts — surgical removal
- `uninstall.ps1` and `uninstall.sh` no longer delete the entire `.claude/`, `.gemini/` or `.codex/` directories.
- Now removes only kit-installed files: root `.md`, `settings.json`, `agents/`, `skills/`.
- Parent directories are cleaned up only if empty — preserving `settings.local.json`, custom hooks, etc.

#### `validate.sh` — STOP pattern precision
- `grep -q "STOP"` replaced with `grep -qE '^> .*STOP|⚠️.*STOP'` to avoid false positives on words containing "STOP".

---

## [1.0.0] - 2026-05-14

### Added

#### New skills
- `python` — FastAPI / Django / pytest / uv / ruff / mypy / SQLAlchemy.
- `node` — Express / NestJS / Fastify, strict TypeScript, Vitest / Jest, pnpm.
- `go` — modules, errors with `%w`, contexts, table-driven tests, net/http + chi.
- `rust` — cargo workspaces, thiserror / anyhow, tokio, axum, sqlx.
- `react` — hooks, Next.js App Router, Remix, RTL + userEvent, MSW.
- `mobile-rn` — Expo + bare RN, React Navigation, Reanimated, EAS, Detox / Maestro.
- `mobile-flutter` — Riverpod / BLoC, go_router, mocktail, flutter_test.
- `infrastructure` — Docker, Kubernetes, Terraform / OpenTofu, GitHub Actions.
- `api-design` — REST, OpenAPI, GraphQL, RFC 7807 problem details, idempotency.
- `dependencies` — MIT-only enforcement, 20-line native rule, anti-overkill list.

#### Skill rewrites
- `database` — extended from EF Core-only to multi-engine (Postgres, MySQL, SQLite, MongoDB, Redis, ORM-agnostic).
- `testing` — added frontend testing section (Vitest, Vue Test Utils, Angular TestBed) and per-language examples (pytest, go test, cargo test, JUnit, Jest).

#### Operational scripts
- `scripts/update.sh` — bash equivalent of `update.ps1` with MD5 diff and version drift warning.
- `scripts/validate.sh` and `scripts/validate.ps1` — post-install check that `docs/ai/` templates have been filled (no `STOP` notices or `<!-- placeholder -->` left).
- `scripts/uninstall.sh` and `scripts/uninstall.ps1` — cleanly remove kit files from a project (preserves `docs/ai/`).
- `scripts/new-skill.sh` and `scripts/new-skill.ps1` — scaffold a new skill following the standard template.
- Version drift detection in `update.sh` / `update.ps1` — warns when installed `.kit-version` differs from source kit version.

#### Codex parity
- New `tooling/codex/agents/security-reviewer.toml` — closes the gap with Claude / Gemini.

#### Routing additions in CLAUDE.md, AGENTS.md, GEMINI.md
- Entries for all 10 new / rewritten skills.
- `dependencies` skill routing on "adding, updating, or replacing any library/package".

#### Project templates
- `STOP` notices on top of every `project-template/*.md` to prevent agents from reading empty templates.

#### Filled example
- `examples/filled-project/docs/ai/` — concrete reference of what filled templates look like.

#### Prompts
- `prompts/run-tests.md` — start a focused test pass.
- `prompts/security-audit.md` — targeted security review.

### Changed

#### Install / update semantics (clarified and tested)
- `install` now **always overwrites kit files** (skills, tooling configs, subagents, root `.md`). The `-Force` / `--force` flag has been removed — overwriting is the default and only mode.
- `install` continues to **never overwrite `docs/ai/`** — project content is always preserved.
- `update` is the MD5-diff-based path: only files that are missing or whose content differs are touched.

#### Subagent naming consistency (Codex)
- `codebase-explorer.toml` → `codebase-investigator.toml` to match Claude / Gemini.
- All `name = "..."` fields in Codex agents normalized to kebab-case
  (`code-reviewer`, `codebase-investigator`, `security-reviewer`, `test-runner`).

#### Subagent enrichment
- All five subagents in all three tools now include a "Context to read first" section pointing to `docs/ai/*` and the relevant skill file.

#### Engineering principles (all 3 root files)
- "Do not add dependencies without justification" upgraded to **"MIT license only. Avoid library bloat — if it can be done in ~20 lines of native code, do not pull a package."**

#### Definition of Done (all 3 root files)
- "covered by tests when practical" replaced by **"If tests are not added, state explicitly why and what should be tested manually."**

#### Gemini token budget
- Removed `includeDirectories: ["docs/ai"]` from `tooling/gemini/settings.json` — avoids loading all project docs into every session (~4 400 tokens saved per session).

#### Codex sandbox
- `project_doc_max_bytes = 32768` enabled in `tooling/codex/config.toml` (cap per-doc context size).

#### Claude permissions
- `WebFetch(domain:*)` deny replaced with an allowlist of documentation domains (docs.microsoft.com, learn.microsoft.com, vuejs.org, angular.dev, vitest.dev, npmjs.com).
- Added `vue-tsc`, `vite`, `vitest`, `npx vitest` to the bash allowlist.
- Added `git push --force-with-lease` and `git clean -fd` to deny (parity with `--force` and `reset --hard`).
- Branch-specific push restrictions (e.g. "deny push to main") cannot be expressed in the permission matcher (the `:*` wildcard only works at end-of-pattern). Enforcement of "no direct push to main / dev" stays in the `## Git rules` section of CLAUDE.md and at the GitHub branch-protection level.

#### CLAUDE.md
- Added `## Git rules` section (already present in AGENTS.md, missing here).

### Fixed

#### Install / update scripts
- `install.ps1` rewritten in ASCII — UTF-8 box-drawing characters were corrupting under Windows PowerShell 5.1 (Windows-1252 default reader).
- `update.ps1` rewritten in ASCII (same root cause).
- Gemini installer now copies `skills/` to `.gemini/skills/` — previously skipped, which broke the new GEMINI.md routing.
- `validate.ps1` strict-mode bug on `Select-String` returning a single object (not an array).

#### Repo hygiene
- Removed garbage directory `./{skills/{dotnet,angular,...}}` (result of an unexpanded bash brace expansion).
- Removed `./agents/` at repo root — duplicated `tooling/<tool>/agents/`, never installed by the scripts.
- Structural consistency: all skills now end with a "Final response requirements" section.

### Documentation
- README rewritten to reflect the new layout (`agents/` removed, mobile + transverse skills listed).
- README now includes:
  - Skill coverage table (backend / frontend / mobile / data / cross-cutting).
  - `prompts/` directory description with usage notes.
  - Install vs update semantics table.
  - `validate` script row.

---

## [1.0.0] - 2026-05-14

### Added
- Initial kit structure: skills, agents, tooling, project-template, prompts, scripts.
- Skills: dotnet, angular, vue, architecture, testing, code-review, database, security, github-workflow.
- Agents: codebase-investigator, code-reviewer, test-runner, architect, security-reviewer.
- Tooling adapters: Codex, Claude Code, Gemini CLI.
- Install scripts: PowerShell and Bash.
- Project template: PROJECT.md, ARCHITECTURE.md, DECISIONS.md, ROADMAP.md, COMMANDS.md, TESTING.md, GLOSSARY.md.
- Prompt templates: daily-ticket, feature-planning, code-review, bug-fix, refactor.

# Changelog

Older releases (1.22.0 and earlier) are archived in
[docs/CHANGELOG-archive.md](docs/CHANGELOG-archive.md).

## [Unreleased]

### Fixed

- **`docs(testing)` — testing docs listed shipped suites as planned and didn't
  say where each runs (#515).** `docs/ai/TESTING.md` "Planned Testing
  Improvements" still listed BATS, Pester, bash/PowerShell parity, router
  parity, stronger `validate` placeholder checks, and skill evals as future
  work — all of which ship and run in CI today — and `docs/SCOPE.md` classified
  the doctor command, init wizard, and skill evals as Future/experimental
  despite being implemented and tested. Rewrote the section as current state
  with a short genuinely-open list, fixed the SCOPE maturity rows, and added a
  "Where tests run" note (bats = Linux/CI, Pester = Windows, evals = both) so a
  Windows contributor knows bats failures there are environmental and which
  suite to run instead.

- **`docs(plugin)` — team-setup section named a nonexistent config file and
  mis-scoped `strictKnownMarketplaces` (#519).** The "Pinning and pre-enabling
  the plugin" recipe told teams to add keys to `CLAUDE.local.json` (not a real
  Claude Code file — personal overrides live in `.claude/settings.local.json`;
  `CLAUDE.local.md` is the memory file) and recommended `strictKnownMarketplaces:
  true` in project settings, but that key is documented as **managed-settings
  only**, so a project-level entry has no effect. Corrected the filename, moved
  `strictKnownMarketplaces` into a managed-settings note, and kept `enabledPlugins`
  in project `settings.json` (verified valid at project scope).

- **`docs(windows)` — tracked dogfood hooks are POSIX-flavored, leaving Windows
  contributors with silently dead hooks (#514).** The dogfood `.claude/settings.json`
  tracked here is the POSIX variant (`bash "…/hook.sh"`), so on a Windows clone
  where `bash` resolves to the WSL launcher stub the repo's own `pre-bash-guard`
  never runs — and CI cannot flag it. Added a "Contributing to ai-agent-kit from
  Windows" section to `WINDOWS_HOOKS.md` with a `where bash` sanity check, a
  copy-pasteable `.claude/settings.local.json` override that rewires the four
  hooks through `run-hook.ps1` (gitignored, so no drift), and a guard-is-live
  verification. Also corrected the stale "the WSL `System32\bash.exe` stub is a
  valid configuration and works" claim to match README's "Does not work".

- **`docs(governance)` — WORKFLOW/ARCHITECTURE/SCOPE still said the Antigravity
  dogfood was not tracked (#508).** Three governance docs described the
  pre-Antigravity state and contradicted both `git ls-files` (which tracks
  `.agy/`, `AGY.md`, `.agyignore`) and CI (`validate --strict` +
  `pr-versioning.yml`/`pr-dogfood-parity.yml` enforce all three trees). Added the
  agy artifacts to WORKFLOW.md's tracked list and removed the "do not track
  Antigravity" paragraph; updated ARCHITECTURE.md's directory table, dogfood
  vs source rows (with canonical `tooling/agy/` sources), update command, and
  invariants; widened SCOPE.md's guarantee and ADR-004 to
  Claude/Codex/Antigravity.

- **`docs(parity)` — PROVIDER_PARITY hook-events table overstated wired events
  (#510).** The table claimed events for all three providers that the shipped
  configs do not register. Corrected it to the actual wired sets — Claude:
  `PreToolUse`/`PostToolUse`/`PreCompact`/`Stop`; Codex: those plus
  `PermissionRequest` and `SessionStart` (PermissionRequest was missing);
  Antigravity: `BeforeTool` only — clarified that providers support more than
  the kit wires, and reconciled the Antigravity row with README.

- **`docs(security)` — README cosign verify example accepted any signer
  identity (#517).** The "Verifying a release" command used
  `--certificate-identity-regexp ".*"`, which accepts a signature from any
  GitHub Actions workflow in any repository, defeating identity verification.
  Pinned it to `"github.com/PetrovC/ai-agent-kit"`, matching the form in
  `docs/ai/RELEASE.md` so the two docs stay consistent.

- **`chore(scripts)` — purge removed audit-mode remnants (#511).** The deleted
  audit/metrics subsystem left contradictory remnants. Removed the phantom
  `--audit`/`-Audit` flag from the `install.sh` and `install.ps1` help text and
  examples (the parsers reject it), deleted the dead `tooling/shared/agent-audit`
  mappings from `validate.ps1` and `uninstall.ps1` (the directory does not
  exist), rewrote the `delegate.py` module docstring to match `DELEGATION.md`
  (status line on stderr; no audit events; `load_audit_config`/`emit` retained
  as no-ops), and dropped a stale agent-audit reference from an `install.sh`
  comment. Mirrored `delegate.py` to the dogfood copy.

- **`docs(readme)` — stale skill count, missing coverage rows, and an outdated
  PowerShell-prune caveat (#507).** Replaced the hard-coded "31 skills" with
  non-numeric phrasing (the tree now has 32 since the godot skill landed); added
  `godot` (new Game row) and `release-management` (Cross-cutting) to the Skill
  coverage table and the paths/no-paths explanatory lists; and dropped the
  "PowerShell parity tracked separately" note from the update semantics — both
  `update.sh` and `update.ps1` prune via the `.kit-manifest` diff.

- **`fix(bootstrap)` — `bootstrap.ps1` hard-required `pwsh`, breaking the
  Windows install on PowerShell 5.1-only machines (#505).** Stock Windows ships
  only Windows PowerShell 5.1; the installer invocation hard-coded `& pwsh ...`,
  so the released `irm .../bootstrap.ps1 | iex` path downloaded the archive then
  failed with `CommandNotFoundException: pwsh`, installing nothing. Now resolves
  the engine first (`Resolve-AakPowerShellEngine`): prefers `pwsh` when present,
  otherwise falls back to `powershell`, and prints which engine runs the
  installer. `install.ps1` is already 5.1-compatible. Covered by a new Pester
  test mocking both branches.

- **`docs(readme)` — pinned install examples referenced the nonexistent
  `v1.21.0` release (#506).** Every pinned `bootstrap.{sh,ps1}` example and the
  `git clone --branch` snippet in README pointed at `v1.21.0`, which 404s (the
  first release with working assets is `v1.22.1`). Repointed the pinned
  examples to `v1.23.0`, corrected the "available from" claim to `v1.22.1`, and
  updated the matching `-Version`/`--version` examples in
  `scripts/bootstrap.ps1` and `scripts/bootstrap.sh` help text.

## [1.23.0] - 2026-06-10

### Added

- **`test(skills)` — eval fixtures for 6 more skills, now gated in CI (#488).**
  `run-evals.sh` asserted real behavior for only 3 of 32 skills and ran in no
  workflow. Added fixtures for rust, angular, database, godot (glob routing +
  content terms) and the two path-less cross-cutting skills, architecture and
  security (content terms + a no-paths guard against overly broad globs):
  37 → 95 assertions. The `Offline routing eval` job now runs the suite and
  triggers on `tests/skills/**`.

- **`feat(dotnet)` — ASP.NET Core HTTP-layer reference (#485).** New
  lazy-loaded `skills/dotnet/references/aspnet-core-http.md` (`## Load when`):
  minimal APIs vs controllers with route groups and `TypedResults`,
  middleware pipeline ordering, `IExceptionHandler` + RFC 9457
  ProblemDetails, JWT + policy-based authorization, built-in OpenAPI
  (.NET 9+), validated options binding (`ValidateOnStart`), and cancellation
  tokens in handlers. Dotnet keywords extended (`minimal api`, `openapi`,
  `swagger`, `problemdetails`, `kestrel`) so HTTP tasks route without a `.cs`
  path; mirrored to the three dogfood trees and the manifest.

- **`feat(delegate)` — `AAK_DEBUG` surfaces the resolved depth & model (#477).**
  With `AAK_DEBUG` set (per the #305 convention, `0`/`false` mean off),
  `delegate.py` now prints one stderr line before invoking the provider:
  `AAK_DEBUG provider=… task_type=… risk=… depth=… tier=… model=…
  write_mode=…` (plus `effort=…` for Codex). Covered by three bats tests and
  two Pester twins; documented in `docs/ai/PROVIDER_PARITY.md`.

- **`feat(godot)` — add a Godot 4.x skill with a Rust GDExtension reference (#483).**
  New `skills/godot/SKILL.md` (typed GDScript, scene composition and
  "call down, signal up", autoloads, physics callbacks, GUT/gdUnit4 testing,
  GDScript-vs-Rust boundary table) plus a lazy-loaded
  `references/rust-gdextension.md` (`## Load when`): gdext crate setup
  (`godot = "0.5"`, `cdylib`), class registration (`#[derive(GodotClass)]`,
  `#[godot_api]`, interface traits), `.gdextension` descriptors, batching
  across the FFI boundary, panic safety, and per-platform build pitfalls.
  Mirrored to `.claude/`, `.agents/`, `.agy/` and registered in
  `.kit-manifest`. Scope notes added: `dotnet` (Godot C# is engine code, not
  ASP.NET Core) and `rust` (pointer to the godot skill for gdext work).
  Routing: `**/*.gd`, `**/*.tscn`, `**/*.tres`, `**/project.godot`,
  `**/*.gdextension` globs + engine-scoped keywords (no bare `node`/`signal`
  to avoid colliding with node/angular). Two routing fixtures
  (`godot-gdscript.yaml`, `godot-rust-gdext.yaml`) and three `routing.bats`
  assertions cover activation.
- **`docs(architecture)` — add legacy / modernization guidance (F-3, #460).**
  Extends `skills/architecture/SKILL.deep.md` (mirrored to `.claude/`, `.agents/`,
  `.agy/`) with a **Legacy / brownfield modernization** section: strangler-fig
  (seam → reimplement → flip → repeat), characterization tests as the safety net
  before refactoring, seam identification (Feathers), and incremental decomposition
  by business capability / dependency direction (modular-monolith-first), plus an
  anti-pattern list. To honor the audit's routing trigger the `architecture` and
  `testing` skills gain `keywords:` (`legacy`, `brownfield`, `modernize`,
  `modernization`, `strangler`; `testing` adds `characterization`) so a
  modernization task routes to both. A routing fixture
  (`tests/routing/fixtures/legacy-modernization.yaml`) and a `routing.bats`
  assertion cover activation. No new broad skill or subagent.
- **`docs(infrastructure)` — add cloud-provider specifics notes (F-2, #459).**
  Extends `skills/infrastructure/SKILL.deep.md` (mirrored to `.claude/`,
  `.agents/`, `.agy/`) with an IaC-first **Cloud provider specifics** section
  covering the cross-provider concepts that recur — workload identity over
  long-lived keys (AWS IRSA, Azure Managed Identity, GCP Workload Identity, CI
  OIDC), IAM least privilege, regions/data residency, cost tagging and budgets,
  and managed-over-self-hosted. Per the #424 audit there is **no new per-cloud
  skill** (provider SDKs/consoles change too fast); the durable layer is IaC, so
  this rides the existing `infrastructure` activation with no new routing trigger.
- **`feat(database)` — add a SQL Server / T-SQL reference (F-1, #458).** New
  lazy-loaded `skills/database/references/sql-server.md` (with a `## Load when`
  header, mirrored to `.claude/`, `.agents/`, `.agy/`) closes the only genuine
  *Missing* gap from the #424 coverage audit: SQL Server had no `database`
  coverage despite first-class `dotnet`/EF Core support. It covers T-SQL
  specifics, SQL Server indexing/locking (clustered index, RCSI, deadlocks),
  EF Core ↔ SQL Server mapping, migration scripting, and common pitfalls
  (parameter sniffing, implicit conversions, scalar UDFs). The `database` skill
  gains `keywords:` (`sql server`, `t-sql`, `mssql`, `sqlcmd`, `azure sql`) so a
  T-SQL task routes to it even without a `.sql` file, plus a `## References`
  section. A routing fixture (`tests/routing/fixtures/sql-server-tsql.yaml`) and
  two `routing.bats` assertions cover activation. No new broad skill or subagent.
- **`docs(coverage)` — add the skill/technology coverage matrix (#424).** New
  `docs/ai/SKILL_COVERAGE_MATRIX.md` audits the full skill/subskill/subagent
  surface against the stacks and technologies enumerated in #424 (backend,
  frontend, data, architecture, infrastructure, quality, project types). Each
  area is rated covered / covered-distributed / weak / missing / intentionally
  unsupported. The audit finds coverage already broad: the only genuine *Missing*
  gap is **SQL Server / T-SQL** (no `database` coverage despite first-class
  `dotnet`/EF Core), proposed as a lazy-loaded `database/references/` subskill
  (F-1) with metadata + routing fixture. Two doc-only follow-ups (cloud-provider
  specifics in `infrastructure`, legacy/modernization notes in `architecture`)
  are recorded with reasons and routing triggers. The audit recommends **no new
  broad skills and no new subagents**. The matrix is the deliverable for #424;
  proposed additions ship as their own issues/PRs per the ROADMAP issue rule.
- **`chore(governance)` — add `.github/CODEOWNERS` and document the `master`
  branch-protection posture.** OpenSSF Scorecard flagged Branch-Protection (no
  CODEOWNERS, administrators not included, last-push approval off) and
  Code-Review 0. A minimal CODEOWNERS now assigns the maintainer (`@PetrovC`) as
  default owner, with explicit ownership of the highest-risk surfaces
  (`/scripts/`, `/.github/workflows/`, `/skills/`). `docs/ai/WORKFLOW.md` gains a
  "Branch Protection" section describing the intended `master` posture: require
  PRs, require the `quality-gate` status check, require up-to-date branches,
  require Code Owners review, require last-push approval, and include
  administrators. Applying the toggles is a human-gated GitHub Settings step
  (Settings -> Branches), not code.
- **`ci(dogfood)` — require dogfood content + git-mode parity in CI.**
  `validate.sh --strict` already verifies that every tracked dogfood file
  (`.claude/`, `.codex/`, `.agents/`, `.agy/`, `AGENTS.md`, `CLAUDE.md`,
  `AGY.md`) matches its canonical source under `tooling/` or `skills/` — in both
  content and git-tracked mode — but that check ran nowhere in CI, so the
  tracked install could silently drift from source again (the class of bug PR
  #447 fixed: a dropped `statusline.sh`, a `token-log.sh` exec-bit downgrade).
  New workflow `pr-dogfood-parity.yml` runs `validate.sh --target . --strict`
  (bash, Ubuntu) and `validate.ps1 -Target . -Strict` (PowerShell, Windows) on
  every pull request; both job names are registered in
  `.github/required-checks.txt` so the quality gate blocks a drifting PR. New
  `tests/bats/dogfood_parity.bats` proves the gate trips on a mutated dogfood
  file and stays green on a clean tree.

### Changed

- **`docs(routing)` — stages 1/2/4 marked deterministic, 3/5 agent-driven (#470).**
  `ADAPTIVE_ROUTING.md` gains a determinism callout plus an Enforcement bullet
  per stage: intent classification, skill selection, and the delegation
  recommendation are code (`select-skills.py`); reference loading
  (`## Load when`) and synthesis are agent-followed prose with no code path.
  Same clarification in `skills/README.md` (and its dogfood mirrors).

- **`chore(changelog)` — archive released history older than 1.22.1 (#486).**
  `CHANGELOG.md` had grown to 261 KB (~65k tokens), a context hazard for any
  agent or release skill that opens it wholesale. It now keeps `[Unreleased]`
  plus the latest release; 1.22.0 back to 1.0.0 moved verbatim to
  `docs/CHANGELOG-archive.md`, linked from the header. The `validate.sh`
  CHANGELOG invariants read only the main file and pass unchanged.

- **`ci` — pin the provider-CLI installs in `agent-on-mention.yml`.** OpenSSF
  Scorecard flagged Pinned-Dependencies because the `@codex`/`@agy` jobs ran
  floating `npm install -g` commands. The Codex install is now pinned to
  `@openai/codex@0.137.0` (verified published on npm before committing). The
  Antigravity install keeps its floating form with a `TODO`: as of 2026-06-07
  `@antigravity/agy` is a placeholder — `npm view @antigravity/agy` returns 404,
  so there is no published version to pin; the comment records the reason and
  what to change when the real CLI ships. Both steps keep their best-effort
  `|| true` and the existing graceful-skip behavior, and the `if:` gates,
  maintainer gate, and env-based untrusted-body handling are unchanged.
- **`ci` — merge the @claude and @codex/@agy mention workflows into one.**
  `agent-on-mention.yml` now holds three gated jobs (`claude`, `codex`, `agy`)
  and `agent-codex-agy-on-mention.yml` is deleted. Both files previously
  subscribed to `issue_comment`, so every comment fired both workflows and the
  non-targeted one fully-skipped — which GitHub emails as a "Run skipped"
  notification (attributed to `master` HEAD). With one workflow, a single
  `@claude`/`@codex`/`@agy` comment produces one run where the matching job runs
  and the others skip silently (run conclusion `success`, no email); an ordinary
  comment produces one fully-skipped run instead of two. The security model is
  unchanged: top-level `permissions: contents: read`, per-job least-privilege
  writes, the maintainer (`OWNER`/`MEMBER`/`COLLABORATOR`) gate, and the
  injection-safe handling of the untrusted comment body are all preserved. Note
  added that maintainers should set GitHub Actions notifications to "failures
  only" to suppress any residual skip emails. A new `pr-docs.yml` semantics
  check guards the consolidation — it asserts the duplicate workflow stays
  deleted and that the triggers, top-level + per-job least-privilege
  permissions, mention gate, maintainer gate, and the `issue_comment`
  restriction for codex/agy remain intact.

### Fixed

- **`ci(release)` — release assets attach loudly and get per-archive signatures (#472).**
  v1.22.0/v1.22.1 published with zero assets while `release-checksums.yml`
  reported success, so the README one-liner
  (`releases/latest/download/bootstrap.sh`) 404s. The upload step now sets
  `fail_on_unmatched_files: true` (an empty release fails the run), and cosign
  also emits one keyless `.sigstore.json` bundle per archive next to the
  existing `SHA256SUMS.bundle`. `docs/ai/RELEASE.md` documents the asset list
  and the `cosign verify-blob` recipe. Closing the issue still needs a new
  release cut by the maintainer.

- **`fix(ci)` — quality gate no longer fails on stale cancelled duplicates (#500).**
  The check-runs API dedupes per check suite, not per name, so a re-triggered
  batch (e.g. the "Update branch" button cancelling a superseded run) left
  stale `cancelled` runs on the head SHA and `quality_gate.py` failed the
  gate even though the latest run of every check was green. `fetch_checks()`
  now keeps only the newest run per name (max `started_at`, tiebreak `id`) —
  the "latest run counts" semantics branch protection applies. New
  `tests/bats/quality_gate.bats` (6 pure-function tests, no `gh`/network);
  `pr-bats.yml` now also triggers on the script itself.

- **`fix(routing)` — route plain TypeScript files to the node skill (#498).**
  The node skill's `paths:` matched `**/*.js`/`**/*.mjs`/`**/*.cjs` and
  `tsconfig*.json` but no TypeScript sources, so a backend file like
  `src/server/app.ts` matched no skill at all. Added `**/*.ts`, `**/*.mts`,
  `**/*.cts` (mirrored to the three dogfood trees); `**/*.tsx` deliberately
  stays with react. New fixture + two bats regression tests (plain `.ts`
  routes to node; `.tsx` does not).

- **`ci(scorecard)` — drop the last top-level `contents: write` grant
  (#473).** `release-checksums.yml` declared `contents: write` +
  `id-token: write` at workflow level; both scopes now live on the single
  `checksums` job (release-asset upload + cosign keyless OIDC), with
  top-level `contents: read`. Every workflow is now read-only at top level,
  which is what Scorecard's Token-Permissions probe checks.

- **`fix(routing)` — thicker rust keywords; bare "migrate" no longer drags
  `dotnet` into frontend tasks (#484).** The `rust` skill now routes on
  `cargo`/`tokio`/`lifetime`/`borrow checker`/`crate`/`clippy`/`axum`/`sqlx`
  keywords (plus standard task intents), so Rust prompts without a `.rs` path
  select it. The data-migration intent requires a database signal
  (`database`/`db`, or `migrate`/`migration` with `sql`/`ef`/`schema`/
  `dbcontext` context) instead of bare "migrate" — "Migrate Angular component
  to signals" no longer selects `dotnet`. Two routing fixtures and three bats
  assertions added.

- **`fix(routing)` — model router no longer under-routes abstract review
  prompts (#469).** Intent keywords are now tokenized — every token must
  appear in the task text, in any order (word-prefix for tokens of 3+ chars,
  exact word for shorter ones), so "Review the proposed architecture" routes
  to `architecture_review`/`high_reasoning` instead of falling through to
  `implementation`/`balanced`. New `pr_review → high_reasoning` intent covers
  PR / code reviews; the `--risk high` manual escape hatch is documented in
  `docs/ai/MODEL_SELECTION.md`. Four routing tests added.

- **`fix(delegate)` — gate `--dangerously-skip-permissions` on `write_mode` for
  Antigravity (#476).** `build_antigravity_argv` appended the flag
  unconditionally — even for read-only depth — while `build_claude_argv` gates
  it on `write_mode`. Read-only Antigravity delegations now run with
  `--sandbox` only; implementation tasks keep the flag. The read-only routing
  tests now assert the flag is absent, and a regression test was added to both
  suites (bats + Pester).

- **`fix(routing)` — stop the `architecture` skill under-routing deep greenfield
  prompts (#468).** A textbook Clean-Architecture / DDD prompt ("clean
  architecture boundaries, aggregate consistency, bounded context") scored the
  `architecture` skill at 0 and was never selected, because the offline selector
  (`scripts/select-skills.py`) scores `keywords` but not `description`, and the
  skill's `keywords` only held the legacy/brownfield terms. The `architecture`
  skill (`skills/architecture/SKILL.md`, mirrored to `.claude/`, `.agents/`,
  `.agy/`) gains the greenfield vocabulary as keywords (`clean architecture`,
  `ddd`, `domain-driven design`, `cqrs`, `aggregate`, `value object`,
  `bounded context`, `event sourcing`, `hexagonal`, `ports and adapters`), so the
  prompt now selects `architecture` (score 3). Because the skill has no
  `task_intents`/`paths`, a lone incidental keyword (e.g. "aggregate" in a .NET
  task) stays at score 1, below the selection threshold, so backend routing is
  unchanged. A routing fixture
  (`tests/routing/fixtures/clean-architecture-greenfield.yaml`) and a
  `routing.bats` assertion cover activation.
- **`fix(delegate)` — make the Antigravity (`agy`) handoff functional: select the
  model per call and parse JSON output (#465).** A live test showed Antigravity
  delegation returning empty stdout and silently running the wrong model: the
  adapter passed the model as an environment hint (`ANTIGRAVITY_MODEL`) that
  `agy` ignores, and `agy -p` produced no parseable answer. The adapter
  (`tooling/shared/delegate/delegate.py`) now invokes
  `agy -m <model> -p "<brief>" --output-format json` — selecting the model with
  the supported `-m` flag (Opus for deep work, Sonnet for standard/readonly) and
  parsing the JSON response into a non-empty summary. The selected model is shown
  in a `delegate:` stderr debug line for verification. The dead env-hint
  mechanism (`provider_env`, `ANTIGRAVITY_MODEL_ENV`) is removed. Because Opus and
  Sonnet share the Anthropic quota, the **deep** quota-fallback now crosses pools
  from `claude-opus-4-6` to `gemini-3.1-pro` (standard/readonly already fell back
  to Gemini). The bats/Pester suites now assert the model via the recorded argv
  (not the env var). Also folds in a latent decode bug: `run_provider` now decodes
  provider output as UTF-8 (`encoding="utf-8", errors="replace"`) instead of the
  Windows locale (cp1252), which raised `UnicodeDecodeError` on UTF-8 output. The
  fail-open contract and the `delegate-status:` line (#466) are unchanged. Docs:
  `docs/ai/DELEGATION.md`, `docs/ai/MODEL_ROUTING.md`.
- **`fix(delegate)` — surface an explicit handoff status so the adapter is no
  longer silently fail-open (#466).** The cross-tool delegation adapter
  (`tooling/shared/delegate/delegate.py`) returned exit 0 for success, empty
  results, an unavailable provider CLI, and a failed provider alike, so an
  orchestrator could not tell a usable answer from a no-op. The adapter now
  always writes one final machine-parseable line to **stderr** —
  `delegate-status: status=<ok|empty|skipped|error> provider=… exit_code=… summary_chars=… fallback_used=…`
  — while preserving the fail-open exit code (still `0` on every path, as
  `docs/ai/DELEGATION.md` documents). `ok` = provider exited 0 with a non-empty
  summary; `empty` = exited 0 but produced nothing; `skipped` = exit 127 (CLI
  unavailable); `error` = any other non-zero exit (including timeout 124). The
  contract is documented in `docs/ai/DELEGATION.md`, and the bats/Pester suites
  gain a test per outcome.
- **`fix(delegate)` — align the Antigravity high-reasoning model ID with the
  runtime adapter and guard against future drift (#467).** `config/model-policy.yaml`
  listed the Antigravity `high_reasoning` model as `claude-opus-4-8`, but
  Antigravity only exposes Opus **4.6** — the runtime adapter
  (`tooling/shared/delegate/delegate.py`, `ANTIGRAVITY_MODEL_BY_DEPTH["deep"]`)
  correctly uses `claude-opus-4-6`. The policy entry is corrected (the Claude
  provider stays `claude-opus-4-8`), and the same stale ID is fixed in the
  human-companion docs (`docs/ai/MODEL_SELECTION.md`, `docs/ai/DELEGATION.md`). A
  new static consistency guard in `tests/bats/model-routing.bats` parses both the
  policy file and the adapter's model maps (via `ast`, without importing the
  module) and fails if any provider's policy tier disagrees with the adapter depth
  it maps to (`high_reasoning↔deep`, `balanced↔standard`, `fast↔readonly`), for
  both Claude and Antigravity; `pr-routing.yml` now also runs on `delegate.py`
  changes so adapter-side drift is caught too.
- **`fix(delegate)` — delegation egress redacts secrets instead of blocking, and
  closes the AWS / fine-grained-GitHub gap (#464).** The cross-tool delegation
  privacy gate (`tooling/shared/delegate/delegate.py`) matched a weaker pattern
  set than `scripts/sanitize.sh`, so an AWS access key (`AKIA…`) or a fine-grained
  GitHub token (`github_pat_…`) in a brief could reach a third-party CLI, and the
  gate blocked-or-allowed the whole brief rather than redacting it. A new canonical
  module `tooling/shared/delegate/sanitize_patterns.py` is now the single source of
  truth for egress redaction — covering AWS keys, classic and fine-grained GitHub
  tokens, bearer tokens, private RFC1918 IPs, internal hostnames, secret key/value
  pairs, and OpenAI/GitLab keys — and the brief is **redacted** (not skipped)
  before it is sent, with the provider summary redacted by the same function.
  `scripts/sanitize.{sh,ps1}` gain the matching OpenAI/GitLab token rules, and a
  new `tests/bats/sanitize_parity.bats` proves the standalone sanitizer and the
  egress redact the same secret categories.
- **`docs(readme)` — correct two inaccurate claims to match the repo.** The
  dogfood paragraph omitted the tracked Antigravity files and wrongly stated that
  "Antigravity root install output ... stay ignored"; in fact `AGY.md`, `.agy/`,
  and `.agyignore` are tracked and the `dogfood-install-policy` job in
  `pr-versioning.yml` *requires* them tracked. They are now listed and the stale
  clause is gone, so the README agrees with CI. The "Security posture" CodeQL
  bullet implied CodeQL covers this repo's code; there is no CodeQL workflow and
  CodeQL does not analyze bash/PowerShell (the bulk of the kit). It now states
  that static analysis is PSScriptAnalyzer (`powershell.yml`) plus shell
  validation (`pr-scripts-shell.yml`), and that GitHub code scanning / CodeQL
  default setup, if enabled, covers only the Python helper scripts.

## [1.22.1] - 2026-06-06

### Fixed

- **`fix(scripts)` — make lifecycle scripts work from the flat release archive.**
  `install.sh`, `update.sh`, `uninstall.sh`, `new-skill.sh`, and `doctor.sh`
  (plus their `.ps1` twins) assumed they always live in `scripts/` and resolved
  the kit root one level up (`$SCRIPT_DIR/..`). In a release archive (produced by
  `release-checksums.yml`) the scripts sit at the archive root beside
  `VERSION`/`skills/`/`tooling/`, so the documented
  `curl … releases/latest/download/bootstrap.sh | bash` install aborted with
  `Error: VERSION file not found`. The scripts now detect the layout via the
  `VERSION` sentinel beside the script: present → flat archive root, absent →
  repo `scripts/` (kit root one level up). A new `pr-scripts-shell.yml` job
  assembles `dist/` exactly as the release workflow does and asserts a clean
  install + healthy `doctor.sh` from the flat layout, closing the coverage gap
  that let this ship (CI only ever installed from the repo checkout).

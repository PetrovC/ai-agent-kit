# Changelog

Older releases (1.22.0 and earlier) are archived in
[docs/CHANGELOG-archive.md](docs/CHANGELOG-archive.md).

## [Unreleased]

### Added

- **`feat(dotnet)` — ASP.NET Core HTTP-layer reference (#485).** New
  lazy-loaded `skills/dotnet/references/aspnet-core-http.md` (`## Load when`):
  minimal APIs vs controllers with route groups and `TypedResults`,
  middleware pipeline ordering, `IExceptionHandler` + RFC 9457
  ProblemDetails, JWT + policy-based authorization, built-in OpenAPI
  (.NET 9+), validated options binding (`ValidateOnStart`), and cancellation
  tokens in handlers. Dotnet keywords extended (`minimal api`, `middleware`,
  `openapi`, `swagger`) so HTTP tasks route without a `.cs` path; mirrored to
  the three dogfood trees and the manifest.

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

# Testing Strategy

`ai-agent-kit` is mostly Markdown, shell, PowerShell, JSON, TOML, and workflow
configuration. Validation focuses on file presence, template completion,
install/update/uninstall behavior, hook behavior, and semantic consistency
between provider adapters.

## Test Levels

| Level | Scope | Tooling | Location |
|---|---|---|---|
| Documentation validation | Filled `docs/ai` templates, required files, and source-repo dogfood drift | `scripts/validate.ps1`, `scripts/validate.sh` | `scripts/` |
| Script behavior | Install, update, uninstall, dry-run, manifest behavior | PowerShell and Bash scripts, CI workflows | `scripts/`, `.github/workflows/` |
| Hook behavior | Claude/Codex guard, format, notify, session summary | Shell scripts and workflow checks | `tooling/*/hooks/`, `.github/workflows/` |
| Semantic lint | Cross-tool consistency, action templates, model/config drift | GitHub Actions and repository checks | `.github/workflows/` |
| Manual review | Documentation accuracy, issue scope, PR scope | Human review plus agent review | PR review |

## Current CI Strategy

The current checks are stronger than simple documentation linting. They cover:

- validation of `examples/filled-project`;
- smoke install on Linux Bash;
- smoke install on Windows PowerShell;
- update dry-run behavior;
- uninstall dry-run behavior;
- shell syntax checks;
- ShellCheck where available in CI;
- hook behavior matrix for `pre-bash-guard`;
- non-guard hook smoke checks;
- Claude tooling validity checks;
- Codex tooling validity checks;
- Antigravity tooling validity checks;
- routing consistency checks;
- workflow semantic checks;
- plugin and marketplace manifest version checks.

These checks do not replace unit tests for script helpers. They are practical
smoke and semantic checks for a repository whose core is shell, PowerShell,
Markdown, TOML, JSON, YAML, and provider configuration.

## Required Before PR

- Run `scripts/validate.ps1 -Target "."` on Windows or
  `./scripts/validate.sh --target .` on POSIX when `docs/ai` or root
  Claude/Codex dogfood files change.
- Run the relevant script dry-run when changing update or uninstall behavior.
- Run targeted hook tests when changing hook scripts or hook wiring.
- Inspect generated diffs for accidental template or provider drift.
- State any commands that could not be run and why.

## Documentation Checks

- No template warning notices remain in `docs/ai`.
- No HTML placeholder comments remain in `docs/ai`.
- No placeholder rows, placeholder bullets, or generic stack examples remain.
- Planned work is described as planned, not completed.
- `docs/ai` does not duplicate the full README.
- `docs/ai` does not contradict README install/update semantics.

## Script Change Checks

Do not change scripts without a dedicated issue. When an issue does authorize a
script change, verify both Windows and POSIX variants where possible:

- `install.ps1` and `install.sh`
- `update.ps1` and `update.sh`
- `uninstall.ps1` and `uninstall.sh`
- `validate.ps1` and `validate.sh`
- `new-skill.ps1` and `new-skill.sh`

The Bash and PowerShell scripts already show meaningful care around manifests,
dry-runs, preservation, and path handling. Future work should test that care in
isolation instead of undervaluing or rewriting it without evidence.

## Testing tooling: current state

The improvements once tracked here as future work have shipped and run in CI:

- **BATS** suites for the Bash lifecycle scripts and hooks (`tests/bats/`,
  `PR — BATS`).
- **Pester** suites for the PowerShell lifecycle scripts (`tests/pester/`,
  `PR scripts PowerShell`).
- **Bash/PowerShell output parity** checks (`pr-parity`, `pr-install-parity`,
  `pr-dogfood-parity`).
- **Router parity** across `AGENTS.md`, `CLAUDE.md`, and `AGY.md`
  (`pr-router-parity`).
- **Stronger `validate` checks** for unresolved placeholders and stale template
  content (`scripts/validate.{sh,ps1}`; see *Documentation Checks* above).
- **Skill evals** — the offline routing eval, CI-gated since #488
  (`PR — routing eval`).

Still genuinely open — each needs its own scoped GitHub issue before
implementation:

- Optional fuzzing for `pre-bash-guard`.
- A `python3 → python` fallback in `tests/bats/bats_helper.bash` so the bats
  suite can also run on hosts where `python3` is unavailable (see
  *Where tests run* below).
- Public release checks for release tags and the release checklist (the root
  `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, and `VERSION` files already
  exist and `validate` checks CHANGELOG release metadata).

## Where tests run

The two unit suites are platform-split by design; pick the suite for your host:

- **bats — Linux / CI.** The BATS suite is validated on Ubuntu (the `PR — BATS`
  workflow). On Windows Git Bash many tests fail for environmental reasons that
  are **not** product bugs: `python3` resolves to the Microsoft Store
  `WindowsApps` stub, and NTFS does not emulate the POSIX exec bit that the
  doctor-executability test asserts. A Windows contributor should expect these
  failures and run Pester instead.
- **Pester — Windows.** The PowerShell suite (`tests/pester/`) is the unit suite
  to run on Windows; it is also exercised on the GitHub-hosted Windows runner.
- **Skill evals — both.** The offline routing eval runs on Linux/CI and on
  Windows via Git Bash.

## Quality gate (required status)

CI is split across many workflows, each with its own job names. If branch
protection listed every job by name, renaming one would silently drop it from
the required set. Instead, branch protection requires a single check —
`quality-gate` (`.github/workflows/quality-gate.yml`) — which reflects all the
others.

How it works (`.github/scripts/quality_gate.py`):

- It polls the GitHub check-runs API for the PR head commit until the
  **mandatory** checks are present and every check has completed (or a timeout).
- It then **fails** if any mandatory check is missing — a missing mandatory check
  means a rename/removal, so failing is the safe outcome — or if any check that
  ran (and is not explicitly optional) did not pass.

Two maintained lists:

- **`.github/required-checks.txt`** — mandatory checks (must be present **and**
  pass). Only jobs that run on every `pull_request` belong here. Add a line when
  a new always-run job is introduced; if a listed name stops matching a real job
  (a rename), the gate fails because that check is then missing on the commit.
- **`.github/optional-checks.txt`** — advisory checks that never block (empty by
  default). Anything not in either list still has to pass **if it runs**
  ("present must pass"), so new checks (e.g. CodeQL `Analyze (...)`) block by
  default rather than being silently ignored.

Path-filtered jobs (e.g. `BATS (Ubuntu)`, which runs only on `.sh` / `tests/bats`
changes) are intentionally **not** mandatory — they may be legitimately absent —
but they still must pass when they do run. The `@claude` / `@codex` / `@agy`
mention workflows do not run on `pull_request` and are excluded.

**Branch protection:** require only the `quality-gate` status check on the
protected branches (`master`). After this lands, update branch protection to drop
the individual job names and add `quality-gate`.

## Test Data and Fixtures

Prefer small disposable target directories for script tests. Never run install,
update, or uninstall against a real project without confirming the target path
and using dry-run where available.

## PR Evidence

PRs should include:

- commands run;
- relevant exit codes;
- summary of changed files;
- risks and assumptions;
- any skipped verification with reason.

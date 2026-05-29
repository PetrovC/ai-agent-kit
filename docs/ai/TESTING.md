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

## Planned Testing Improvements

Each improvement below requires its own scoped GitHub issue before
implementation:

- BATS tests for Bash helpers.
- Pester tests for PowerShell helpers.
- Bash/PowerShell output parity checks.
- Router parity checks across `AGENTS.md`, `CLAUDE.md`, and `AGY.md`.
- Stronger `validate` checks for unresolved placeholders and stale template
  content.
- Optional fuzzing for `pre-bash-guard`.
- Future skill evals, probably outside required CI at first.
- Public release checks for root `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`,
  root `VERSION`, release tags, and release checklist.

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

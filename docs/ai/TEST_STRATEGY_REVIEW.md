# Test Strategy Review

**Date:** 2026-05-29

---

## Current Tests

### BATS (Bash)

Location: `tests/bats/`

| File | Coverage |
|---|---|
| `agent_audit_runtime.bats` | Audit runtime script behavior |
| `arg_parsing.bats` | Script argument validation |
| `bats_helper.bash` | Shared helpers |
| `idempotent_copy.bats` | Install/update idempotency |
| `manifest.bats` | `.kit-manifest` read/write |
| `sanitize.bats` | `sanitize.sh` redaction correctness |
| `validate_release.bats` | CHANGELOG/VERSION release invariants (9 tests) |
| `validate_strict.bats` | `validate.sh --strict` mode |

CI: `pr-bats.yml` runs on Ubuntu.

### Pester (PowerShell)

Location: `tests/pester/`

| File | Coverage |
|---|---|
| `AgentAuditRuntime.Tests.ps1` | Audit runtime PowerShell |
| `ArgParsing.Tests.ps1` | PowerShell argument validation |
| `IdempotentCopy.Tests.ps1` | Install/update idempotency (ps1) |
| `Manifest.Tests.ps1` | `.kit-manifest` (ps1) |
| `PesterHelper.ps1` | Shared helpers |
| `Sanitize.Tests.ps1` | `sanitize.ps1` redaction |
| `ValidateRelease.Tests.ps1` | CHANGELOG/VERSION (ps1) |
| `ValidateStrict.Tests.ps1` | Validate strict mode (ps1) |

CI: `pr-scripts-powershell.yml` runs on Windows via `pwsh`.

### CI Document/Structure Tests

`pr-docs.yml` enforces:
- Skill structure (every skill has SKILL.md with "Final response requirements").
- YAML syntax across all workflow files.
- Router parity: every skill appears in CLAUDE.md, AGENTS.md, AGY.md routing tables.
- Subagent parity: 5 named agents identical across providers.
- Antigravity model whitelist check.
- Intra-repo markdown link resolution.
- CHANGELOG presence on feat/fix/perf PRs.

### Install Parity Tests

`pr-install-parity.yml`: Runs `install.sh` on Ubuntu and `install.ps1` on Windows,
captures file lists, diffs them. Fails on unexplained divergence.

---

## Missing Tests

| Gap | Impact | Linked Issue |
|---|---|---|
| No hook execution tests (real invocation of pre-bash-guard, format-on-save, etc.) | Cannot verify hooks fire correctly | #180 / #178 |
| No Antigravity-specific hook tests | Antigravity hooks added in PR #296 but not integration-tested | #178 |
| No skill eval harness | Cannot detect skill regressions | #167 |
| No `doctor.sh` tests | Script doesn't exist yet | #149 |
| No router parity CI check across provider root files (CLAUDE.md / AGENTS.md / AGY.md headings) | Heading drift not caught | #148 |

---

## Weak Tests

| Area | Weakness |
|---|---|
| Audit runtime tests | Do not verify that audit events are queryable / report correctly end-to-end |
| Validate release | Happy-path and some edge cases covered; does not test malformed semver with pre-release suffix interactions |

---

## Quality Gate Recommendation

**Current state:** 9 separate CI workflows. Branch protection must require each one by name.
When a workflow is renamed, branch protection silently stops requiring it.

**Recommended design:**
- Add a final `quality-gate` job in a new or existing workflow that `needs:` all mandatory jobs.
- GitHub branch protection requires only `quality-gate`.
- Optional/experimental checks omitted from `quality-gate.needs`.
- Skipped jobs (e.g., Windows-only on Linux PRs) must be handled: use `if: always()` with
  explicit pass/skip logic, not bare `needs:`.

**Reference:** GitHub Actions `needs` + `if: always()` pattern for aggregate gates.
See: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/using-jobs-in-a-workflow#defining-prerequisite-jobs

This is tracked as a new issue (created this session).

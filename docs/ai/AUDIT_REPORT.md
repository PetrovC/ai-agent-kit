# Audit Report

**Date:** 2026-05-29
**Branch audited:** master (commit 457092a)
**Auditor:** Claude (claude-sonnet-4-6)
**Scope:** Full repository — core kit product, dogfood self-installation,
Gemini-to-Antigravity migration, CI, tests, scripts, hooks, governance.

---

## Current State

Validation passes cleanly:

```
bash scripts/validate.sh --target .
# All checks passed. 166 dogfood file(s) match source.
```

No open pull requests. 32 open issues. Working tree clean.

---

## Core Kit Product Findings

**Working:**
- Install and update scripts (sh + ps1) deploy all three providers: Claude, Codex, Antigravity.
- 30 shared skills under `skills/*/SKILL.md`, all with `allowed-tools` frontmatter.
- 12 Claude commands under `tooling/claude/commands/`.
- 11 Antigravity commands under `tooling/agy/commands/`.
- Subagent definitions under `tooling/claude/agents/`, `tooling/agy/agents/`, `tooling/codex/` (via AGENTS.md).
- Hooks: Claude has 6, Codex has 5, Antigravity has 3 (gap — see issues #178).
- `scripts/validate.sh` and `scripts/validate.ps1` enforce dogfood drift, router budgets, skill structure,
  Antigravity model whitelist, CHANGELOG/VERSION invariants.
- BATS suite (8 test files) and Pester suite (8 test files) cover script lifecycle.
- `scripts/sanitize.sh` / `scripts/sanitize.ps1` redact sensitive data before log sharing.
- `scripts/new-skill.sh` / `scripts/new-skill.ps1` scaffold new skills.

**Partial / open:**
- No `scripts/doctor.sh` yet (issue #149).
- No `--profile minimal` install yet (issue #170).
- Codex subagents use emulated skill-dir pattern, not native `[agents.<name>]` tables (issue #179).
- Claude hooks: 8 of 12 events unused (issue #180).
- Codex granular approval policy not adopted (issue #186).
- No `release-management` shared skill (issue #250).
- No `/release-check` or `/cut-release` Claude commands (issue #252).

**Documented but not implemented:**
- `docs/ai/RELEASE.md` describes the full release flow; no `/release-check` or `/cut-release`
  commands exist yet to operationalize it (issue #252).

**Implemented but not documented:**
- None found.

**Missing for real target repository usage:**
- A `doctor` script for health-checking an installed kit.
- Release commands to make the release flow repeatable and safe for agents.

---

## Dogfood / Self-Installation Findings

- 166 dogfood files match their sources exactly. No drift.
- All 3 providers installed: Claude (`.claude/`), Codex (`.codex/`), Antigravity (`.agy/`).
- All hooks execute via `run-hook.ps1` on Windows and directly on POSIX.
- `.agy/hooks/` is missing `format-on-save.sh`, `notify-done.sh`, `session-summary.sh` — same gap as core kit (issue #178).
- No obsolete `.gemini/` directory (removed by PR #298).
- `CLAUDE.md` and `AGY.md` at root are dogfood copies of `tooling/claude/CLAUDE.md` and `tooling/agy/AGY.md` respectively. Both confirmed identical to sources.

---

## Gemini-to-Antigravity Migration Findings

The migration is complete and coherent. See Phase 4 answer below.

1. **Gemini as a direct active agent:** No. `tooling/gemini/` does not exist.
2. **Antigravity as the correct replacement:** Yes. `tooling/agy/` is the active directory.
3. **Active docs aligned with Antigravity:** Yes, with one exception:
   - Issue #250 body references `tooling/gemini/GEMINI.md` — path does not exist. Should be `tooling/agy/AGY.md`. Issue body updated.
   - Issue #148 body references `tooling/gemini/GEMINI.md` — same correction needed. Issue body updated.
   - Issue #178 title uses "gemini" branding for what is an Antigravity hook parity task.
4. **Model references:** Antigravity uses Google Gemini model names (`gemini-3-flash`, `gemini-3.1-pro`). These are valid and intentional. The `pr-docs.yml` APPROVED_MODELS whitelist confirms this.
5. **Provider parity claims:** Antigravity has fewer hooks than Claude/Codex. Documented as open issue #178.
6. **Tests proving migration:** `pr-docs.yml` Antigravity model drift check validates model names on every PR. Install parity CI (`pr-install-parity.yml`) confirms Antigravity files are installed correctly.
7. **BACKLOG.md staleness:** Issue #143 is shown as 🟢 open in BACKLOG.md but is already closed on GitHub. BACKLOG.md needs a status refresh (tracked in GAP_ANALYSIS as P3).

---

## Verified Behavior

| Claim | Verified | Evidence |
|---|---|---|
| validate.sh passes on dogfood | Yes | Command output above |
| 166 dogfood files match sources | Yes | validate.sh output |
| No `.gemini/` directory exists | Yes | `ls tooling/` shows only agy/claude/codex/shared |
| CLAUDE.md == tooling/claude/CLAUDE.md | Yes | `diff` showed IDENTICAL |
| .agy/settings.json == tooling/agy/settings.json | Yes | Agent subcheck confirmed identical |
| Gemini model names in AGY settings are GA | Yes | pr-docs.yml APPROVED_MODELS whitelist |

---

## Untested Behavior

- Live hook execution for Antigravity (can only be verified in a real `agy` session).
- Windows hook wrapper behavior (requires Windows environment).
- Install on a fresh target repository (no target available in this session).
- `scripts/doctor.sh` — does not exist yet.

---

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| No quality-gate aggregator — branch protection cannot require a single job | P2 | Track as new issue |
| Antigravity hooks incomplete — 3 of 6 hooks missing | P1 (open #178) | Implement #178 after #252 |
| Issue bodies #250 and #148 reference non-existent Gemini paths | P1 | Issue bodies updated this session |
| BACKLOG.md stale status markers | P3 | Update separately |

---

## Recommendations

1. Implement issue #252 first (release commands) — safe, scoped, no dependencies.
2. Then implement issue #178 (Antigravity hooks parity) — P1, closes a real gap.
3. Add a quality-gate CI aggregator job.
4. Keep one PR per issue.

# Implementation Plan

**Date:** 2026-05-29
**Based on:** AUDIT_REPORT.md, GAP_ANALYSIS.md (same session)

---

## Prioritized Issue Backlog

### P1 — High (implement before new features)

| Issue | Title | Dependencies |
|---|---|---|
| #178 | feat(agy): Antigravity hooks parity (format-on-save, notify-done, session-summary) | None |
| #179 | feat(codex): migrate subagents to native `[agents.<name>]` tables | #144 (profile docs) |
| #186 | feat(codex): adopt granular approval policy + SessionStart/PermissionRequest hooks | None |

### P2 — Normal (implement after P1)

| Issue | Title | Dependencies |
|---|---|---|
| **#252** | feat(claude): add `/release-check` and `/cut-release` commands | None — **selected first** |
| New (quality-gate) | ci: add quality-gate aggregator job | None |
| #250 | feat(shared): add release-management skill | None |
| #180 | feat(claude): adopt additional hook events | None |
| #149 | feat(scripts): add doctor.sh + doctor.ps1 | None |
| #194 | chore: consolidate .mcp.example.jsonc to single source | None |
| #148 | ci: router parity check across CLAUDE.md / AGENTS.md / AGY.md | None |

### P3 — Later

| Issue | Title |
|---|---|
| #190 | feat(claude): teammateMode docs |
| #189 | feat(claude): worktree settings guidance |
| #167 | feat(skills): lightweight skill evals |
| #158 | refactor(skills): split skills >200 lines |
| #166 | feat(skills): per-skill version metadata |

---

## Issues Created This Session

| Issue | Title | Priority | Reason |
|---|---|---|---|
| New | ci: add quality-gate aggregator job | P2 | No single CI job exists for branch protection to require |

## Issues Updated This Session

| Issue | Change |
|---|---|
| #250 | Body: replaced `tooling/gemini/GEMINI.md` with `tooling/agy/AGY.md`; removed `.gemini/skills/` reference |
| #148 | Body: replaced `tooling/gemini/GEMINI.md` with `tooling/agy/AGY.md` |

## Issues Reused (no change needed)

All 32 existing open issues are valid and appropriately scoped. No duplicates found.

---

## Why #252 Is Selected First (Not a P1)

No P0 issues exist. No broken CI, no security risk, no data loss risk.

P1 issues (#178, #179, #186) all require live provider verification (running `agy`, `codex`)
that is not available in this session. Implementing them without live testing would be unsafe.

Issue #252 is purely additive (new files, no behavior change to existing code), fully
testable with `validate.sh`, and directly useful for the kit's own release process.

---

## First Implementation: Issue #252

**Branch:** `claude/determined-goldberg-f8Hw6` (designated session branch)

**Files to create:**
- `tooling/claude/commands/release-check.md`
- `tooling/claude/commands/cut-release.md`
- `.claude/commands/release-check.md` (dogfood copy)
- `.claude/commands/cut-release.md` (dogfood copy)

**Files to modify:**
- `tooling/claude/CLAUDE.md` — command table: add 2 rows, update count from 12 to 14
- `CLAUDE.md` — same change (dogfood copy)
- `.kit-manifest` — add 2 entries for the new dogfood command files
- `CHANGELOG.md` — add entry under `[Unreleased]`

**Validation command:**
```
bash scripts/validate.sh --target .
```

**Expected result:** All checks pass, dogfood drift check shows 168 files (was 166).

---

## Next Recommended Issue After First PR

**Issue #178** — feat(agy): Antigravity hooks parity.

Why: It is the highest-priority remaining gap that does not require external verification
beyond what can be confirmed from the existing hook scripts and Antigravity settings schema.
The missing hooks (`format-on-save.sh`, `notify-done.sh`, `session-summary.sh`) already
exist under `.claude/hooks/` and `.codex/hooks/` as reference implementations.

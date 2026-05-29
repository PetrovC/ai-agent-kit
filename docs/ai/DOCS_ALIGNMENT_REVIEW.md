# Documentation Alignment Review

**Date:** 2026-05-29

---

## README

**Location:** `README.md`

| Claim | Status | Notes |
|---|---|---|
| 3 active providers: Claude, Codex, Antigravity | Correct | README table covers all three |
| 30 skills | Correct | `ls skills/ | wc -l` = 30 |
| 12 Claude commands | Stale after #252 | Will become 14 once #252 merges |
| Install script installs Claude, Codex, Antigravity | Correct | Verified by install parity CI |
| Plugin marketplace available | Correct | `.claude-plugin/` and `marketplace.json` exist |

**Gap:** README will need command count updated from 12 to 14 after issue #252 merges. The
`CLAUDE.md` update in #252 handles this for the in-repo dogfood file.

---

## CHANGELOG

**Location:** `CHANGELOG.md`

- Exactly one `[Unreleased]` section: confirmed by validate.sh.
- No duplicate version sections: confirmed.
- All version headings use valid format: confirmed.
- Most recent entries document the Antigravity migration (PRs #296–#299) correctly.

**Gap:** CHANGELOG entry for the current session's work (audit docs + #252 commands) must be
added before the PR merges. This is done as part of implementing #252.

---

## Install / Update Docs

`docs/ai/COMMANDS.md` documents local install, update, uninstall, validate commands.
Verified accurate against `scripts/` contents.

**Gap:** No `doctor.sh` command exists yet; COMMANDS.md does not mention it. This will be
handled when issue #149 is implemented.

---

## Migration Docs

The Gemini-to-Antigravity migration is documented in:
- `CHANGELOG.md` entries for PRs #296, #297, #298, #299.
- `docs/ai/DECISIONS.md` (ADR-008 referenced in issue trackers).

**Gap:** Issue #250 body referenced `tooling/gemini/GEMINI.md` instead of `tooling/agy/AGY.md`.
Updated this session.

**Gap:** Issue #148 body referenced `tooling/gemini/GEMINI.md` instead of `tooling/agy/AGY.md`.
Updated this session.

---

## Troubleshooting Docs

No dedicated troubleshooting document exists. The `CONTRIBUTING.md` mentions
`validate.sh` as the primary diagnostic tool.

**Gap:** A short troubleshooting section (hook not firing, install drift, validate failures)
would help users. Low priority — not tracked as a new issue since no concrete user pain is
evidenced beyond what validate.sh already surfaces.

---

## Gemini-to-Antigravity Documentation Gaps

| Location | Reference | Classification | Action |
|---|---|---|---|
| `docs/ai/MODEL_ROUTING.md` | `gemini-3.1-pro`, `gemini-3-flash` as AGY models | Valid for Antigravity | No change needed |
| `tooling/agy/AGY.md` + agent frontmatter | `gemini-3.1-pro` / `gemini-3-flash` (was `agy-*`) | Corrected — standardized on the GA Gemini IDs | Fixed (#302) |
| Issue #250 body | `tooling/gemini/GEMINI.md` | Obsolete path | Updated to `tooling/agy/AGY.md` |
| Issue #148 body | `tooling/gemini/GEMINI.md` | Obsolete path | Updated to `tooling/agy/AGY.md` |
| Issue #178 title | `feat(gemini):` prefix | Misleading — should be `feat(agy):` | Cosmetic; acceptable as-is |
| `docs/ai/BACKLOG.md` | #143 shown as open | Stale — #143 is closed on GitHub | P3; update BACKLOG in a future pass |

---

## Core Kit vs Dogfood Documentation Gaps

Both `tooling/claude/CLAUDE.md` and root `CLAUDE.md` are identical (confirmed by `diff`).
Both `tooling/agy/AGY.md` and root `AGY.md` are identical (confirmed by validate.sh).

The distinction between "this is a kit source file" and "this is a dogfood copy" is not
surfaced to the reader of root files. This is intentional — root files serve as working
agent instructions. The validate.sh drift check enforces consistency.

No documentation gap requiring a new issue.

---

## ADRs

Located in `docs/ai/DECISIONS.md`. Referenced ADRs (001–017) cover:
shell parity, router brevity, context governance, audit schema, model routing, etc.

All referenced ADRs exist within DECISIONS.md or are cross-referenced to open issues.
No stale ADR references found.

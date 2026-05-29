# Gap Analysis

**Date:** 2026-05-29
**Audit basis:** AUDIT_REPORT.md (same session)

---

| # | Gap | Severity | Area | Core kit / Dogfood / Both | Evidence | Issue | Priority |
|---|---|---|---|---|---|---|---|
| G-01 | No `/release-check` or `/cut-release` Claude commands | P2 | Claude commands | Core kit + Dogfood | `ls tooling/claude/commands/` shows 12 files, neither present | #252 | P2 |
| G-02 | No shared `release-management` skill | P2 | Skills | Core kit | `ls skills/` — no release-management directory | #250 | P2 |
| G-03 | Antigravity missing 3 hooks: `format-on-save`, `notify-done`, `session-summary` | P1 | Hooks | Core kit + Dogfood | `.agy/hooks/` has 3 files vs `.claude/hooks/` 6 files | #178 | P1 |
| G-04 | No CI quality-gate aggregator job | P2 | CI | Core kit | `ls .github/workflows/` — 9 separate workflows, no aggregate | New issue created | P2 |
| G-05 | Issue #250 body references `tooling/gemini/GEMINI.md` (does not exist) | P1 | Documentation | Core kit | `ls tooling/` shows no `gemini/` directory | #250 body updated | P1 |
| G-06 | Issue #148 body references `tooling/gemini/GEMINI.md` (does not exist) | P1 | Documentation | Core kit | Same evidence as G-05 | #148 body updated | P1 |
| G-07 | Issue #178 title uses "gemini" branding for Antigravity task | P2 | Documentation | Core kit | Issue title says "feat(gemini):" not "feat(agy):" | Noted; minor cosmetic | P2 |
| G-08 | BACKLOG.md shows #143 as open; it is closed on GitHub | P3 | Documentation | Dogfood | #143 not in open issues list (32 issues, #143 absent) | BACKLOG.md needs refresh | P3 |
| G-09 | Codex subagents use skill-dir pattern, not native `[agents.<name>]` tables | P1 | Codex config | Core kit | `tooling/codex/` has no `[agents.]` sections | #179 | P1 |
| G-10 | 8 of 12 Claude hook events unused (SessionStart, SubagentStop, etc.) | P2 | Hooks | Core kit | `.claude/settings.json` wires only 4 events | #180 | P2 |
| G-11 | Codex granular approval policy not adopted | P1 | Codex config | Core kit | `tooling/codex/config.toml` uses `on-request`, not `granular` | #186 | P1 |
| G-12 | No `scripts/doctor.sh` for install health-checking | P2 | Scripts | Core kit | `ls scripts/` — no doctor script | #149 | P2 |
| G-13 | No `--profile minimal` install option | P3 | Scripts | Core kit | `scripts/install.sh` has no `--profile` flag | #170 | P3 |
| G-14 | `.mcp.example.jsonc` exists in root and `tooling/claude/` — dual source | P2 | Config | Core kit | `ls .mcp.example.jsonc tooling/claude/.mcp.example.jsonc` both exist | #194 | P2 |
| G-15 | Provider feature parity matrix not published | P2 | Documentation | Core kit | `docs/ai/` has no PROVIDER_PARITY.md | #197 | P2 |

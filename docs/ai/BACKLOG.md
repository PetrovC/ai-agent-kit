# Backlog

Living index of the issue-tracked backlog for `ai-agent-kit`. GitHub Issues
remain the source of truth; this file is the agent-facing snapshot grouped by
roadmap phase, with status markers that get flipped to `✅` once a PR closes the
issue.

Update rules:

- Flip `🟢 open` → `✅ done` when the linked PR merges and closes the issue.
- Keep one line per issue. Do not paste full descriptions.
- Add new issues at the bottom of their phase block.
- Do not flip an issue without a merged PR link.

## How to refresh quickly

```bash
gh issue list --state open  --limit 100 --json number,title,labels | jq -r '.[] | "#\(.number) \(.title)"'
gh issue list --state closed --limit 100 --json number,title,closedAt | jq -r '.[] | "#\(.number) \(.title) (closed \(.closedAt))"'
```

## Status legend

| Marker | Meaning |
|---|---|
| 🟢 open | Issue open, not started |
| 🟡 in progress | Branch / PR exists |
| ✅ done | PR merged, issue closed |
| ⏸ blocked | Waiting on a dependency |
| ⏭ deferred | Intentionally postponed |

---

## Sprint 1 — Public release hygiene (`roadmap:now`)

| Status | Issue | Title |
|---|---|---|
| 🟢 | [#136](https://github.com/PetrovC/ai-agent-kit/issues/136) | docs(license): add root MIT LICENSE matching plugin metadata |
| 🟢 | [#137](https://github.com/PetrovC/ai-agent-kit/issues/137) | docs: add SECURITY.md (disclosure policy + hook posture) |
| 🟢 | [#138](https://github.com/PetrovC/ai-agent-kit/issues/138) | docs: add CONTRIBUTING.md (issue-first workflow + commit conventions + DoD) |
| 🟢 | [#139](https://github.com/PetrovC/ai-agent-kit/issues/139) | feat(versioning): introduce root VERSION as single source of truth |
| ⏸ | [#140](https://github.com/PetrovC/ai-agent-kit/issues/140) | chore(release): release checklist + first signed tag + GitHub Release — depends on #139 |
| 🟢 | [#141](https://github.com/PetrovC/ai-agent-kit/issues/141) | docs(readme): clarify public install + tool matrix + plugin path |

## Sprint 2 — Lifecycle confidence (`roadmap:next`)

| Status | Issue | Title |
|---|---|---|
| 🟢 | [#145](https://github.com/PetrovC/ai-agent-kit/issues/145) | test(scripts): bootstrap BATS suite for Bash helpers |
| 🟢 | [#146](https://github.com/PetrovC/ai-agent-kit/issues/146) | test(scripts): bootstrap Pester suite for PowerShell helpers |
| ⏸ | [#147](https://github.com/PetrovC/ai-agent-kit/issues/147) | ci: enforce Bash/PowerShell parity matrix — depends on #145+#146 |
| 🟢 | [#148](https://github.com/PetrovC/ai-agent-kit/issues/148) | ci: router parity check across CLAUDE.md / AGENTS.md / GEMINI.md |
| 🟢 | [#149](https://github.com/PetrovC/ai-agent-kit/issues/149) | feat(scripts): add doctor.sh + doctor.ps1 to diagnose target installs |
| 🟢 | [#150](https://github.com/PetrovC/ai-agent-kit/issues/150) | feat(validate): stricter checks (router length, project-owned guards) |
| 🟢 | [#151](https://github.com/PetrovC/ai-agent-kit/issues/151) | docs(claude): improve Windows hook guidance for bash-installed setups |

## Model alignment (`kind:perf`, `priority:high`)

| Status | Issue | Title |
|---|---|---|
| 🟢 | [#142](https://github.com/PetrovC/ai-agent-kit/issues/142) | perf(claude): align 5 subagents to Opus/Sonnet/Haiku per task risk |
| 🟢 | [#143](https://github.com/PetrovC/ai-agent-kit/issues/143) | perf(gemini): replace gemini-3-pro-preview with GA models tiered per agent |
| 🟢 | [#144](https://github.com/PetrovC/ai-agent-kit/issues/144) | perf(codex): document per-agent profile mapping in AGENTS.md (gpt-5.5 + reasoning_effort tiers) |

## Performance & sobriety (`kind:perf`)

| Status | Issue | Title |
|---|---|---|
| 🟢 | [#152](https://github.com/PetrovC/ai-agent-kit/issues/152) | perf(hooks): scope format-on-save to source extensions only |
| 🟢 | [#153](https://github.com/PetrovC/ai-agent-kit/issues/153) | docs(skills): document head_limit and scope discipline for investigators |
| 🟢 | [#154](https://github.com/PetrovC/ai-agent-kit/issues/154) | docs(ai-dev): add prompt caching guidance + cache_control patterns |
| 🟢 | [#155](https://github.com/PetrovC/ai-agent-kit/issues/155) | docs: token budget targets per slash command |
| 🟢 | [#156](https://github.com/PetrovC/ai-agent-kit/issues/156) | feat(claude): minimal statusline with context% + cache age |
| 🟢 | [#157](https://github.com/PetrovC/ai-agent-kit/issues/157) | chore(agents): add explicit stop-conditions to subagent prompts |
| 🟢 | [#158](https://github.com/PetrovC/ai-agent-kit/issues/158) | refactor(skills): split skills > 200 lines into SKILL + SKILL.deep |
| 🟢 | [#159](https://github.com/PetrovC/ai-agent-kit/issues/159) | feat(hooks): approximate token logger in PostToolUse |
| 🟢 | [#160](https://github.com/PetrovC/ai-agent-kit/issues/160) | chore(settings): trim WebFetch allowlist + prefer WebSearch first |
| 🟢 | [#161](https://github.com/PetrovC/ai-agent-kit/issues/161) | feat(agents): file-read quota + escalation rule for investigators |
| 🟢 | [#162](https://github.com/PetrovC/ai-agent-kit/issues/162) | feat(claude): minimal output style for /run-tests |

## Roadmap Later — strategic backlog (`roadmap:later`)

| Status | Issue | Title |
|---|---|---|
| 🟢 | [#163](https://github.com/PetrovC/ai-agent-kit/issues/163) | docs(security): write a threat model for hooks, MCP examples and install/update |
| ⏸ | [#164](https://github.com/PetrovC/ai-agent-kit/issues/164) | ci: add OpenSSF Scorecard workflow + badge — depends on #136+#137 |
| ⏸ | [#165](https://github.com/PetrovC/ai-agent-kit/issues/165) | feat(scripts): publish signed manifests and SHA checksums per release — depends on #139+#140 |
| 🟢 | [#166](https://github.com/PetrovC/ai-agent-kit/issues/166) | feat(skills): per-skill version metadata + changelog |
| 🟢 | [#167](https://github.com/PetrovC/ai-agent-kit/issues/167) | feat(skills): lightweight skill evals (not required CI) |
| ⏸ | [#168](https://github.com/PetrovC/ai-agent-kit/issues/168) | feat(scripts): init wizard + stack presets — recommended after #145+#146 |
| 🟢 | [#169](https://github.com/PetrovC/ai-agent-kit/issues/169) | exp(gemini): optional Gemini wrapper experiment for hook-like guardrails |
| ⏸ | [#170](https://github.com/PetrovC/ai-agent-kit/issues/170) | feat(scripts): minimal vs full install profiles — recommended after #145+#146 |
| 🟢 | [#171](https://github.com/PetrovC/ai-agent-kit/issues/171) | feat(scripts): context sanitization scripts for logs and pasted documents |
| ⏸ | [#172](https://github.com/PetrovC/ai-agent-kit/issues/172) | feat(shared): turn context/subagent/MCP/model-routing policies into installable assets — depends on #142+#143+#144+#150 |
| 🟢 | [#173](https://github.com/PetrovC/ai-agent-kit/issues/173) | docs(gemini): compression guidance + minimal command support |
| ⏸ | [#174](https://github.com/PetrovC/ai-agent-kit/issues/174) | docs(codex): context policy + explicit model-routing notes in AGENTS.md — depends on #144 |
| ⏸ | [#175](https://github.com/PetrovC/ai-agent-kit/issues/175) | docs: README + CHANGELOG hygiene when governance assets become installable — depends on #172 |

---

## Recommended execution order

Start with the issues that unlock everything else, then run independent tracks in parallel.

1. **Model alignment first** — small, immediate quality + cost win:
   - [#142](https://github.com/PetrovC/ai-agent-kit/issues/142) Claude
   - [#143](https://github.com/PetrovC/ai-agent-kit/issues/143) Gemini
   - [#144](https://github.com/PetrovC/ai-agent-kit/issues/144) Codex
2. **Public release hygiene** — 1-line dependencies between them:
   - [#136](https://github.com/PetrovC/ai-agent-kit/issues/136) LICENSE
   - [#137](https://github.com/PetrovC/ai-agent-kit/issues/137) SECURITY.md
   - [#138](https://github.com/PetrovC/ai-agent-kit/issues/138) CONTRIBUTING.md
   - [#139](https://github.com/PetrovC/ai-agent-kit/issues/139) VERSION
   - [#140](https://github.com/PetrovC/ai-agent-kit/issues/140) Release tag
   - [#141](https://github.com/PetrovC/ai-agent-kit/issues/141) README polish
3. **High-leverage docs** in parallel: [#154](https://github.com/PetrovC/ai-agent-kit/issues/154) prompt caching, [#157](https://github.com/PetrovC/ai-agent-kit/issues/157) stop conditions, [#160](https://github.com/PetrovC/ai-agent-kit/issues/160) WebFetch trim.
4. **Lifecycle confidence**: [#145](https://github.com/PetrovC/ai-agent-kit/issues/145)+[#146](https://github.com/PetrovC/ai-agent-kit/issues/146) BATS+Pester, then [#147](https://github.com/PetrovC/ai-agent-kit/issues/147)+[#148](https://github.com/PetrovC/ai-agent-kit/issues/148), then [#149](https://github.com/PetrovC/ai-agent-kit/issues/149)+[#150](https://github.com/PetrovC/ai-agent-kit/issues/150).
5. **Roadmap Later** — only after Sprint 1 + 2 are mostly green.

## Cross-reference

- Strategic phasing: [ROADMAP.md](./ROADMAP.md)
- Workflow contract: [WORKFLOW.md](./WORKFLOW.md)
- Decisions: [DECISIONS.md](./DECISIONS.md)
- Model choices: [MODEL_ROUTING.md](./MODEL_ROUTING.md)

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
| ⏭ | [#169](https://github.com/PetrovC/ai-agent-kit/issues/169) | exp(gemini): optional Gemini wrapper experiment — **likely obsolete after #177 lands (Gemini ships hooks natively)** |
| ⏸ | [#170](https://github.com/PetrovC/ai-agent-kit/issues/170) | feat(scripts): minimal vs full install profiles — recommended after #145+#146 |
| 🟢 | [#171](https://github.com/PetrovC/ai-agent-kit/issues/171) | feat(scripts): context sanitization scripts for logs and pasted documents |
| ⏸ | [#172](https://github.com/PetrovC/ai-agent-kit/issues/172) | feat(shared): turn context/subagent/MCP/model-routing policies into installable assets — depends on #142+#143+#144+#150 |
| 🟢 | [#173](https://github.com/PetrovC/ai-agent-kit/issues/173) | docs(gemini): compression guidance + minimal command support |
| ⏸ | [#174](https://github.com/PetrovC/ai-agent-kit/issues/174) | docs(codex): context policy + explicit model-routing notes in AGENTS.md — depends on #144 |
| ⏸ | [#175](https://github.com/PetrovC/ai-agent-kit/issues/175) | docs: README + CHANGELOG hygiene when governance assets become installable — depends on #172 |

## Provider parity audit (`kind:audit`)

Findings from a May 2026 audit against the official docs of Claude Code, Codex CLI, and Gemini CLI. The audit identified ~25 gaps not covered by earlier issues; the most impactful ones became these 21 issues.

| Status | Issue | Title |
|---|---|---|
| 🟢 | [#177](https://github.com/PetrovC/ai-agent-kit/issues/177) | docs(adr): rewrite ADR-008 — Gemini now supports hooks (2026 update) |
| ⏸ | [#178](https://github.com/PetrovC/ai-agent-kit/issues/178) | feat(gemini): adopt hooks (BeforeTool/AfterTool/SessionStart/...) — depends on #177 |
| ⏸ | [#179](https://github.com/PetrovC/ai-agent-kit/issues/179) | feat(codex): migrate subagents to native `[agents.<name>]` tables — depends on #144 |
| 🟢 | [#180](https://github.com/PetrovC/ai-agent-kit/issues/180) | feat(claude): adopt unused hook events (SubagentStop, SessionStart/End, UserPromptSubmit, Notification) |
| 🟢 | [#181](https://github.com/PetrovC/ai-agent-kit/issues/181) | feat(gemini): switch context.fileName to array (AGENTS.md + GEMINI.md + CONTEXT.md) |
| 🟢 | [#182](https://github.com/PetrovC/ai-agent-kit/issues/182) | feat(gemini): enable tools.useRipgrep + tune model.maxSessionTurns + compressionThreshold |
| 🟢 | [#183](https://github.com/PetrovC/ai-agent-kit/issues/183) | feat(gemini): migrate excludedEnvVars to security.environmentVariableRedaction |
| ⏸ | [#184](https://github.com/PetrovC/ai-agent-kit/issues/184) | feat(gemini): ship policies/ directory in extension — depends on #178 |
| 🟢 | [#185](https://github.com/PetrovC/ai-agent-kit/issues/185) | feat(codex): document and selectively enable features.{hooks,memories,multi_agent,web_search} |
| 🟢 | [#186](https://github.com/PetrovC/ai-agent-kit/issues/186) | feat(codex): adopt granular approval policy + SessionStart/PermissionRequest hooks |
| 🟢 | [#187](https://github.com/PetrovC/ai-agent-kit/issues/187) | feat(claude): tune skillListingBudgetFraction + maxSkillDescriptionChars for 30 skills |
| ⏸ | [#188](https://github.com/PetrovC/ai-agent-kit/issues/188) | feat(claude): document strictKnownMarketplaces + enabledPlugins for target projects — depends on #136 |
| 🟢 | [#189](https://github.com/PetrovC/ai-agent-kit/issues/189) | feat(claude): worktree.{baseRef,symlinkDirectories,sparsePaths,bgIsolation} guidance |
| 🟢 | [#190](https://github.com/PetrovC/ai-agent-kit/issues/190) | feat(claude): teammateMode docs for parallel subagent runs |
| 🟢 | [#191](https://github.com/PetrovC/ai-agent-kit/issues/191) | feat(claude): introduce permissions ask: rules (third path between allow/deny) |
| 🟢 | [#192](https://github.com/PetrovC/ai-agent-kit/issues/192) | chore(claude): attribution + prUrlTemplate + includeGitInstructions tuning |
| 🟢 | [#193](https://github.com/PetrovC/ai-agent-kit/issues/193) | chore(skills): complete allowed-tools coverage across the remaining 15/30 skills |
| 🟢 | [#194](https://github.com/PetrovC/ai-agent-kit/issues/194) | chore: consolidate .mcp.example.jsonc to a single source under tooling/claude |
| 🟢 | [#195](https://github.com/PetrovC/ai-agent-kit/issues/195) | docs(architecture): clarify dogfood vs source layout boundary (Codex root .codex/ vs tooling/codex) |
| 🟢 | [#196](https://github.com/PetrovC/ai-agent-kit/issues/196) | feat(claude): document autoMemory + apiKeyHelper + disableSkillShellExecution |
| 🟢 | [#197](https://github.com/PetrovC/ai-agent-kit/issues/197) | docs(audit): publish provider feature parity matrix (Claude/Codex/Gemini) |

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
5. **Audit (kind:audit)** — start with [#177](https://github.com/PetrovC/ai-agent-kit/issues/177) (ADR-008 rewrite) because it invalidates the kit's Gemini narrative everywhere else; then [#179](https://github.com/PetrovC/ai-agent-kit/issues/179) (Codex native agents) and [#178](https://github.com/PetrovC/ai-agent-kit/issues/178) (Gemini hooks adoption). The remaining audit issues can run in parallel with Sprint 2.
6. **Roadmap Later** — only after Sprint 1 + 2 are mostly green.

## Audit summary (May 2026)

The 21 `kind:audit` issues come from a cross-check between the kit and the current official docs of Claude Code, Codex CLI, and Gemini CLI. High-impact findings:

- ~~**ADR-008 is obsolete.** Gemini CLI now ships a full hooks system.~~ — ADR-008 rewritten in this PR; [#177](https://github.com/PetrovC/ai-agent-kit/issues/177) resolved. The kit-side hook adoption is now tracked separately by [#178](https://github.com/PetrovC/ai-agent-kit/issues/178); [#169](https://github.com/PetrovC/ai-agent-kit/issues/169) remains recommended for `wontfix`.
- **Codex has native `[agents.<name>]` tables.** The kit's "Codex skills as agent stand-ins" pattern is legacy. Tracked by [#179](https://github.com/PetrovC/ai-agent-kit/issues/179).
- **Claude exposes 12 hook events; the kit uses 4.** Tracked by [#180](https://github.com/PetrovC/ai-agent-kit/issues/180).
- **Version drift live now**: `.kit-version` 1.19.36 vs `plugin.json`/`gemini-extension.json` 1.19.38 — already what [#139](https://github.com/PetrovC/ai-agent-kit/issues/139) targets.
- **Gemini security defaults** (`tools.sandbox: false`, no `security.*`) are weaker than they need to be. Tracked by [#182](https://github.com/PetrovC/ai-agent-kit/issues/182) + [#183](https://github.com/PetrovC/ai-agent-kit/issues/183) + [#184](https://github.com/PetrovC/ai-agent-kit/issues/184).

The audit method, sources, and full table are kept short here on purpose; [#197](https://github.com/PetrovC/ai-agent-kit/issues/197) tracks the durable provider parity matrix doc.

## Cross-reference

- Strategic phasing: [ROADMAP.md](./ROADMAP.md)
- Workflow contract: [WORKFLOW.md](./WORKFLOW.md)
- Decisions: [DECISIONS.md](./DECISIONS.md)
- Model choices: [MODEL_ROUTING.md](./MODEL_ROUTING.md)

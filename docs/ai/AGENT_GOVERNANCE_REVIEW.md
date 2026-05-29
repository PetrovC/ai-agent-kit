# Agent Governance Review

**Date:** 2026-05-29

---

## Current Governance

Governance is split into:
- `docs/ai/MODEL_ROUTING.md` — model selection rules, provider mapping, subagent assignments.
- `docs/ai/SUBAGENT_GOVERNANCE.md` — when to use subagents, stop conditions, ROI rules.
- `docs/ai/CONTEXT_GOVERNANCE.md` — context thresholds, compact triggers.
- Provider-specific: `tooling/claude/CLAUDE.md`, `tooling/codex/AGENTS.md`, `tooling/agy/AGY.md`.
- Subagent definitions: `tooling/claude/agents/`, `tooling/agy/agents/`, `tooling/codex/` (via AGENTS.md).

---

## Provider / Model Matrix

### Claude Code

| Subagent | Model | maxTurns | Role | Do not use for |
|---|---|---|---|---|
| `architect` | `claude-opus-4-7` | 15 | Decision-bearing design | Mechanical edits |
| `code-reviewer` | `claude-opus-4-7` | 12 | High-stakes review | Fast lookups |
| `security-reviewer` | `claude-opus-4-7` | 15 | Exploitable vulnerability finding | Style review |
| `codebase-investigator` | `claude-sonnet-4-6` | 15 | Narrow deterministic search | Architecture decisions |
| `test-runner` | `claude-haiku-4-5` | 10 | Run tests, summarize output | Any reasoning task |

**Model verification source:** https://platform.claude.com/docs/en/about-claude/models/overview
Verified GA as of May 2026: `claude-opus-4-7`, `claude-sonnet-4-6`, `claude-haiku-4-5`.

### Codex CLI

| Subagent | Profile | `model_reasoning_effort` | Role |
|---|---|---|---|
| `architect` | `deep` | `high` | Design assessment |
| `code-reviewer` | `deep` | `high` | PR review |
| `security-reviewer` | `deep` | `high` | Security audit |
| `codebase-investigator` | `standard` | `medium` | Code search |
| `test-runner` | `readonly` | `low` | Test execution |

**Model verification source:** https://developers.openai.com/codex/models
Verified GA as of May 2026: `gpt-5.5` with effort levels `none/low/medium/high/xhigh`.

**Gap:** Codex subagents are emulated via skill directories, not native `[agents.<name>]` tables.
Native tables are supported per Codex docs. Tracked as issue #179 (P1).

### Antigravity CLI

| Subagent | Model | max_turns | Role |
|---|---|---|---|
| `architect` | `gemini-3.1-pro` | 15 | Design assessment |
| `code-reviewer` | `gemini-3.1-pro` | 20 | PR review |
| `security-reviewer` | `gemini-3.1-pro` | 15 | Security audit |
| `codebase-investigator` | `gemini-3-flash` | 15 | Code search |
| `test-runner` | `gemini-3-flash` | 10 | Test execution |

**Note on model names:** Antigravity CLI uses Google Gemini model names directly.
`gemini-3.1-pro` and `gemini-3-flash` are GA Gemini models, not a Gemini-CLI dependency.
The `pr-docs.yml` APPROVED_MODELS whitelist validates these names on every PR.

**Model verification source:** Google Antigravity / Gemini model docs.
Verified GA as of May 2026: `gemini-3.1-pro` (GA April 2026), `gemini-3-flash` (stable).

---

## Gemini Migration Traces

The governance correctly treats Gemini model names as Antigravity model identifiers, not as
references to a "Gemini CLI" provider. This distinction is accurate and documented in the
CHANGELOG for PR #297 and #298.

No governance documents treat Gemini CLI as an active agent. Migration is complete.

---

## Subagent Governance

From `docs/ai/SUBAGENT_GOVERNANCE.md`:
- Use subagents when affected area is unclear, output is large, or task is specialized.
- Do not use subagents for simple one-file changes.
- 5 named subagents: architect, code-reviewer, security-reviewer, codebase-investigator, test-runner.
- Stop conditions defined per subagent type.

**Gap:** `teammateMode` (`auto`/`in-process`/`tmux`) is not documented for parallel subagent runs.
Tracked as issue #190 (P3).

---

## Report Validation Rules

The governing agent must verify subagent reports by checking:
1. The subagent identified specific files, not vague areas.
2. Commands were listed with actual output, not claimed output.
3. Tests were named, not just "tests passed".
4. The scope matches the original issue, not drift.

These rules are stated in `docs/ai/SUBAGENT_GOVERNANCE.md`. No automated enforcement exists.

---

## Gaps and Issues

| Gap | Issue | Priority |
|---|---|---|
| Codex native `[agents.<name>]` tables not used | #179 | P1 |
| 8 of 12 Claude hook events unused | #180 | P2 |
| Codex granular approval policy not adopted | #186 | P1 |
| `teammateMode` guidance missing | #190 | P3 |
| Antigravity model upgrade candidate (`gemini-3.5-flash`) not yet adopted | Noted in MODEL_ROUTING.md | P3 |

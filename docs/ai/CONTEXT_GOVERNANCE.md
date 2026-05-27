# Context Governance

Context thresholds are governance checkpoints, not automatic laws. The goal is
to preserve decision quality, reduce repeated reading, and avoid carrying stale
or unrelated task state.

## Context Thresholds

| Context usage | Guidance |
|---|---|
| 0-39% | Continue normally. Keep reading targeted files only. |
| 40-59% | Context checkpoint. Evaluate whether to compact before broad analysis, large file reads, large logs, or refactoring. |
| 60-79% | Compaction or compression is strongly recommended before continuing. |
| 80%+ | Checkpoint, summarize current state, and start a fresh session. |

Important nuance:

- 40% does not mean mandatory automatic compaction.
- 60% means continuing is possible, but compression should be the default unless
  the next step is very small.
- 80% means the session is high risk for drift and missed details.
- Context quality matters as much as percentage.

## Command Mapping

| Tool | Command |
|---|---|
| Claude Code | `/compact` |
| Codex CLI | `/compact` |
| Gemini CLI | `/compress` |

Claude Code session-hygiene details (when to use `--continue`, `/compact`, `/clear`; why auto-compact is not yet configurable) live in the **Session hygiene** section of `tooling/claude/CLAUDE.md`. That section includes the agent-side directive: when to proactively recommend `/compact` before a heavy step.

## Codex Router Budget

Codex reads router files at session start, so keep them as pointers rather than
full policy documents. `scripts/validate.{sh,ps1}` enforces this budget for
`AGENTS.md` and `tooling/codex/AGENTS.md`:

| File | Budget |
|---|---|
| `AGENTS.md` | <= 320 lines and <= 16 KiB |
| `tooling/codex/AGENTS.md` | <= 320 lines and <= 16 KiB |

Both routers must link to this file and to `docs/ai/MODEL_ROUTING.md`. If a
router needs to grow past the budget, open a dedicated issue that explains why
the detail cannot live in `docs/ai/`, a skill, or a provider-specific config
file, then update the validator constants in the same PR.

## Provider settings that enforce these thresholds

The kit aligns provider-side knobs with the table above so the
governance is enforced by configuration where the platform supports
it, not only by agent discipline.

### Gemini CLI (`tooling/gemini/settings.json`)

| Setting | Kit value | Why this value |
|---|---|---|
| `model.compressionThreshold` | `0.6` | Triggers Gemini's automatic compression at the 60% checkpoint — the boundary where this document says compression should be the default unless the next step is very small. Upstream default is `0.5`; raising it to `0.6` gives a small safety margin before forced compression, matching the 40–59% "evaluate" band. |
| `model.maxSessionTurns` | `100` | Caps user/model/tool conversation rounds retained per session. Upstream default is `-1` (unlimited); `100` is the runaway-prevention bound — well above legitimate multi-step workflows (typically 30–60 turns) and well below catastrophic loops. |
| `tools.useRipgrep` | `true` | Already the upstream default, but the kit sets it explicitly so a future upstream default flip does not silently degrade search performance. ripgrep is the kit-preferred deterministic search per ADR-017. |

Claude Code and Codex CLI do not expose equivalent direct knobs at
the moment; their governance is enforced through hook guards
(`pre-bash-guard`), the `docs/ai/SUBAGENT_GOVERNANCE.md` rules, and
the `/compact` reminder above.

## Cache Freshness

Short-lived prompt/context cache windows are signals, not correctness
boundaries.

| Idle time | Same task | Different task |
|---|---|---|
| More than 5 minutes | Evaluate context. If context is heavy, compact or compress before continuing. | Start a fresh session. |
| More than 15 minutes | Prefer a fresh session unless uncommitted work must be summarized first. | Start a fresh session. |

Do not describe a 5-minute idle period as a forced reset. Treat it as a
workflow hygiene signal.

## Session Boundary

- One GitHub issue equals one agent session by default.
- Exceptions are allowed only for tightly related work in the same PR and scope.
- Never switch to an unrelated issue in the same session.
- If a new issue starts, summarize and end the old context before continuing.
- If a PR spans multiple concerns, split the work rather than stretching the
  session boundary.

## Repository-specific Guidance

For `ai-agent-kit`, broad reads can become expensive because the repository has
parallel Bash/PowerShell scripts, three provider adapters, shared skills,
examples, templates, and workflow files. Prefer targeted reads and exact search
before opening whole trees.

When a task touches public-release hygiene, lifecycle behavior, or provider
parity, summarize the current evidence before editing. Those areas affect users
who install the kit into target projects and are easy to over-expand into
unrelated roadmap work.

## Practical Checkpoint Questions

Before broad reading or a large edit, ask:

- Is this still the same issue?
- Is the next step narrow enough to continue?
- Have important findings been summarized?
- Would compaction lose critical details?
- Would a fresh session be safer?

If the answer is unclear, summarize the current state before continuing.

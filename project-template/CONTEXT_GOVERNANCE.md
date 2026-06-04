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
| Antigravity CLI | `/compress` |

Session-hygiene details (when to use `--continue`, `/compact`, `/clear`) live in the project-specific configuration/documentation.

## Router Budget

> ⚠️ **STOP** — Document the context budget limits for your AI tool router files
> (e.g. max lines, max bytes). Your validation script should enforce these limits.

| File | Budget |
|---|---|
| `<router-file>` | `<max-lines>` lines / `<max-bytes>` bytes |

## Provider settings that enforce these thresholds

> ⚠️ **STOP** — Document where your AI provider settings configure these
> context thresholds (e.g. `/compact` commands, auto-compact configuration).

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

> ⚠️ **STOP** — Document repository-specific guidelines for context optimization and reading strategies (e.g. avoiding broad/recursive reads, expensive directories).

## Practical Checkpoint Questions

Before broad reading or a large edit, ask:

- Is this still the same issue?
- Is the next step narrow enough to continue?
- Have important findings been summarized?
- Would compaction lose critical details?
- Would a fresh session be safer?

If the answer is unclear, summarize the current state before continuing.

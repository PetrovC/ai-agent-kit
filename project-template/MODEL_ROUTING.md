# Model Routing

Use model power where reasoning quality matters. The right model depends on the
task, prompt quality, and scope. Weak models are not bad in general; they are
inappropriate for decision-bearing reports.

## Routing by Task

| Model tier | Use for |
|---|---|
| Strong model | Architecture, security, PR review, investigation, refactor planning, decision-bearing reports. |
| Balanced model | Daily coding, tests, normal bugfixes, local analysis, straightforward implementation. |
| Cheap or fast model | Mechanical edits, formatting, fixture generation, simple renames, repetitive low-risk operations. |

## Important Nuance

- A precise prompt and narrow scope matter as much as the model.
- A strong model with vague scope can still produce poor results.
- A balanced model with narrow scope can outperform a strong model with vague instructions.
- Low-tier models may be used for narrow, mechanical, verifiable work.
- Low-tier models must not produce final architecture, security, investigation, or review reports.

## Provider Mapping

### Claude Code

> ⚠️ **STOP** — Fill in your project's per-subagent model assignments.

| Subagent | Model | maxTurns | Justification |
|---|---|---|---|
| `architect` | `<model>` | `<n>` | Decision-bearing design assessment. |
| `code-reviewer` | `<model>` | `<n>` | High-stakes review. |
| `security-reviewer` | `<model>` | `<n>` | Security-sensitive changes. |
| `codebase-investigator` | `<model>` | `<n>` | Targeted lookups. |
| `test-runner` | `<model>` | `<n>` | Mechanical: run tests, summarize output. |

### Codex CLI

> ⚠️ **STOP** — Fill in your project's per-subagent reasoning effort mapping.

| Subagent | Profile | reasoning_effort |
|---|---|---|
| Architecture/review | deep | high |
| Daily development | standard | medium |
| Exploration | readonly | low |

### Antigravity CLI

> ⚠️ **STOP** — Fill in your project's Antigravity model assignments.

| Depth | Model |
|---|---|
| deep | `<model>` |
| standard | `<model>` |
| readonly | `<model>` |

## Prompt Caching

Model power is not the only cost lever. Prompt caching cuts input tokens on the cached portion and off time-to-first-token on long system prompts. Prefer caching long stable content (tool definitions, system prompts, context) and keeping user messages last.

## Web access — WebSearch before WebFetch

- **Prefer WebSearch first** when the exact URL is unknown. Search returns a short summary, whereas WebFetch retrieves full page content and is more expensive.
- **Use WebFetch only when** you know the exact URL and need the full content.

## Token Budgets per Slash Command

Soft targets (not hard gates) to monitor token usage per single end-to-end command invocation:

| Command | Target budget | Why this size |
|---|---|---|
| `/run-tests` | < 30 k | Run + summarize; logs trimmed. |
| `/code-review` | < 60 k | Diff + skill + ARCHITECTURE. |
| `/security-audit` | < 80 k | Scoped vulnerability checks. |
| `/bug-fix` | < 80 k | Repro + root cause + fix + test. |
| `/refactor` | < 100 k | Scoped behavior-preserving changes. |
| `/daily-ticket` | < 120 k | End-to-end ticket workflow. |

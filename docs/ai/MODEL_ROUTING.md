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
- A balanced model with narrow scope can outperform a strong model with vague
  instructions.
- Low-tier models may be used for narrow, mechanical, verifiable work.
- Low-tier models must not produce final architecture, security, investigation,
  or review reports.

## Provider Mapping

### Claude Code

- Use Opus or Opus plan mode for architecture, refactor planning, and security
  review.
- Use Sonnet for daily development.
- Use Haiku only for narrow mechanical work.

Per-subagent model assignment used in this repository (see
`tooling/claude/agents/*.md`):

| Subagent | Model | maxTurns | Justification |
|---|---|---|---|
| `architect` | `claude-opus-4-8` | 15 | Decision-bearing design assessment. |
| `code-reviewer` | `claude-opus-4-8` | 12 | High-stakes review; tightened from 20 turns to curb drift. |
| `security-reviewer` | `claude-opus-4-8` | 15 | Real exploitable vulnerabilities, not theoretical risk. |
| `codebase-investigator` | `claude-sonnet-4-6` | 15 | Narrow, deterministic-search-first lookups; Sonnet is enough (ADR-017). |
| `test-runner` | `claude-haiku-4-5` | 10 | Mechanical: run filtered tests, summarize output. |

Verified against the Anthropic model overview (accessed 2026-05-31):
`claude-opus-4-8` is the most capable model (`claude-opus-4-7` is now listed as
a legacy model); `claude-sonnet-4-6` and `claude-haiku-4-5` remain current. See
<https://platform.claude.com/docs/en/about-claude/models/overview>.

### Codex CLI

- Use a deep or high reasoning profile for architecture, refactor planning, and
  review.
- Use the standard profile for daily development.
- Use the readonly profile for exploration.
- Use low effort only for mechanical scoped tasks.

Per-subagent profile mapping used in this repository. All profiles run on
`gpt-5.5`; the differentiator is `model_reasoning_effort`. Mirror in
`tooling/codex/AGENTS.md`:

| Subagent | Codex profile | `model_reasoning_effort` |
|---|---|---|
| `architect` | `deep` | `high` |
| `code-reviewer` | `deep` | `high` |
| `security-reviewer` | `deep` | `high` |
| `codebase-investigator` | `standard` | `medium` |
| `test-runner` | `readonly` | `low` |

Verified against the Codex models doc (accessed 2026-05-31): `gpt-5.5` remains
the current default and most capable model (alongside `gpt-5.4`, `gpt-5.4-mini`,
and `gpt-5.3-codex`); the per-profile differentiator here is the Codex
`model_reasoning_effort` config setting. See
<https://developers.openai.com/codex/models>.

### Antigravity CLI

- Use a Pro model for architecture, security, review, and investigation.
- Use a balanced model for daily development.
- Use a fast model only for narrow mechanical work.

Per-subagent model assignment used in this repository (see
`tooling/agy/agents/*.md`):

| Subagent | Model | max_turns | Justification |
|---|---|---|---|
| `architect` | `claude-opus-4-6` | 15 | Decision-bearing design assessment. |
| `code-reviewer` | `claude-opus-4-6` | 20 | High-stakes review. |
| `security-reviewer` | `claude-opus-4-6` | 15 | Real exploitable vulnerabilities, not theoretical risk. |
| `codebase-investigator` | `claude-sonnet-4-6` | 15 | Narrow lookups; Sonnet is sufficient. |
| `test-runner` | `claude-sonnet-4-6` | 10 | Mechanical: run tests, summarize output. |

Antigravity (agy) is a CLI with a fixed, user-selected model picker (no
per-call model flag). As of 2026-06-04 the picker offered Gemini 3.5 Flash
(Medium/High/Low), Gemini 3.1 Pro (Low/High), **Claude Sonnet 4.6 (Thinking)**,
**Claude Opus 4.6 (Thinking)**, and GPT-OSS 120B (Medium). The kit's delegate
adapter now pins Claude models as the default hints: Opus for deep work (separate
Anthropic quota from the linked Gemini pool), Sonnet for standard/readonly work.
The model hint is passed via the `ANTIGRAVITY_MODEL` environment variable before
the `agy -p` call. Confirmed from the live product (agy v1.0.4); see
<https://antigravity.google/docs/models>.

**Quota fallback (automatic):** when the adapter detects a 429 / quota-exhausted
error from agy, it retries once with the depth's fallback model:

| Depth | Primary model | Fallback model |
|---|---|---|
| `deep` | `claude-opus-4-6` | `claude-sonnet-4-6` (Anthropic quota, lower tier) |
| `standard` | `claude-sonnet-4-6` | `gemini-3.1-pro` (Gemini quota — separate pool) |
| `readonly` | `claude-sonnet-4-6` | `gemini-3.1-pro` |

Detection patterns: `quota`, `rate limit`, `resource_exhausted`, `429`,
`too many requests`. Codex does not have this retry path (no per-model quota
to fall back from).

## Command and Agent Guidance

Current repository agents already use strong models in several sensitive areas.
Future work should clarify model hints for commands as well as agents. Do not
change command or agent model routing without a dedicated issue and PR.

For this repository, use stronger reasoning for public-release readiness,
lifecycle script behavior, security hook review, MCP policy, and provider parity
because mistakes can be copied into target projects. Balanced reasoning is fine
for routine documentation edits and narrow, verifiable command updates.

Cheap or fast models are acceptable for repetitive Markdown formatting or
fixture-like edits only when the scope is narrow and the result is easy to
verify.

## Prompt Caching

Model power is not the only cost lever. Prompt caching cuts input tokens
50–90% on the cached portion and 30–80% off time-to-first-token on long
system prompts. For any wrapper, agent, or tool that calls the Anthropic /
OpenAI / Gemini APIs from this repo, prefer caching long stable content
(tool defs, system prompt, RAG context) and keeping the user message last.

Provider notes and full code examples live in the
[`ai-dev` skill](../../skills/ai-dev/SKILL.md#prompt-caching).

## Web access — WebSearch before WebFetch

The kit's Claude allowlist (`tooling/claude/settings*.json`) is trimmed to 12
high-signal domains: the three provider doc sites
(`code.claude.com` / `platform.claude.com` / `developers.openai.com` /
`antigravity.google`), GitHub, and one canonical reference per major language
runtime (Microsoft Learn, Node.js, npm, Python, Go, Rust, Kubernetes). This
keeps WebFetch usage scoped and predictable.

Rules:

- **Prefer `WebSearch` first** when the exact URL is unknown. Search returns
  a short summary; WebFetch dumps full HTML and is much more expensive in
  tokens.
- **Use `WebFetch` only when** you already know the exact URL and need the
  full content (e.g., a specific reference page, a release note, an issue).
- **Target projects extend the list** in `.claude/settings.local.json` for
  their actual stack (Vue, Angular, Spring, Flutter, …). The kit
  intentionally does not ship a 30-domain catch-all — every entry is a
  small attack surface and a context-bloat risk.

## Token Budgets per Slash Command

Soft targets — not gates — to spot when a command balloons in tokens. If a
run consistently exceeds the budget, investigate the prompt scope before
the model tier. Budgets cover the full conversation (input + output) for a
single end-to-end invocation, not just the model call.

| Command | Target budget | Why this size |
|---|---|---|
| `/run-tests` | < 30 k | Run + summarize; logs trimmed. |
| `/code-review` | < 60 k | Diff + skill + ARCHITECTURE; uses subagent for noise. |
| `/security-audit` | < 80 k | Multiple checks but should not re-read the world. |
| `/bug-fix` | < 80 k | Repro + root cause + fix + regression test. |
| `/refactor` | < 100 k | Behaviour-preserving, scoped to one area. |
| `/performance-audit` | < 100 k | Measure baseline, find bottleneck, propose fix. |
| `/dependency-update` | < 100 k | Changelog + license + tests + audit. |
| `/on-call` | < 100 k | Live incident playbook; prefer narrow scope. |
| `/tech-debt` | < 120 k | Triage across categories — read-only, can grow. |
| `/feature-planning` | < 120 k | Plan only; no code; can need broader context. |
| `/daily-ticket` | < 120 k | End-to-end ticket workflow with subagents. |

Heuristics:

- Subagent calls do not count against the main session budget — that is
  the point of delegation (ADR-013).
- Hitting a budget rarely means raise it. Usually it means: tighten the
  prompt, drop a skill, push a noisy step to a subagent.
- See [`docs/ai/CONTEXT_GOVERNANCE.md`](./CONTEXT_GOVERNANCE.md) for the
  40/60/80% session checkpoints that complement these per-command budgets.

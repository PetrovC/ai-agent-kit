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

### Codex CLI

- Use a deep or high reasoning profile for architecture, refactor planning, and
  review.
- Use the standard profile for daily development.
- Use the readonly profile for exploration.
- Use low effort only for mechanical scoped tasks.

### Gemini CLI

- Use a Pro model for architecture, security, review, and investigation.
- Use a balanced model for daily development.
- Use a fast model only for narrow mechanical work.

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

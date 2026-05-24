# Prompt: Daily Ticket

> Copy-paste this when starting work on a GitHub issue.
> Replace [NUMBER] and adjust the subagent section based on complexity.

---

```
Work on GitHub issue #[NUMBER].

Follow [AGENTS.md / CLAUDE.md / GEMINI.md] strictly.

Before editing:
- Read docs/ai/PROJECT.md if domain context is needed.
- Identify the relevant skill(s).
- Identify the minimal files to inspect.
- Write a short implementation plan (3–5 bullet points).

Use subagents only if:
- The affected area is unclear → use codebase-investigator first.
- The change touches more than 5 files → use code-reviewer before final response.
- Test output is large → use test-runner.

Then implement the smallest complete solution.

After editing:
- Run the relevant verification commands from docs/ai/COMMANDS.md.
- Report: summary / files changed / verification results / risks / next step.
```

---

## Minimal variant (simple tasks)

```
Work on GitHub issue #[NUMBER].

Keep the change small and focused.
Add or update tests for changed behavior.
Run the project's test command (see `docs/ai/COMMANDS.md`) before final response.
```

## With explicit skills (when you know the stack)

```
Work on GitHub issue #[NUMBER].

Use the skills relevant to the files this change touches (e.g. `python` and
`testing` for a Django change; replace with your stack's skill from the
routing table). Do not use unrelated skills.

Keep the change small, explicit, and covered by tests.
Run the project's build + test commands (see `docs/ai/COMMANDS.md`) before
final response.
```

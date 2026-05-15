---
description: Start work on a GitHub issue with the kit's standard workflow (skills, subagents, verification).
argument-hint: <issue-number>
---

Work on GitHub issue #$ARGUMENTS.

Follow CLAUDE.md strictly.

Before editing:
- Read `docs/ai/PROJECT.md` if domain context is needed.
- Identify the relevant skill(s).
- Identify the minimal files to inspect.
- Write a short implementation plan (3–5 bullet points).

Use subagents only if:
- The affected area is unclear → use `codebase-investigator` first.
- The change touches more than 5 files → use `code-reviewer` before final response.
- Test output is large → use `test-runner`.

Then implement the smallest complete solution.

After editing:
- Run the relevant verification commands from `docs/ai/COMMANDS.md`.
- Report: summary / files changed / verification results / risks / next step.

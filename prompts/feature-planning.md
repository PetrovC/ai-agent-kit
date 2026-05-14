# Prompt: Feature Planning

> Use before starting a large feature. Get a plan before touching a single file.

```
Plan the implementation of the feature described in GitHub issue #[NUMBER].

Use the architect subagent to analyze the impact on existing boundaries.
Use the codebase-investigator subagent to map the relevant existing code.

Do NOT implement anything yet. Only produce the plan.

The plan must include:

1. Feature summary (one paragraph).
2. Affected layers (Domain / Application / Infrastructure / Interfaces).
3. New files to create (with layer and brief purpose).
4. Existing files to modify (with reason).
5. New dependencies required (justify each one).
6. Migration required? (yes/no — if yes, describe the schema change).
7. Test strategy:
   - Unit tests: what behavior to cover.
   - Integration tests: what boundary to test.
8. Suggested breakdown into small, mergeable PRs (ordered).
9. Risks and open questions.

Keep the plan concise. It will be used to write GitHub issues for each sub-task.
```

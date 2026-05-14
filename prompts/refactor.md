# Prompt: Refactor

```
Refactor [DESCRIBE WHAT] as described in GitHub issue #[NUMBER] (or: as follows: ...).

Rules:
- Do not change observable behavior. This is a refactor, not a feature.
- Keep the change small and reviewable. Prefer multiple small PRs over one large rewrite.
- Do not introduce new patterns, abstractions, or dependencies unless explicitly requested.
- Maintain or improve test coverage.

Before editing:
- Use the codebase-investigator subagent to map all affected usages.
- Identify the minimal scope of the refactor.
- Write a short plan before starting.

After editing:
- Run all existing tests. They must all pass.
- If any test needed updating, explain why (behavior-preserving adaptation vs. behavior change).
- Use the code-reviewer subagent before final response.

Report:
- What changed and why (even for a refactor, explain the intent).
- Files changed.
- Test results.
- Risks (especially: anything that was not covered by tests before the refactor).
```

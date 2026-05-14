# Prompt: Run Tests

```
Run the test suite for the current change.

Read docs/ai/COMMANDS.md first for the exact commands used in this project.

Steps:
1. Identify which modules or layers are touched by the current change.
2. Run the relevant filtered tests first (by module or category).
3. If they pass, run the full suite.
4. Use the test-runner subagent if the output is large.

Report:
- Commands run.
- Result: X passed, Y failed, Z skipped.
- Failing tests: name + short failure reason.
- Whether failures are pre-existing or caused by the current change.
- What is NOT covered and why.

Do not fix test failures. Report them.
```

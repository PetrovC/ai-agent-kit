# Prompt: Bug Fix

```
Fix the bug described in GitHub issue #[NUMBER].

Before editing:
- Reproduce the bug in code or via a test.
- Identify the root cause (not just the symptom).
- Identify the minimal change that fixes it without side effects.

After editing:
- Add a regression test that fails without the fix and passes with it.
- Name the test to describe what was broken: e.g. GetDaysConsumed_WhenHolidayOnWeekend_ShouldNotDoubleCount
- Run the project's test command (see `docs/ai/COMMANDS.md`) and confirm the regression test passes.

Report:
- Root cause identified.
- Fix applied (files changed).
- Regression test added.
- Verification result.
- Any related edge cases that were not fixed and should be tracked separately.
```

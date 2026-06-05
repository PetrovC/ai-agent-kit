---
description: Run the test suite for the current change and report results — without fixing failures.
---

Run the test suite for the current change.

Read `docs/ai/COMMANDS.md` first for the exact commands used in this project.

Steps:
1. Identify which modules or layers are touched by the current change.
2. Run the relevant filtered tests first (by module or category).
3. If they pass, run the full suite.
4. Use the `test-runner` subagent if the output is large.

## Output format (strict — no prose)

Use exactly this Markdown table. Do not add narration outside the table and the failures list.

| | Count |
|---|---|
| ✅ Passed | `N` |
| ❌ Failed | `N` |
| ⏭️ Skipped | `N` |
| 🕒 Duration | `Ns` |

**Commands run:** `<command 1>`, `<command 2>`

**Failing tests (top 5):**

| Test | Reason |
|---|---|
| `<TestName>` | `<one-line reason>` |

**Pre-existing failures:** yes / no / unknown

**Not covered:** `<what was not tested and why, or "none">`

Do not fix test failures. Report them only.


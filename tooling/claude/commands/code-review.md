---
description: Review the changes in the given branch (or current diff) for correctness, security, regressions, and missing tests.
argument-hint: [branch-name]
---

Review the changes in branch $ARGUMENTS (or the current `git diff` if no branch given).

Use the `code-review` skill.
Use the `codebase-investigator` subagent if context about existing behavior is needed.

Review for:
1. Correctness — does it do what it claims?
2. Security — does it introduce vulnerabilities?
3. Regression risk — does it break existing behavior?
4. Missing tests — is changed behavior covered?
5. Architecture compliance — does it respect layer boundaries?
6. Maintainability — will the next developer understand it?

Output format:
### Blockers
### Important
### Minor
### Future improvements

Each finding: file + risk + suggested fix direction.
Do not flag style unless it hides a real problem.

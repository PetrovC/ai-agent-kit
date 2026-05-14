# Prompt: Code Review

```
Review the changes in branch [BRANCH_NAME] (or the diff provided).

Use the code-review skill.
Use the codebase-investigator subagent if context about existing behavior is needed.

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
```

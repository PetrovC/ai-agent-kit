---
name: Bug
about: Something is broken
labels: bug
---

## Description

<!-- What is broken? What was expected vs what happened? -->

## Steps to reproduce

1. ...
2. ...
3. ...

## Expected behavior

<!-- What should happen? -->

## Actual behavior

<!-- What actually happens? -->

## Scope

Fix includes:

- [ ] Root cause identified
- [ ] Fix applied
- [ ] Regression test added

## Technical notes

<!-- Relevant files, methods, or modules. Any hypothesis about the cause. -->

## Validation

```bash
dotnet test --filter "RegressionTestName"
dotnet test
```

---

**Expected agent behavior**:
Identify root cause first. Fix the cause, not the symptom. Add a regression test that fails without the fix.

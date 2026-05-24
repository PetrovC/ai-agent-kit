---
name: Refactor
about: Improve code quality without changing behavior
labels: refactor
---

## Goal

<!-- What is the structural problem being solved? Why now? -->

## What changes

- [ ] ...
- [ ] ...

## What does NOT change

- Observable behavior remains identical.
- No new features.
- No new dependencies (unless explicitly listed below).

## Acceptance criteria

- [ ] All existing tests pass after the refactor.
- [ ] No behavior change detectable by tests.
- [ ] Code is simpler or more readable than before.

## Technical notes

<!-- Files, modules, patterns involved. -->

## Validation

<!--
Pull the canonical test invocation from `docs/ai/COMMANDS.md`. A refactor
must leave the full test suite green — record the exact command you ran.
-->

```bash
# <add the project's full-test command here — see docs/ai/COMMANDS.md>
```

---

**Expected agent behavior**:
Map all usages before editing. Change behavior is not acceptable. Update tests only if they were testing implementation details (and document why).

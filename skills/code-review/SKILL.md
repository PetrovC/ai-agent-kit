---
name: code-review
description: >
  Use when reviewing a branch, PR, diff, or implementation quality.
  Covers correctness, regression risk, security, maintainability, missing tests,
  architecture compliance, and dependency changes.
---

# Code Review Skill

## Goal

Find real problems before they reach production. Not cosmetic issues.

A good review catches: incorrect behavior, regressions, security holes, missing tests,
and architectural drift. It does not nitpick style unless style hides a real problem.

---

## Review priority order

Always triage by impact:

1. **Correctness** — Does it do what it claims to do?
2. **Security** — Does it expose vulnerabilities?
3. **Regression risk** — Does it break existing behavior?
4. **Missing tests** — Is changed behavior covered?
5. **Architecture compliance** — Does it respect layer boundaries and dependency direction?
6. **Maintainability** — Will the next developer understand it?
7. **Readability** — Is naming clear and consistent?

Stop at 1–2 if there are blockers. Do not bury critical findings under style comments.

---

## Correctness checks

- Does the logic match the acceptance criteria in the ticket?
- Are edge cases handled? (null, empty, negative, concurrent access, overflow)
- Are error paths handled correctly?
- Are return values checked?
- Are async methods awaited? Are cancellation tokens propagated?
- Are transactions used where atomicity is required?

---

## Security checks

- Is user input validated and sanitized before use?
- Are there SQL injection risks? (raw query string concatenation, unparameterized queries)
- Are authorization checks present and correctly placed?
- Are secrets hard-coded or logged? (tokens, passwords, connection strings)
- Are error messages leaking internal details to the client?
- Is CORS / CSRF / rate limiting weakened?

---

## Regression checks

- Are existing tests still passing?
- Does the change touch shared behavior that affects other features?
- Are there implicit dependencies that could break (shared state, global config, static methods)?

---

## Missing tests

Flag when:
- New behavior has no test.
- A fixed bug has no regression test.
- A changed method has no updated test.
- Tests were deleted without a clear reason.

---

## Architecture compliance

- Does the change respect layer boundaries? (no EF Core in Domain, no business logic in controllers)
- Does it follow existing naming conventions?
- Does it introduce a new pattern inconsistent with the existing codebase?
- Does it add a dependency that was not discussed?

---

## What NOT to flag

- Minor style preferences that do not affect clarity.
- Framework-specific patterns that are standard for this project.
- Refactoring opportunities unrelated to the current task.

Save observations for a separate "future improvement" section at the bottom of the review.

---

## Final response requirements

Structure your review as:

### Blockers
Issues that must be fixed before merge (correctness, security, regressions).

### Important
Issues that should be fixed but are not merge-blocking (missing tests, architecture drift).

### Minor
Readability, naming, low-risk cleanup.

### Future improvements
Optional observations for a later ticket. Not blocking.

Each finding must include:
- File and line reference.
- Concrete explanation of the risk or problem.
- Suggested fix or direction.

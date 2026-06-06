# Code Review Skill — Deep Reference

> Loaded on demand. The slim [`SKILL.md`](SKILL.md) covers the quick reference.

## Review priority order

Always triage by impact:

1. **Correctness** — Does it do what it claims to do?
2. **Security** — Does it expose vulnerabilities?
3. **Regression risk** — Does it break existing behavior?
4. **Missing tests** — Is changed behavior covered?
5. **Architecture compliance** — Does it respect layer boundaries and dependency direction?
6. **Data safety** — Are schema changes backward-compatible? Is the migration safe?
7. **Dependency changes** — Are new packages vetted?
8. **Maintainability** — Will the next developer understand it?
9. **Readability** — Is naming clear and consistent?

Stop at 1–2 if there are blockers. Do not bury critical findings under style comments.

---

## PR size

- A PR with >400 LOC changed (excluding generated / migration files) is hard to review well.
- If it's too big, request a split: "Can this be split into [feature behind flag] + [cleanup] + [integration]?"
- If it can't be split, focus the review on the riskiest sections first.
- Large auto-generated files (OpenAPI clients, EF Core migrations) can be skimmed, not line-reviewed.

---

## Correctness checks

- Does the logic match the acceptance criteria in the ticket?
- Are edge cases handled? (null, empty, negative, concurrent access, overflow, internationalization)
- Are error paths handled correctly? Do they propagate or swallow?
- Are return values checked everywhere the caller could fail silently?
- Are async methods awaited? Are cancellation tokens / signals propagated?
- Are transactions used where atomicity is required?
- Does the change handle the "happy path" only, ignoring partial failures?

---

## Security checks

- Is user input validated and sanitized before use?
- Are there SQL injection risks? (raw query concatenation, unparameterized queries)
- Are authorization checks present and correctly placed? (not just authentication)
- Are secrets hard-coded or logged? (tokens, passwords, connection strings, private keys)
- Are error messages leaking internal details to the client (stack traces, file paths)?
- Is CORS / CSRF / rate limiting weakened by the change?
- Does the change expose a new endpoint or operation without auth?
- Are file paths or URLs from user input validated against traversal? (`../../etc/passwd`)

See the `security` skill for detailed patterns per vulnerability class.

---

## Regression checks

- Are existing tests still passing with this change?
- Does the change touch shared behavior that affects other features?
- Are there implicit dependencies that could break (shared state, global config, static methods)?
- If a public interface changed — is every caller updated or is it backward-compatible?

---

## Async and concurrency checks

These are easy to miss in review and expensive to debug in production:

- **Missing await**: Is every `async` call site awaited? (JS/TS: `await`, C#: `await`, Python: `await`)
- **Fire-and-forget**: Is it intentional? If so, is the error handled somewhere?
- **Race condition**: Can two concurrent requests corrupt state? (e.g., read-modify-write without a lock or transaction)
- **Deadlock risk**: Are locks acquired in consistent order? Are `async` calls made while holding a lock?
- **Thread-safety**: Are shared mutable objects protected? (C# static fields, Python module-level state, Go maps)
- **CancellationToken / AbortSignal**: Is cancellation propagated through all async calls in the chain?
- **Event listener cleanup**: Are event listeners, timers, and subscriptions removed on component/service teardown?

---

## Data and schema changes

For any PR touching a migration, SQL, ORM schema, or seed data:

- Is the migration **reversible**? Can it be rolled back without data loss?
- Is the migration **backward-compatible** with the current deployed app? (additive only during deploy window)
- Does adding a `NOT NULL` column handle existing rows? (needs a `DEFAULT` or a backfill step)
- Does a new index use `CONCURRENTLY` (Postgres) or `ALGORITHM=INPLACE` (MySQL) to avoid table locks?
- Is a column rename done in two steps (add → dual-write → remove) rather than one?
- Is there a risk of the migration exceeding the deploy timeout on the current data volume?
- Are there `SELECT *` queries that will break when columns are added?

See the `database` skill for migration safety rules.

---

## Dependency changes

For any PR adding or updating a package/library:

- Is the license acceptable? (MIT, Apache 2.0, BSD preferred — GPL is usually a problem for commercial code)
- Is the package actively maintained? (last commit, open CVEs, npm/PyPI download trends)
- Is the version pinned or range-constrained? (`^1.2.3` vs `>=1` are very different)
- Does the dependency bring in a large transitive dependency tree that wasn't there before?
- For frontend: does it significantly increase bundle size? (check with `bundlephobia.com` or `vite-bundle-analyzer`)
- Is there an existing package already in the project that does the same thing?

---

## Performance flags

Flag (don't block) when you see:

- **O(n²) or worse** iteration over a non-trivially-sized collection.
- **N+1 queries** — a query inside a loop; use a batch query or eager-load instead.
- **Missing pagination** on a query that could return unbounded rows.
- **No caching** for an expensive, repeated, deterministic read.
- **Synchronous I/O** on a hot path in an async service.
- **Unbounded retry loops** without a backoff or iteration cap.

---

## Missing tests

Flag as **Important** (not Blocker unless the risk is high) when:

- New behavior has no test.
- A fixed bug has no regression test.
- A changed method has no updated test.
- Tests were deleted without a clear reason.
- The only tests are happy-path; error paths are untested.

---

## Architecture compliance

- Does the change respect layer boundaries? (no EF Core / ORM in Domain, no business logic in controllers or route handlers)
- Does it introduce a new cross-module import that bypasses the public API?
- Does it follow existing naming conventions (file names, class names, URL patterns)?
- Does it introduce a pattern inconsistent with the rest of the codebase without discussion?
- Does it add a new dependency direction that violates the established flow?

See the `architecture` skill for layer rules.

---

## Review comment quality

**Format every finding as:**
```
[File:line] Problem description.
Why it matters: <one sentence on the risk>.
Suggestion: <concrete alternative or direction>.
```

**Example of a good comment:**
```
[src/orders/OrderService.ts:47] The retry loop has no iteration cap.
Why it matters: if the downstream is down for 10 minutes, this will spin indefinitely and exhaust the thread pool.
Suggestion: add a max-attempts guard (e.g., Polly retry with count=3 and exponential backoff).
```

**Tone rules:**
- Use "consider", "suggest", "could" for non-blocking items. Reserve "must" for blockers.
- Phrase as a question when you're not certain: "Is this intentional?" or "Did you mean X?"
- Never attribute intent negatively ("you forgot", "you broke"). Describe the code, not the author.
- Acknowledge good choices: if a section solves a hard problem cleanly, say so.

---

## What NOT to flag

- Minor style preferences that do not affect clarity.
- Framework-specific patterns that are standard for this project.
- Refactoring opportunities unrelated to the current task.
- Personal preference over equally correct choices (tabs vs spaces where the linter handles it).

Save observations for a "Future improvements" section at the bottom of the review.

---

## Final response requirements

Structure your review as:

### Blockers
Issues that must be fixed before merge (correctness, security, regressions, data loss risk).

### Important
Issues that should be fixed: missing tests, architecture drift, unsafe async patterns, dependency problems.

### Minor
Readability, naming, low-risk cleanup.

### Future improvements
Optional observations for a later ticket. Not blocking.

Each finding must include:
- File and line reference.
- Concrete explanation of the risk or problem.
- Suggested fix or direction.

End the review with a one-line summary: "Ready to merge", "Needs changes (N blockers)", or "Needs discussion".

---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/tests/**"
  - "**/__tests__/**"
  - "**/test/**"
---
# Test rules

Naming: `<what>_<when/condition>_<expected>` or `describe/it` natural language.

Rules:
- Never use `.only` or `fdescribe`/`fit` — they silently skip all other tests.
- Never skip tests without a comment explaining why and linking an issue.
- One assertion concept per test; multiple assertions are fine if they prove the same thing.
- Tests must be deterministic — no random data, no time-dependent assertions without mocking.
- Prefer real types over `any` / untyped mocks.
- Test the behavior (what it does), not the implementation (how it does it).
- Delete dead tests rather than commenting them out.

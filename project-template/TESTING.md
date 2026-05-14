# Testing Strategy

> ⚠️ **STOP — Adjust this file for your stack before letting any agent read it.**
> Defaults assume .NET + xUnit + Testcontainers. Remove what does not apply.
> Once adjusted, remove this notice.

---

## Test levels

| Level | Scope | Framework | Location |
|---|---|---|---|
| Unit | Domain + Application logic | xUnit | `tests/Domain.Tests`, `tests/Application.Tests` |
| Integration | DB, EF Core, external adapters | xUnit + Testcontainers | `tests/Integration.Tests` |
| E2E | Critical user flows | TBD | `tests/E2E.Tests` |

---

## What we test at each level

**Unit tests**
- Domain entity invariants and business rules.
- Application handler logic (with mocked dependencies).
- Calculation methods, validation logic, edge cases.

**Integration tests**
- EF Core repository behavior against a real database.
- External API adapters.
- DI container registration.

**E2E tests**
- Kept minimal. Only for the most critical user flows.

---

## Naming convention

```csharp
// MethodName_Scenario_ExpectedResult
CalculateBalance_WhenLeaveOverlapsHoliday_ShouldDeductOnce()

// or GivenX_WhenY_ThenZ
GivenApprovedLeave_WhenHolidayFallsInRange_ThenBalanceDeductedOnce()
```

Pick one pattern per class and stick to it.

---

## Required before any PR

- [ ] All existing tests pass.
- [ ] New behavior is covered by at least one test.
- [ ] Bug fixes have a regression test.
- [ ] `dotnet test` exits with code 0.

---

## Test data conventions

- Use clearly named builders or factory methods. No magic numbers.
- Prefer hardcoded, deterministic dates/values over random data.
- Isolate tests: no shared mutable state between tests.

---

## Mocking rules

- Use NSubstitute (or Moq — be consistent within a project).
- Mock only at the application layer boundary (infrastructure ports).
- Do not mock domain objects — use real instances.
- Test behavior, not that a mock was called.

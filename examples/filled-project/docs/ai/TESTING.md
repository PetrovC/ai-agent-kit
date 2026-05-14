# Testing Strategy

## Test levels

| Level | Scope | Framework | Location |
|---|---|---|---|
| Unit | Domain + Application logic | xUnit + FluentAssertions | `backend/tests/LeaveDesk.Domain.Tests`, `backend/tests/LeaveDesk.Application.Tests` |
| Integration | DB, EF Core, holiday calendars | xUnit + Testcontainers (Postgres) | `backend/tests/LeaveDesk.Integration.Tests` |
| Frontend unit | Composables, components | Vitest + @vue/test-utils | `frontend/src/features/**/__tests__` |
| E2E | Critical user flows | Playwright | `frontend/e2e` |

The mass of tests lives at the unit level (~85%). Integration tests cover the
EF Core mapping + the Postgres-specific behaviors (timezone, jsonb queries).
E2E is reserved for: login → request leave → manager approves → balance updates.

## Naming convention

Backend uses `MethodName_Scenario_ExpectedResult`:

```
CalculateDaysConsumed_WhenLeaveOverlapsHoliday_ShouldDeductOnce
ApproveLeaveRequest_WhenCallerIsNotManager_ShouldReturnForbidden
```

Frontend uses BDD-style with `describe / it`:

```
describe('useLeaveForm', () => {
  it('rejects submission when end date is before start date', () => { ... })
})
```

## Mocking rules

- We use **NSubstitute** for backend test doubles. No Moq in new code.
- Frontend uses `vi.fn()` and MSW for network mocking.
- Integration tests **do not mock** the database. Real Postgres via Testcontainers.
- We never mock our own types — we use fakes for ports (`IHolidayCalendar`, `IClock`, `ILeaveRepository`).

## Test data

- A `TestDataBuilder` per aggregate (`LeaveRequestBuilder`, `WorkspaceBuilder`).
- Sensible defaults; tests override only the relevant fields.
- Dates are fixed to 2026 (a leap year with predictable holidays) to keep tests deterministic.

## Coverage targets

- Domain layer: 95%+ (it's pure code, no excuses).
- Application layer: 85%+.
- Infrastructure: not measured (tested via integration tests).
- Frontend features: 75%+ on logic; UI snapshots discouraged.

## Known gaps

- The manager-approval E2E test is flaky (bug #517). Currently skipped in CI, opt-in via `pnpm test:e2e:flaky`.
- Holiday calendar tests for NL / ES / DE are TODO until v1.2 lands.

## CI

CI runs all unit + integration tests on every PR. E2E runs on `main` only,
nightly. Failures block merge except for tests in the `[Trait("Flaky","true")]`
category.

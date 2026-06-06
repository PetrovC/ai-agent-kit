# Testing Skill — Deep Reference

> Loaded on demand. The slim [`SKILL.md`](SKILL.md) covers the quick reference.

## Test pyramid

Prefer this distribution:

```
         /\
        /  \   E2E — critical user flows only
       /----\
      /      \  Integration — boundaries, DB, external adapters
     /--------\
    /          \  Unit — domain and application logic  ← most tests here
   /____________\
```

- **Unit tests**: fast, isolated, no I/O. For domain rules, application logic, calculations.
- **Integration tests**: for database, external APIs, configuration, DI container.
- **E2E tests**: only for critical end-to-end user flows. Keep them few and stable.

---

## Universal rules (any language)

- Test **behavior**, not implementation details.
- A test that only verifies a mock was called is not a meaningful test.
- Avoid coupling tests to private functions, internal state, or implementation order.
- One concept per test. If a test has 3 Act sections, split it.
- Tests must be deterministic. No raw sleeps, no unseeded random data, no real network calls.
- Tests must be independent. No shared mutable state between tests.
- Tests must be readable. Another developer should understand what is tested from the test name alone.

---

## Naming conventions

Use one of these two patterns consistently within a project:

```
// Pattern 1 — subject / scenario / expected result
calculateBalance_whenLeaveOverlapsHoliday_shouldDeductOnce

// Pattern 2 — given / when / then (BDD-style)
givenApprovedLeave_whenHolidayFallsInRange_thenBalanceDeductedOnce
```

Adapt to the language's idiomatic case (camelCase, snake_case, PascalCase). Do not mix patterns in the same test file.

For frameworks using `describe / it` (Vitest, Jest, RSpec, pytest with nested classes):

```
describe('LeaveCalculation', () => {
  it('deducts one day when leave overlaps a holiday', () => { ... })
})
```

---

## AAA structure

Every test follows Arrange / Act / Assert. Pick one example below in your language:

### .NET (xUnit + FluentAssertions)

```csharp
// Arrange
var service = new LeaveCalculationService(holidays);
var leave = new LeaveRequest(start: Jan1, end: Jan5);

// Act
var result = service.CalculateDaysConsumed(leave);

// Assert
result.Should().Be(4); // Jan 1 is a holiday
```

### Python (pytest)

```python
def test_deducts_one_day_when_leave_overlaps_holiday() -> None:
    # Arrange
    service = LeaveCalculationService(holidays=[date(2026, 1, 1)])
    leave = LeaveRequest(start=date(2026, 1, 1), end=date(2026, 1, 5))

    # Act
    result = service.calculate_days_consumed(leave)

    # Assert
    assert result == 4
```

### Node (Vitest)

```ts
import { describe, it, expect } from 'vitest';

describe('LeaveCalculation', () => {
  it('deducts one day when leave overlaps a holiday', () => {
    // Arrange
    const service = new LeaveCalculationService([new Date('2026-01-01')]);
    const leave = { start: new Date('2026-01-01'), end: new Date('2026-01-05') };

    // Act
    const result = service.calculateDaysConsumed(leave);

    // Assert
    expect(result).toBe(4);
  });
});
```

### Go (testing + table-driven)

```go
func TestCalculateDaysConsumed(t *testing.T) {
    cases := []struct {
        name string
        leave Leave
        want  int
    }{
        {"overlaps holiday", Leave{Start: jan1, End: jan5}, 4},
        {"no holiday",       Leave{Start: jan6, End: jan9}, 4},
    }
    for _, tc := range cases {
        t.Run(tc.name, func(t *testing.T) {
            got := CalculateDaysConsumed(tc.leave, holidays)
            if got != tc.want {
                t.Errorf("got %d, want %d", got, tc.want)
            }
        })
    }
}
```

### Rust (cargo test)

```rust
#[test]
fn deducts_one_day_when_leave_overlaps_holiday() {
    // Arrange
    let service = LeaveCalculationService::new(vec![date(2026, 1, 1)]);
    let leave = LeaveRequest::new(date(2026, 1, 1), date(2026, 1, 5));

    // Act
    let result = service.calculate_days_consumed(&leave);

    // Assert
    assert_eq!(result, 4);
}
```

---

## Mocking / test doubles per language

| Language | Library | Notes |
|---|---|---|
| .NET | NSubstitute, Moq | Prefer NSubstitute for new code; pick one per project. |
| Python | `unittest.mock` (stdlib), `pytest-mock` | Or just inject fakes — often clearer. |
| Node / TS | `vi.fn()` (Vitest), `jest.fn()` | Avoid `jest.mock()` of internal modules — inject fakes. |
| Go | Hand-written fakes implementing the interface | The standard idiom. `gomock` only for large interfaces. |
| Rust | `mockall` for trait-heavy code | Hand-written fakes work and don't require codegen. |
| Flutter / Dart | `mocktail` | No codegen — preferred over `mockito` for new projects. |

**Rule across all languages**: don't mock something you own — use the real thing or a hand-written fake. Mock only external boundaries (HTTP, DB if integration not feasible, third-party SDKs).

---

## Integration tests

- Use a **real** database in integration tests (Testcontainers or a dedicated test DB). SQLite-as-Postgres-substitute hides real bugs.
- Set up and tear down per test, or per test class — never share state without an explicit reset.
- HTTP integration: spin up the framework's test harness (`TestClient` in FastAPI, `WebApplicationFactory` in ASP.NET, `supertest` in Express, `app.inject` in Fastify, `httptest` in Go, `axum::Server` in Rust tests).
- Always set timeouts on external-facing tests.

---

## Regression tests

When fixing a bug:
- Add a regression test that **fails without the fix** and passes with it.
- Name it clearly: `getDaysConsumed_whenHolidayOnWeekend_shouldNotDoubleCount`
- Include a short comment explaining what was broken before — readers in two years will thank you.

---

## What NOT to do

- Do not test framework behavior (ORM save calls, router resolution).
- Do not create a test class with 50 tests that all hit the same method with tiny variations — use parametrized / table-driven.
- Do not write a test with no assertion.
- Do not assert on unrelated side effects just because you can.
- Do not mark a test as passing if it has not been run.
- Do not use real time / real network / real disk for unit tests — inject a clock, mock the boundary.

---

## When tests cannot be run

State explicitly:
- Why they cannot be run (missing DB, missing environment, CI only).
- Exactly which commands should be run manually.
- Which behaviors are covered and which are not yet verified.

---

## Frontend testing

### Vue 3 (Vitest + @vue/test-utils)

- Test composables by calling them directly — not inside a component.
- Test components through the public API: props, emits, slots. Not internal state.
- `mount` over `shallowMount` unless a child is heavy.
- Mock Pinia stores with `createTestingPinia()` from `@pinia/testing`.

```ts
const wrapper = mount(MyComponent, { props: { label: 'Save' } });
await wrapper.find('button').trigger('click');
expect(wrapper.emitted('save')).toBeTruthy();
```

### Angular (Jest or Vitest + TestBed)

- Services: test in isolation with `TestBed` or plain `new`.
- Components: query with `By.css()` or `By.directive()`.
- Mock dependencies via `TestBed.overrideProvider()`.
- For signals: set input signals, assert on computed / effect outputs.

### React (Vitest + React Testing Library)

- Query by accessible role / label / text — avoid `getByTestId`.
- Use `@testing-library/user-event` for typing / clicking (not `fireEvent`).
- `findBy*` queries auto-await for async UI.

```tsx
await userEvent.click(screen.getByRole('button', { name: /save/i }));
expect(onSave).toHaveBeenCalled();
```

### Mobile (RN + Flutter)

- See the `mobile-rn` and `mobile-flutter` skills for full testing guidance specific to those stacks.

### Network mocking (frontend)

- Use **MSW** (Mock Service Worker, MIT) — intercepts at the network level, not the fetch wrapper. Reusable across unit and integration tests.

---

## Verification commands per stack

```bash
# .NET
dotnet test
dotnet test --filter "FullyQualifiedName~LeaveCalculation"
dotnet test --logger "trx;LogFileName=results.trx"

# Python
uv run pytest -q
uv run pytest -k leave_calculation
uv run pytest --cov=src --cov-report=term-missing

# Node / TypeScript
pnpm test                       # vitest / jest
pnpm test --coverage
pnpm vitest run --reporter=verbose

# Go
go test ./...
go test -race -count=1 ./...
go test -run TestCalculateDaysConsumed -v

# Rust
cargo test
cargo test --all-features
cargo test --doc                # doctests

# Flutter
flutter test
flutter test --coverage
flutter test test/features/leave/leave_calculation_test.dart
```

---

## Final response requirements

Always report:
- Test files added or modified, with their language / framework.
- Number of tests added or changed.
- Commands run and result (pass / fail / skipped count).
- What is NOT covered and why.
- Any new test dependency: name, version, **license (MIT only — see `dependencies` skill)**.

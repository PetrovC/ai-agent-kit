# .NET — Testing Reference

## Load when

Load this reference when:
- Task adds, modifies, or reviews tests.
- Task text mentions: xUnit, test, spec, mock, NSubstitute, Moq, FluentAssertions,
  fixture, arrange/act/assert, integration test, unit test, regression test.
- Changed files are in `**/Tests/**`, `**/Test/**`, or match `**Test*.cs`, `**Tests.cs`.

---

## Framework and tooling

- Use **xUnit** for the test framework.
- Use **FluentAssertions** or xUnit native assertions. Be consistent with the suite.
- Use **NSubstitute** or **Moq** for mocking. Be consistent with the suite.

## Test structure

- Follow the **AAA pattern**: Arrange / Act / Assert.
- Name tests: `MethodName_Scenario_ExpectedResult` or `GivenX_WhenY_ThenZ`.
- Test behavior, not implementation details.
- Never test only that a mock was called — test what actually happened as a result.
- Add a regression test when fixing a bug.

## Coverage rules

- New business logic in the Domain or Application layer must have unit tests.
- Infrastructure (EF Core) integration tests require a real or in-memory database.
- Do not use `[Ignore]` or `Skip` without a comment explaining why and a ticket.

## Verification

```bash
dotnet test --no-build
dotnet test --no-build --collect:"XPlat Code Coverage"
```

---
name: dotnet
description: >
  Use when modifying C#, .NET, ASP.NET Core, Entity Framework Core, xUnit,
  backend services, dependency injection, CQRS handlers, domain logic,
  application layer, or any backend project structure.
paths:
  - "**/*.cs"
  - "**/*.csproj"
  - "**/*.sln"
  - "**/global.json"
allowed-tools:
  - "Bash(dotnet:*)"
---

# .NET Skill

## Goal

Produce simple, explicit, maintainable .NET code that a junior developer can understand
and that a senior developer would not need to refactor in 6 months.

---

## Layering

Respect this dependency direction at all times:

```
Domain
  ↑
Application  (commands, queries, handlers, ports, validation)
  ↑
Infrastructure  (EF Core, external APIs, file system, email, queues)
  ↑
Interfaces  (controllers, endpoints, workers, CLI, minimal APIs)
```

Rules:
- Domain must not reference EF Core, ASP.NET, HTTP, or any infrastructure concern.
- Application must not reference concrete infrastructure implementations.
- Infrastructure implements ports/interfaces defined in Application.
- Interfaces call application use cases; they do not contain business logic.
- Do not shortcut layers to "save time."

---

## CQRS

When the project uses CQRS (commands / queries / dispatcher):
- Commands change state. Queries return data. Never mix both.
- Handlers contain orchestration only — not business rules.
- Business rules belong in domain entities or domain services.
- Validation belongs in the application layer (FluentValidation or explicit guard clauses).
- Do not put EF Core queries directly in controllers or UI layers.

---

## Entity Framework Core

- Use repositories or query services defined in Application, implemented in Infrastructure.
- Do not leak `DbContext` into the domain or application layers.
- Migrations belong in Infrastructure.
- Use explicit configurations (`IEntityTypeConfiguration<T>`) over data annotations where possible.
- Avoid lazy loading unless explicitly justified.
- Prefer `AsNoTracking()` for read-only queries.

---

## Dependency injection

- Register services with the correct lifetime: Singleton / Scoped / Transient.
- Do not capture Scoped services inside Singletons.
- Use `IOptions<T>` for configuration binding.
- Prefer constructor injection. Avoid service locator pattern.
- When using Scrutor for assembly scanning, test that registrations resolve correctly.

---

## Code style

- Prefer records for immutable DTOs and value objects.
- Prefer primary constructors for simple classes (C# 12+).
- Use `required` keyword for mandatory properties.
- Use `file` keyword to scope types that are not used outside their file.
- Use pattern matching and switch expressions over long if/else chains.
- Avoid nullable reference type warnings — configure `<Nullable>enable</Nullable>` and handle null explicitly.
- Use `ArgumentNullException.ThrowIfNull()` and `ArgumentException.ThrowIfNullOrWhiteSpace()`.

---

## Naming

- Commands: `CreateLeaveRequestCommand`, `ApproveLeaveRequestCommand`
- Queries: `GetLeaveRequestByIdQuery`, `GetLeaveRequestsForUserQuery`
- Handlers: `CreateLeaveRequestCommandHandler`, `GetLeaveRequestByIdQueryHandler`
- Events: `LeaveRequestCreatedEvent`, `LeaveRequestApprovedEvent`
- DTOs: `LeaveRequestDto`, `CreateLeaveRequestRequest`
- Repositories: `ILeaveRequestRepository`, `LeaveRequestRepository`

---

## Testing

- Use xUnit.
- Use FluentAssertions or xUnit native assertions. Be consistent with the existing suite.
- Use NSubstitute or Moq. Be consistent with the existing suite.
- Test behavior, not implementation details.
- Prefer the AAA pattern (Arrange / Act / Assert).
- Name tests: `MethodName_Scenario_ExpectedResult` or `GivenX_WhenY_ThenZ`.
- Add a regression test when fixing a bug.
- Never test only that a mock was called — test what actually happened as a result.

---

## Package and runtime maintenance

When you notice (during any task) that NuGet packages or the .NET runtime version can be updated, follow this protocol — **do not apply silently**.

### Protocol

1. **Surface it explicitly** — list what can be updated and why (security patch, bug fix, LTS upgrade, outdated minor).
2. **Wait for approval** — do not touch anything until the user confirms.
3. **If approved, apply:**
   - **NuGet update**: update one package at a time; run `dotnet restore && dotnet build && dotnet test` after each update.
   - **.NET runtime upgrade**: bump `<TargetFramework>` in all `.csproj` files, update `global.json` if present, fix any breaking change warnings, consult the official migration guide.
4. **Report** — which versions changed, whether tests pass, and any breaking changes handled.

### Commands to detect what needs updating

```bash
# Packages with available updates
dotnet list package --outdated

# Packages with known vulnerabilities (run regularly)
dotnet list package --vulnerable --include-transitive

# Installed .NET SDKs
dotnet --list-sdks

# Installed .NET runtimes
dotnet --list-runtimes
```

### .NET runtime upgrade checklist

- Bump `<TargetFramework>` in every `.csproj` (e.g., `net8.0` → `net9.0`).
- Update `global.json` `sdk.version` if present.
- Run `dotnet build` and fix compiler warnings introduced by the new TFM.
- Check [the official migration guide](https://learn.microsoft.com/en-us/dotnet/core/compatibility/) for breaking changes.
- Only propose upgrades to **stable LTS releases** unless the user explicitly asks for a non-LTS version.
- Verify NuGet packages are compatible with the new TFM before proposing the upgrade.

---

## Verification commands

Run these in order, from smallest to broadest:

```bash
dotnet restore
dotnet build --no-restore
dotnet test --no-build
dotnet format --verify-no-changes
```

---

## Final response requirements

Always report:
- Changed files with layer (Domain / Application / Infrastructure / Interfaces).
- Tests added or updated.
- Commands run and result.
- Any architecture boundary that was touched or affected.
- Risks or assumptions.

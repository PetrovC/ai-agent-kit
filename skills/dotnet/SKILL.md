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
version: "1.0.0"
keywords:
  - dotnet
  - csharp
  - c#
  - asp.net
  - aspnet
  - entity framework
  - ef core
  - xunit
  - mediatr
  - ddd
  - cqrs
task_intents:
  - implement
  - review
  - fix
  - refactor
  - data-migration
delegation_hints:
  can_delegate: true
  when: >
    When the task also involves a frontend (Angular, Vue, React) — delegate
    backend to a focused subagent.
---

# .NET Skill

## Goal

Produce simple, explicit, maintainable .NET code that a junior developer can
understand and that a senior developer would not need to refactor in 6 months.

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

- Domain must not reference EF Core, ASP.NET, HTTP, or any infrastructure concern.
- Application must not reference concrete infrastructure implementations.
- Infrastructure implements ports defined in Application.
- Interfaces call application use cases; they do not contain business logic.

## References

Load these only when signals justify it:

| Reference | Load when |
|---|---|
| [`references/clean-architecture.md`](references/clean-architecture.md) | Task touches multiple layers, adds a new feature, or refactors cross-layer dependencies. Task text mentions DDD, CQRS, aggregate, value object, bounded context, or Clean Architecture. Files in `**/Domain/**`, `**/Application/**`, or `**/Infrastructure/**`. |
| [`references/ef-core.md`](references/ef-core.md) | Task touches database queries, migrations, DbContext, repositories, or EF configuration. Files match `**/Infrastructure/**`, `**/Migrations/**`, or `**DbContext**`, `**Repository**`. |
| [`references/testing.md`](references/testing.md) | Task adds or modifies tests, or the review must verify test coverage. Task text mentions xUnit, test, spec, mock, or fixture. Files in `**/Tests/**` or `**Test*.cs`. |
| [`references/package-maintenance.md`](references/package-maintenance.md) | Task involves NuGet updates, runtime upgrades, or vulnerability remediation. Task text mentions package, NuGet, upgrade, or outdated. |

## Verification commands

```bash
dotnet restore
dotnet build --no-restore
dotnet test --no-build
dotnet format --verify-no-changes
```

## Final response requirements

Always report:
- Changed files with layer (Domain / Application / Infrastructure / Interfaces).
- Tests added or updated.
- Commands run and result.
- Any architecture boundary that was touched or affected.
- Risks or assumptions.

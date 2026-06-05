# .NET — Clean Architecture, DDD, and CQRS Reference

## Load when

Load this reference when:
- Task touches multiple layers, introduces a new feature, or refactors
  cross-layer dependencies.
- Task text mentions: DDD, domain-driven design, aggregate, value object,
  bounded context, CQRS, command, query, handler, event, domain event,
  Clean Architecture.
- Changed files are in `**/Domain/**`, `**/Application/**`, or
  `**/Infrastructure/**`.

---

## Layer rules

**Domain layer** — zero external dependencies:
- Contains: entities, aggregates, value objects, domain events, domain services,
  repository interfaces (not implementations), domain exceptions.
- Must not reference EF Core, ASP.NET, HTTP, file system, or any infrastructure
  concern.
- Business rules belong here — not in handlers, not in controllers.

**Application layer** — orchestrates use cases:
- Contains: commands, queries, command/query handlers, application services,
  validation, port/interface definitions.
- Must not reference concrete infrastructure implementations.
- Handlers orchestrate — they do not contain business rules.
- Business rules belong in the domain layer.

**Infrastructure layer** — implements ports:
- Contains: EF Core DbContext, migrations, repository implementations, external
  API clients, file system adapters, email, queues.
- Implements interfaces/ports defined in Application.
- Only the composition root (DI configuration) knows about Infrastructure.

**Interfaces layer** — entry points only:
- Contains: controllers, minimal API endpoints, gRPC handlers, CLI entry points,
  background workers.
- Calls application use cases; never contains business logic.

---

## CQRS

- Commands change state. Queries return data. Never mix both in one handler.
- Handlers contain orchestration only — not business rules.
- Business rules belong in domain entities or domain services.
- Validation belongs in the application layer (FluentValidation or guard clauses).
- Do not put EF Core queries directly in controllers or UI layers.

---

## Naming conventions

| Type | Example |
|---|---|
| Commands | `CreateLeaveRequestCommand`, `ApproveLeaveRequestCommand` |
| Queries | `GetLeaveRequestByIdQuery`, `GetLeaveRequestsForUserQuery` |
| Handlers | `CreateLeaveRequestCommandHandler` |
| Events | `LeaveRequestCreatedEvent` |
| DTOs | `LeaveRequestDto`, `CreateLeaveRequestRequest` |
| Repositories | `ILeaveRequestRepository`, `LeaveRequestRepository` |

---

## Code style

- Prefer records for immutable DTOs and value objects.
- Prefer primary constructors for simple classes (C# 12+).
- Use `required` for mandatory properties.
- Use `file` to scope types not used outside their file.
- Use pattern matching and switch expressions over long if/else chains.
- Configure `<Nullable>enable</Nullable>` and handle null explicitly.
- Use `ArgumentNullException.ThrowIfNull()` and
  `ArgumentException.ThrowIfNullOrWhiteSpace()`.

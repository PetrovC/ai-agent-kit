# Architecture

## Overview

LeaveDesk is a small layered monolith. Backend in C# / .NET 8, frontend in Vue 3.
Communication is HTTP/JSON. State of record is PostgreSQL on Supabase. There
are no background workers, no message queues — every operation is synchronous
within an HTTP request.

## Solution layout

```
backend/
  src/
    LeaveDesk.Domain/            # pure C#, no I/O
    LeaveDesk.Application/       # commands, queries, ports
    LeaveDesk.Infrastructure/    # EF Core, Supabase auth client, holiday calendars
    LeaveDesk.Api/               # ASP.NET Core minimal APIs
  tests/
    LeaveDesk.Domain.Tests/      # unit
    LeaveDesk.Application.Tests/ # unit + handler tests
    LeaveDesk.Integration.Tests/ # Testcontainers Postgres

frontend/
  src/
    features/
      leaves/                    # request form, list, calendar
      balance/                   # balance widget + history
      workspace/                 # admin: users, policies, calendar
    components/                  # reusable presentational
    lib/                         # api client, auth
    router/
    stores/                      # Pinia (UI-only state)
  tests/                         # vitest
```

## Dependency direction

```
Domain
  ↑
Application   (defines IHolidayCalendar, ILeaveRepository, IClock)
  ↑
Infrastructure  (implements ports — EF Core, FR/BE/NL/ES/DE calendars, system clock)
  ↑
Api
```

Rules enforced in PR review:
- `LeaveDesk.Domain.csproj` references nothing except base BCL.
- `LeaveDesk.Application.csproj` references `Domain` only.
- `LeaveDesk.Infrastructure.csproj` references `Application` (and indirectly Domain).
- `LeaveDesk.Api.csproj` references `Application` + `Infrastructure`.
- No project may reference `Api`.

## Modules

| Module | Responsibility |
|---|---|
| `Domain/Leave` | `LeaveRequest`, `LeaveStatus`, `Balance`, `WorkingDayCalendar` — rules for consumed days. |
| `Domain/Workspace` | `Workspace`, `Member`, `Role`. |
| `Application/Leaves` | Commands: `CreateLeaveRequest`, `ApproveLeaveRequest`, `CancelLeaveRequest`. Queries: `GetLeaveById`, `GetLeavesForUser`. |
| `Application/Balances` | `RecomputeBalance` (idempotent), `GetBalance`. |
| `Application/Calendars` | `IHolidayCalendar` port, `CalendarResolver`. |
| `Infrastructure/Calendars` | `FrenchHolidayCalendar`, `BelgianHolidayCalendar`, etc. |
| `Infrastructure/Persistence` | `AppDbContext` (EF Core), repositories, `IEntityTypeConfiguration<T>` per aggregate. |
| `Api/Leaves` | Minimal API endpoints, authz policies. |

## Key flows

### Create leave request

```
POST /api/leaves
  → CreateLeaveRequestCommand
    → resolve calendar for workspace
    → compute consumed days (Domain)
    → check balance (Application)
    → persist (Infrastructure)
    → return LeaveDto (Api)
```

Validation: FluentValidation in Application. Authz: caller must be a member of the target workspace.

### Approve leave request

```
POST /api/leaves/{id}/approve
  → ApproveLeaveRequestCommand
    → load request (must belong to a team the caller manages)
    → set Status = Approved
    → emit LeaveApproved domain event (in-process, no broker)
    → balance is updated synchronously
```

## Integration points

| External | What | Failure mode |
|---|---|---|
| Supabase Auth | JWT verification (RS256 with public key cached) | 401 returned to caller; no degraded mode. |
| Supabase Postgres | Read/write via EF Core | Connection pool retry (Polly); fast-fail after 3 attempts. |
| (Vercel + Fly.io) | Hosting | Out of scope for the application code. |

## Cross-cutting

- **Logging**: Serilog → stdout (Fly.io collects). Request ID middleware injects `RequestId` into every log scope.
- **Errors**: RFC 7807 problem details on the API. Domain throws typed exceptions; `Api` maps them in a single middleware.
- **Time**: never `DateTime.UtcNow` in domain — `IClock` is injected.
- **Config**: `IOptions<T>` bound to `appsettings.json` + env vars. Secrets via Fly.io secrets, never committed.

## Non-goals

- No event sourcing.
- No microservices.
- No CQRS read models (queries hit the same EF Core schema as commands).
- No CRDT / offline-first frontend.

If any of these become useful, the change goes through `DECISIONS.md`.

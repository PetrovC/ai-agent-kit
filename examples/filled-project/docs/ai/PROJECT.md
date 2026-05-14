# Project Context

## Product vision

LeaveDesk is a small SaaS for SMBs (5-200 employees) to manage paid time off.
Employees request leaves, managers approve, HR sees the team calendar and
balances. Replaces the spreadsheet most small teams currently use.

## Current milestone

**v1.2 — Public holidays per country**. Today, holidays are configured manually
per workspace. We're shipping built-in calendars for FR, BE, NL, ES, DE so a new
workspace works out of the box. Target ship: 2026-06-15.

## In scope

- [x] Holiday provider abstraction (`IHolidayCalendar`).
- [x] FR + BE built-in calendars.
- [ ] NL, ES, DE calendars.
- [ ] Per-workspace override mechanism (workspace can disable a national holiday).
- [ ] Migration script to convert existing manual entries.

## Out of scope

- Regional / sub-national holidays (US states, Spanish autonomous communities). Tracked for v1.3.
- Religious calendar variants. Probably never.
- Half-day holidays. Tracked but not planned.

## Users and roles

| Role | Description | Key permissions |
|---|---|---|
| Employee | Requests and views leaves | Create / cancel own requests, see own balance |
| Manager | Approves leaves in their team | Approve / reject team requests, see team calendar |
| HR Admin | Configures workspace | Manage users, policies, balances, calendar overrides |
| Owner | Workspace owner | All HR Admin rights + billing |

## Main workflows

1. **Request leave**: Employee fills form → app computes consumed days (excluding weekends + holidays) → request is sent to direct manager → manager approves or rejects → balance is updated.
2. **Configure workspace**: HR Admin sets country (drives default holidays), leave types (paid / unpaid / sick / RTT), annual quota per type.
3. **Cancel approved leave**: Employee or manager cancels; balance is credited back; calendar entry removed.

## Current technical stack

| Layer | Technology |
|---|---|
| Backend | ASP.NET Core 8, C# 12 |
| Frontend | Vue 3 + Vite, Pinia, TanStack Query |
| Database | PostgreSQL 16 (Supabase-hosted) |
| Auth | Supabase Auth (JWT) |
| Messaging | None (sync only for now) |
| Hosting | Fly.io (backend), Vercel (frontend) |
| CI/CD | GitHub Actions |
| Testing | xUnit + Testcontainers (backend), Vitest + Vue Test Utils (frontend) |

## Important technical choices

- CQRS-lite with handler classes (see DECISIONS.md #2). No MediatR — direct DI of handlers.
- Domain layer is pure C#, no EF Core types. Repositories defined in Application.
- Frontend uses TanStack Query as the server cache; Pinia only for ephemeral UI state.
- All times stored as `timestamptz` UTC. Display uses workspace timezone.

## Constraints

- Stay free-tier on Supabase + Fly.io until 50 paying workspaces.
- GDPR: all data hosted in EU regions (Frankfurt, Paris).
- No third-party calendar providers (no Google/Outlook holiday APIs) — pulls latency and free-tier limits.

## Current priorities

1. Ship NL + ES + DE calendars before 2026-06-15.
2. Performance: balance recomputation is O(n) in leaves; cache by workspace.
3. Reduce flakiness in the manager-approval E2E test.

## Known risks

- Holiday data accuracy: we don't have a paid feed. Manual updates each November for the following year.
- Time zone bug: hired employees in workspaces with multiple offices report wrong consumed days for cross-DST leaves. Reproduces 1 case / month. Bug #482 open.

# Roadmap

High-level milestones. Detailed tasks live in GitHub Issues / Linear.

---

## Current milestone — v1.2 (target 2026-06-15)

**Name**: Public holidays per country
**Goal**: New workspaces get accurate holidays out of the box for FR / BE / NL / ES / DE.

- [x] Holiday provider abstraction
- [x] FR + BE calendars
- [ ] NL + ES + DE calendars (in progress)
- [ ] Per-workspace holiday override
- [ ] Migration of existing manual holiday entries

## Next — v1.3 (Q3 2026)

**Name**: Multi-office workspaces
**Goal**: A workspace can have multiple offices with different timezones / holidays.

- Office model under Workspace
- User belongs to one office (was: one workspace)
- Holidays resolved by office
- Manager sees team across offices in their timezone

## Later — v1.4 and beyond

- Sub-national holidays (US states, Spanish autonomous communities).
- Half-day leaves.
- Google Calendar / Outlook export of approved leaves.
- Async approval (Slack notifications + approve from Slack).

## Recently shipped

- v1.1 (2026-03-30) — Leave types (paid / unpaid / sick / RTT).
- v1.0 (2026-02-14) — Public launch.

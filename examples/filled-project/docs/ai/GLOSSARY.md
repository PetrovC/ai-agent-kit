# Glossary

| Term | Definition |
|---|---|
| **Workspace** | Top-level tenant. One company / organization = one workspace. |
| **Member** | A user belonging to a workspace, with a role (Employee / Manager / HR Admin / Owner). |
| **Leave request** | A request to be off work between two dates, for a given leave type, in `Pending` / `Approved` / `Rejected` / `Cancelled` status. |
| **Consumed days** | Working days inside a leave request, excluding weekends and holidays. Computed in Domain. |
| **Balance** | Per-user, per-leave-type, per-year quota minus consumed days. Recomputed deterministically from approved leaves. |
| **RTT** | French-specific leave type (*"Réduction du Temps de Travail"*) accrued by working over 35h/week. Distinct from paid leave. |
| **Holiday calendar** | Set of national public holidays for a country, exposed via `IHolidayCalendar`. |
| **Calendar override** | Per-workspace toggle to disable a national holiday (e.g., a workspace not observing a regional bank holiday). |
| **Office** | Planned for v1.3. Sub-unit of a workspace with its own timezone and calendar. |
| **Manager** | A member with permission to approve leaves for a defined team. A team is currently a flat list configured in HR Admin. |
| **DoD** | Definition of Done — see the root instruction file's checklist before marking work complete. |

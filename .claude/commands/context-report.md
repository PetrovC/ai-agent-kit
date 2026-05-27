---
description: Print a per-surface token estimate for the current session context.
---

Estimate the token cost of each surface currently loaded in this session.

Steps:
1. Identify loaded surfaces: `CLAUDE.md`, any auto-loaded skill files referenced in recent turns, and recently-read files visible in the conversation history.
2. For each surface, run `wc -c <file>` and divide by 4 (Anthropic's chars-per-token approximation).
3. Compute each surface's percentage of a 200 000-token context window.

Report as a markdown table ordered by token cost descending:

```
| Surface | Size (chars) | Tokens (est.) | % of 200K window |
|---------|-------------|---------------|------------------|
| ...     | ...         | ...           | ...              |
| Total   | ...         | ...           | ...              |
```

Rules:
- Run entirely locally — no API calls.
- If a file path is not known, skip it (do not guess).
- Round token estimates to the nearest 100.
- Flag any single surface above 5% of the window as a compaction candidate.

---
description: Triage technical debt across categories (deps, deprecations, layer violations, coverage gaps, dead code). Read-only — does not fix anything.
---

Audit the codebase for technical debt. Use the `codebase-investigator` subagent to search broadly.

First read:
- `docs/ai/PROJECT.md` — product context and current milestone.
- `docs/ai/ARCHITECTURE.md` — expected layer structure.

── Categories to audit ──────────────────────────────────────────────────────

1. **Outdated dependencies**
   Run the appropriate audit tool and list packages > 1 major version behind, especially those with known CVEs:
   - npm/pnpm: `pnpm outdated && pnpm audit`
   - .NET: `dotnet list package --outdated && dotnet list package --vulnerable`
   - Go: `go list -m -u all && govulncheck ./...`
   - Python: `pip list --outdated && pip-audit`
   - Rust: `cargo outdated && cargo audit`

2. **Deprecated API calls**
   Check framework upgrade guides. Flag calls to deprecated APIs with a migration path.

3. **Layer violations**
   - Infrastructure code (DB queries, HTTP calls) inside Domain or Application.
   - Business logic inside HTTP controllers or GraphQL resolvers.
   - Circular imports between modules.

4. **Missing test coverage**
   Identify business logic with zero test coverage. Provide file path and function/class name — not a coverage percentage.

5. **Dead code**
   Unused exported functions, commented-out blocks > 10 lines, feature flags never cleaned up, TODOs/FIXMEs older than 90 days.

6. **Oversized units**
   Files > 500 lines or functions > 50 lines where the complexity is a genuine maintenance risk. Explain why it is a problem.

7. **Configuration and secrets hygiene**
   Hardcoded URLs, magic numbers without named constants, `.env.example` out of sync with `.env`.

── Output format ─────────────────────────────────────────────────────────────

For each item found:
- Category (from list above)
- File and location (line number if relevant)
- Why it is technical debt — the concrete risk, not "it looks messy"
- Effort: small (< 1 day) / medium (1–3 days) / large (> 3 days)
- Risk if left unfixed: low / medium / high

Sort the output: high risk + small effort items first. Group remaining items by category.

Do NOT fix anything. Output is the input for a planning session.

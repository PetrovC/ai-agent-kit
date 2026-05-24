---
description: Update one package end-to-end — changelog read, license check, test baseline, update, fix breakage, security audit.
argument-hint: <package-name> <old-version> <new-version>
---

Update $ARGUMENTS[0] from $ARGUMENTS[1] to $ARGUMENTS[2].

Use the `dependencies` skill.

── Pre-update ────────────────────────────────────────────────────────────────

1. Read the changelog / release notes between $ARGUMENTS[1] and $ARGUMENTS[2].
   Identify:
   - Breaking API changes.
   - Behaviour changes (same API, different runtime behaviour).
   - Deprecated patterns that should be migrated now.

2. Verify the license is still MIT (or equivalent permissive).
   If the license changed, stop and report — do not update.

3. Run the full test suite. Record the baseline result (X passed, Y failed).

── Update ────────────────────────────────────────────────────────────────────

4. Change the version in the manifest:
   - npm/pnpm: `package.json` → `pnpm install`
   - Go: `go get package@version` → `go mod tidy`
   - .NET: `dotnet add package Name --version X.Y.Z`
   - Python: `pyproject.toml` / `requirements.txt` → `uv sync` / `pip install`
   - Rust: `Cargo.toml` → `cargo update -p package`

5. Fix any compile errors or type errors introduced by the update.
   Do not suppress errors with casts or `any` — fix the root cause.

6. Adapt call sites to breaking API changes if needed.

── Post-update ───────────────────────────────────────────────────────────────

7. Run the full test suite. Compare to baseline.
   If tests regressed: investigate whether it is a real behaviour change or a test that was testing implementation details.

8. Run the security audit:
   - npm/pnpm: `pnpm audit`
   - Go: `govulncheck ./...`
   - .NET: `dotnet list package --vulnerable`
   - Python: `pip-audit`
   - Rust: `cargo audit`

── Report ────────────────────────────────────────────────────────────────────

Summarise:
- Package: name, old version → new version.
- Breaking changes encountered and how each was resolved.
- Test results: before vs after.
- License: confirmed MIT (or specify).
- Security audit: clean / vulnerabilities found and resolved.
- Any follow-up items (deprecated call sites not yet migrated, etc.).

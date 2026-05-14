---
name: security
description: >
  Use when a task involves authentication, authorization, input validation,
  secrets management, CORS, CSRF, rate limiting, logging sensitive data,
  dependency vulnerabilities, or any security-sensitive change.
---

# Security Skill

## Goal

Ensure that changes do not introduce vulnerabilities or weaken existing safeguards.
Security is not a feature to add later — it is a constraint applied to every change.

---

## Never do

- Hard-code secrets, tokens, API keys, or passwords anywhere in the codebase.
- Log sensitive data (passwords, tokens, PII, credit card numbers).
- Disable authentication or authorization for "convenience."
- Trust user-supplied input without validation.
- Use string concatenation to build SQL queries.
- Suppress or swallow security exceptions silently.
- Weaken CORS, CSRF, CSP, or rate limiting without explicit justification.
- Commit `.env` files, config files with real secrets, or any credential.
- Read `.env`, secret files, or credentials files unless explicitly approved.

---

## Input validation

Validate at the application boundary — controller, endpoint, command handler, or route handler.

**Rules (all stacks):**
- Validate length, format, range, and allowed values.
- Reject unknown or unexpected fields — do not bind blindly to domain objects.
- Return structured errors, not raw stack traces.

**Stack-specific patterns:**

| Stack | Approach |
|---|---|
| .NET / ASP.NET Core | FluentValidation or data annotations. Use `[FromBody]`, `[FromQuery]`, `[FromRoute]`. |
| Python / FastAPI | Pydantic models with `BaseModel`. |
| Python / Django | DRF serializers or `django.forms`. |
| Node / Express | `zod`, `joi`, or `class-validator`. |
| Node / NestJS | `class-validator` + `class-transformer` pipes. |
| Go | Manual validation or `go-playground/validator`. |
| Rust / Axum | `validator` crate or explicit guard functions. |

---

## Authentication and authorization

- Use framework-provided mechanisms — do not roll your own auth.
- Apply authorization at the application layer, not only at the API boundary.
- Never trust client-provided user IDs. Always resolve identity from the token or session.
- Use role-based or policy-based authorization. Avoid hand-rolled permission checks.

**Stack-specific patterns:**

| Stack | Approach |
|---|---|
| .NET | ASP.NET Core Identity, JWT, OAuth2. Apply `[Authorize]` at controller level, check in application layer too. |
| Python | FastAPI dependency injection (`Depends`), Django permissions / DRF `IsAuthenticated`. |
| Node | Passport.js, JWT middleware, NestJS Guards. |
| Go | Middleware functions checking JWT claims before handler execution. |
| Rust | Tower middleware or Axum extractors for JWT validation. |

---

## Secrets management

- Use environment variables, vault services, or a secrets provider — never source code.
- Never print secrets in logs, exceptions, or API responses.
- Configuration injection patterns by stack:

| Stack | Pattern |
|---|---|
| .NET | `IOptions<T>` / `IConfiguration`. Never read env vars directly in domain code. |
| Python | `os.environ` only in config module; inject via dependency. |
| Node | `process.env` only in config module; inject via constructor/DI. |
| Go | Config struct loaded from env once at startup; passed as dependency. |
| Rust | `std::env::var` only in main or config module; passed via state. |

Cloud providers: Azure Key Vault, AWS Secrets Manager, GCP Secret Manager, HashiCorp Vault.

---

## Dependencies

See the `dependencies` skill for the full rules. Security-specific points:

- Do not add a dependency with known critical CVEs.
- Run a vulnerability scan after adding or updating packages.
- MIT license only — no exceptions for security-sensitive packages (auth, crypto, parsing).
- Prefer mature, actively maintained, widely used packages.
- Audit transitive dependencies — a vulnerable transitive dep is still a vulnerability.

---

## Logging

- Log what happened, not what the user sent.
- Never log passwords, tokens, full request bodies with sensitive fields, or PII.
- Use structured logging.
- Log at the right level: Debug for dev traces, Information for business events, Warning for recoverable issues, Error for failures.

---

## Verification

```bash
# .NET
dotnet list package --vulnerable --include-transitive
dotnet test --filter "Security"

# Node / npm
npm audit
npx audit-ci --moderate

# Python
pip-audit

# Rust
cargo audit

# Go
govulncheck ./...
```

---

## Final response requirements

Always report:
- Security-relevant changes made.
- Any weakened or strengthened safeguard — with justification.
- Secrets, PII, or sensitive data handling changes.
- Dependency security status if packages were added or updated.

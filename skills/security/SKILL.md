---
name: security
description: >
  Use when a task involves authentication, authorization, input validation,
  secrets management, CORS, CSRF, XSS, SQL/NoSQL injection, rate limiting,
  logging sensitive data, dependency vulnerabilities, or any security-sensitive change.
---

# Security Skill

## Goal

Ensure that changes do not introduce vulnerabilities or weaken existing safeguards.
Security is not a feature to add later — it is a constraint applied to every change.

---

## Never do

- Hard-code secrets, tokens, API keys, or passwords anywhere in the codebase.
- Log sensitive data (passwords, tokens, PII, credit card numbers, full request bodies).
- Disable authentication or authorization for "convenience."
- Trust user-supplied input without validation or sanitization.
- Use string concatenation to build SQL or NoSQL queries.
- Suppress or swallow security exceptions silently.
- Weaken CORS, CSRF, CSP, or rate limiting without explicit justification.
- Commit `.env` files, config files with real secrets, or any credential.
- Read `.env`, secret files, or credentials files unless explicitly approved.
- Skip signature verification on JWTs or OAuth tokens.

---

## OWASP Top 10 quick reference

| Risk | Key countermeasure |
|---|---|
| A01 Broken Access Control | Check authorization on **every** sensitive operation, not just at the endpoint boundary |
| A02 Cryptographic Failures | TLS everywhere; encrypt PII at rest; no MD5/SHA1 for passwords — use bcrypt/argon2 |
| A03 Injection | Parameterized queries always; validate/escape all external inputs |
| A04 Insecure Design | Threat-model new features; rate-limit; deny by default |
| A05 Security Misconfiguration | Remove debug endpoints; strict CORS; no default credentials; CSP headers |
| A06 Vulnerable Components | Audit deps (`npm audit`, `dotnet list --vulnerable`, etc.); MIT-only |
| A07 Auth Failures | MFA where possible; strong session management; account lockout |
| A08 Integrity Failures | Verify package integrity (lockfiles, SRI); sign build artifacts |
| A09 Logging Failures | Log security events; never log secrets; structured logs; alert on anomalies |
| A10 SSRF | Allowlist outbound URLs; block private IP ranges; use dedicated egress proxy |

---

## Input validation

Validate at the application boundary — controller, endpoint, command handler, or route handler.
**Never** bind raw request data directly to domain objects.

**Rules (all stacks):**
- Validate length, format, range, and allowed values.
- Reject unexpected/extra fields (allowlist, not blocklist).
- Return structured errors; never raw stack traces.
- Re-validate on the server even if the client validated first.

**Stack-specific patterns:**

| Stack | Approach |
|---|---|
| .NET / ASP.NET Core | FluentValidation or data annotations. `[FromBody]`, `[FromQuery]`, `[FromRoute]`. |
| Python / FastAPI | Pydantic `BaseModel` with field validators. |
| Python / Django | DRF serializers or `django.forms`. |
| Node / Express | `zod`, `joi`, or `class-validator`. |
| Node / NestJS | `class-validator` + `class-transformer` pipes. |
| Go | Manual validation or `go-playground/validator`. |
| Rust / Axum | `validator` crate or explicit guard functions. |

---

## Injection (SQL, NoSQL, OS commands)

Never build queries with string concatenation.

```python
# Bad
cursor.execute(f"SELECT * FROM users WHERE email = '{email}'")

# Good — parameterized
cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
```

```typescript
// Bad
db.query(`SELECT * FROM users WHERE id = ${userId}`);

// Good — parameterized
db.query("SELECT * FROM users WHERE id = $1", [userId]);
```

**Per-stack query safety:**

| Stack | Safe approach |
|---|---|
| .NET EF Core | LINQ queries and `FromSqlInterpolated` (interpolated = safe). Avoid `FromSqlRaw` with user input. |
| Python SQLAlchemy | ORM or `text("...").bindparams(...)`. |
| Node pg / mysql2 | Prepared statements with `$1` / `?` placeholders. |
| Go `database/sql` | `db.QueryContext(ctx, "...", arg1, arg2)` — positional params. |
| MongoDB | Use typed query builders; never pass raw user strings into `$where` or `$regex`. |
| OS commands | Use subprocess arrays, never shell=True / string interpolation. |

---

## XSS (Cross-Site Scripting)

- **Never** insert unescaped user data into HTML, JS, CSS, or URLs.
- React / Vue / Angular escape by default — the risk is explicit bypasses (`dangerouslySetInnerHTML`, `v-html`, `[innerHTML]`).
- When you must render HTML from user input: sanitize with **DOMPurify** (MIT) before injection.
- Set a **Content Security Policy** (CSP) header — `script-src 'self'` blocks injected scripts.
- Use `HttpOnly` cookies to prevent token theft via XSS.

```typescript
// Bad
element.innerHTML = userInput;

// Good
import DOMPurify from "dompurify";
element.innerHTML = DOMPurify.sanitize(userInput);
```

**CSP header (minimal baseline):**
```
Content-Security-Policy: default-src 'self'; script-src 'self'; object-src 'none'; base-uri 'self'
```

---

## CSRF (Cross-Site Request Forgery)

- Set `SameSite=Strict` (or `Lax`) on session cookies — this alone stops most CSRF.
- For APIs using JWTs in `Authorization` headers: CSRF is not a risk (browsers don't auto-send custom headers cross-origin).
- For cookie-based session APIs: use a CSRF token (double-submit cookie or synchronizer token pattern).
- Frameworks with built-in CSRF: Django (`CsrfViewMiddleware`), Rails (default), ASP.NET Core (`[ValidateAntiForgeryToken]`).

```http
Set-Cookie: session=...; HttpOnly; Secure; SameSite=Strict
```

---

## Authentication

- Use framework-provided mechanisms — do not roll your own auth.
- **JWT specifics:**
  - Always verify the signature. Never accept `alg: none`.
  - Use asymmetric keys (RS256/ES256) for tokens consumed by multiple services.
  - Keep expiry short (15 min–1 h for access tokens). Use refresh tokens.
  - Do not store sensitive data in claims (claims are base64-decoded by anyone).
  - Store tokens in `HttpOnly` cookies or memory — not `localStorage` (XSS risk).
- **Passwords:** bcrypt (cost ≥ 12) or Argon2id. Never MD5 or SHA-1.
- **Session fixation:** Rotate the session ID on login.
- **Account enumeration:** Return the same error for "wrong email" and "wrong password."

---

## Authorization

- Apply authorization at the **application layer** (use case / service), not only at the API boundary.
- Never trust client-provided user IDs — always resolve identity from the token/session.
- Fail closed: deny by default, grant explicitly.
- Re-check ownership when fetching records: `WHERE id = ? AND owner_id = ?`.
- Audit log sensitive operations (admin actions, data exports, permission changes).

```typescript
// Bad — authorization only at HTTP layer
router.get("/admin/users", requireAdmin, getUsers);
async function getUsers() { return db.query("SELECT * FROM users"); }

// Good — authorization also enforced in the service
async function getUsers(caller: User) {
  if (!caller.roles.includes("admin")) throw new ForbiddenError();
  return db.query("SELECT * FROM users");
}
```

---

## Secrets management

Never read `process.env.SECRET` scattered through business logic — load once in a config module.

| Stack | Pattern |
|---|---|
| .NET | `IOptions<T>` / `IConfiguration`. Azure Key Vault via `AddAzureKeyVault`. |
| Python | `os.environ` only in `config.py`; inject via dependency. |
| Node | Config module + `zod` validation at startup; inject via DI. |
| Go | Config struct loaded from env at startup; passed as a dependency. |
| Rust | `std::env::var` in `main` or config module; passed via application state. |

Cloud secret stores: **Azure Key Vault**, **AWS Secrets Manager**, **GCP Secret Manager**, **HashiCorp Vault**.

Rotate secrets that have been committed immediately — assume they are compromised.

---

## CORS

```
Access-Control-Allow-Origin: https://your-domain.com
```

- Never `*` for authenticated APIs.
- Allowlist specific origins — do not reflect `Origin` header back without validation.
- `Access-Control-Allow-Credentials: true` requires an explicit, non-wildcard origin.

---

## Rate limiting

- Limit per authenticated user (not just per IP — attackers control IPs).
- Apply tighter limits on sensitive endpoints: login, password reset, OTP, API key generation.
- Return `429 Too Many Requests` with a `Retry-After` header.
- Fail open on limiter errors (don't block all traffic if Redis is down) but alert.

---

## SSRF (Server-Side Request Forgery)

When your service makes outbound HTTP requests based on user-controlled URLs:
- **Allowlist** the permitted domains/IPs. Block everything else.
- Block private IP ranges: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `127.0.0.1`, `169.254.0.0/16`.
- Resolve the hostname and check the resulting IP — DNS rebinding attacks bypass hostname checks.
- Use a dedicated egress proxy for all outbound traffic.

---

## Dependencies

See the `dependencies` skill for full rules. Security-specific:

- Do not add a package with known critical CVEs.
- Run a vulnerability scan after any add/update.
- MIT license only — no exceptions for auth/crypto/parsing packages.
- Audit transitive dependencies — a vulnerable transitive dep is still your vulnerability.

---

## Logging

- Log what happened, not what the user sent.
- Never log passwords, tokens, full request bodies with sensitive fields, or PII.
- Use structured logging (JSON).
- Log security events: auth failures, permission denials, admin actions, data exports.
- Log at the right level. Error only for unrecoverable failures.

---

## Verification

```bash
# .NET
dotnet list package --vulnerable --include-transitive
dotnet test --filter "Security"

# Node / pnpm
pnpm audit --audit-level=high
npx audit-ci --high

# Python
pip-audit
bandit -r src/      # static analysis for common Python security issues

# Rust
cargo audit

# Go
govulncheck ./...

# General — check for hardcoded secrets
git log --all --full-diff -p | grep -iE "(password|secret|token|api_key)\s*="
```

---

## Final response requirements

Always report:
- Security-relevant changes made (auth, validation, sanitization, secrets).
- Any weakened or strengthened safeguard — with justification.
- Secrets, PII, or sensitive data handling changes.
- Dependency security status if packages were added or updated.
- Authorization coverage: which layer(s) enforce access control.
- Known limitations or risks in the current implementation.

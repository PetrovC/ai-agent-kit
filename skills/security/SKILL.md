---
name: security
description: >
  Use when a task involves authentication, authorization, input validation,
  secrets management, CORS, CSRF, XSS, SQL/NoSQL injection, rate limiting,
  logging sensitive data, dependency vulnerabilities, or any security-sensitive change.
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(pip-audit:*)"
  - "Bash(cargo:*)"
  - "Bash(gitleaks:*)"
  - "Bash(trivy:*)"
  - "Bash(dotnet:*)"
version: "1.0.0"
---

# Security Skill

## Goal
Ensure that changes do not introduce vulnerabilities or weaken existing safeguards.
Security is not a feature to add later — it is a constraint applied to every change.

## Quick reference

| Threat | Mitigation |
|---|---|
| Injection | Use parameterized queries (SQL) / ORMs, never concatenate strings |
| XSS / CSRF | Escape user inputs, set HttpOnly cookies, validate CSRF/Anti-forgery tokens |
| Auth & Authz | Enforce authentication checks, apply role/permission-based access control |
| CORS & SSRF | Limit allowed origins, validate destination URLs, block internal networks |
| Sensitive Data | Hash passwords (argon2/bcrypt), encrypt at rest/transit, redact log secrets |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

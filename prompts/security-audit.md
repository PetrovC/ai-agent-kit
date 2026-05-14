# Prompt: Security Audit

```
Perform a security audit of the current change or the specified files.

Use the security skill (skills/security/SKILL.md).
Use the security-reviewer subagent if the change is large.

Check for:
1. Hard-coded secrets, tokens, or credentials.
2. Sensitive data in logs or error responses.
3. Missing or incorrect input validation.
4. SQL injection or query injection risks.
5. Missing or incorrectly placed authorization checks.
6. Weakened CORS, CSRF, CSP, or rate limiting.
7. Vulnerable dependencies.

Run the relevant vulnerability check for the stack:
  dotnet list package --vulnerable --include-transitive   (.NET)
  npm audit                                               (Node / Vue / Angular / React)
  pip-audit                                               (Python)
  cargo audit                                             (Rust)
  govulncheck ./...                                       (Go)

Output format:
### Critical
### High
### Medium
### Informational

Each finding: file + line + vulnerability type + concrete risk + recommended fix.
Do not flag theoretical risks without evidence in the code.
```

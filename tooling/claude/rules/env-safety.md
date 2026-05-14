---
paths:
  - "**/.env*"
  - "**/config/**"
  - "**/appsettings*.json"
  - "**/application*.yml"
  - "**/application*.yaml"
---
# Environment and secret rules

Never hardcode secrets, API keys, tokens, passwords, or connection strings in source code.

Rules:
- Secrets belong in environment variables or a secrets manager (Vault, AWS SM, Azure KV).
- Every secret used in code must have a corresponding entry in `.env.example` (with a fake value).
- `.env` and `.env.*` must be in `.gitignore` — verify before committing.
- `appsettings.json` must never contain production values — use `appsettings.Production.json` (gitignored).
- Never log secrets — redact them in log formatters.
- Rotate any secret that was accidentally committed, even briefly.
- Connection strings: use environment variable references, not literals.

---
paths:
  - "**/.github/**"
  - "**/.gitignore"
  - "**/.gitattributes"
---
# Commit and branch rules

Commit message format: `<type>(<scope>): <subject>` (Conventional Commits).

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `ci`.

Rules:
- Subject line ≤ 72 chars, imperative mood ("add" not "added").
- Breaking changes: append `!` after type and add `BREAKING CHANGE:` footer.
- Never commit: `.env`, `*.local.json`, secrets, compiled binaries, `node_modules/`.
- Never push directly to `main`, `master`, or `dev` — always via PR.
- One concern per commit. If a commit needs "and" in its message, split it.

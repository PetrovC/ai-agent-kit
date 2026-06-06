---
name: api-design
description: >
  Use when designing or modifying HTTP APIs (REST), OpenAPI specs,
  error contracts, pagination, versioning, idempotency,
  or any externally consumed REST/HTTP API surface.
  For GraphQL implementation, use the graphql skill instead.
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(npx:*)"
  - "Bash(pnpm:*)"
version: "1.0.0"
---

# API Design Skill

## Goal
APIs that are predictable, evolvable, and hard to misuse. A consumer should
be able to read the spec and write a correct client without asking a single
question.

## Quick reference

| Concept | Best practice |
|---|---|
| Verbs | GET (read), POST (create), PUT (replace), PATCH (update), DELETE (remove) |
| Status Codes | 200 OK, 201 Created, 400 Bad Request, 401 Unauth, 403 Forbidden, 404 Not Found |
| Errors | Use RFC 7807 Problem Details format for error payloads |
| Resilience | Implement pagination (cursor-based), rate limiting, and idempotency keys |
| OpenAPI | Maintain up-to-date OpenAPI/Swagger specifications for API clients |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

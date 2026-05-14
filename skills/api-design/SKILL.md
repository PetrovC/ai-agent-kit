---
name: api-design
description: >
  Use when designing or modifying HTTP APIs (REST), OpenAPI specs,
  GraphQL schemas, error contracts, pagination, versioning, idempotency,
  or any externally consumed API surface.
---

# API Design Skill

## Goal

APIs that are predictable, evolvable, and hard to misuse. A consumer should
be able to read the spec and write a correct client without asking a single
question.

---

## Universal rules

- **Specify first.** OpenAPI / GraphQL SDL is the contract. Code follows the spec, not the other way around.
- **Consumer-driven naming.** Names reflect the domain, not the implementation.
- **Stable URLs / queries.** Renaming is a breaking change. Plan for evolution.
- **Errors are part of the contract.** Document them as carefully as success cases.
- **Idempotency for mutations** that can be retried (network failures will retry them whether you like it or not).

---

## REST

### Resources and verbs

- Nouns for resources: `/users`, `/orders`, `/orders/{id}/items`.
- HTTP verbs:
  - `GET` — read, safe, cacheable, idempotent.
  - `POST` — create, or non-idempotent action.
  - `PUT` — replace, idempotent.
  - `PATCH` — partial update (use JSON Patch or merge semantics — document which).
  - `DELETE` — remove, idempotent.
- Collections: `GET /users` returns a list. `GET /users/{id}` returns one. Never overload.

### Status codes (use the right one)

| Code | Meaning |
|---|---|
| 200 OK | Success with body |
| 201 Created | Resource created; include `Location` header |
| 202 Accepted | Async processing started; include status URL |
| 204 No Content | Success with no body (DELETE, idempotent PUT) |
| 400 Bad Request | Client sent invalid input |
| 401 Unauthorized | No credentials, or invalid credentials |
| 403 Forbidden | Authenticated but not allowed |
| 404 Not Found | Resource does not exist |
| 409 Conflict | State conflict (concurrent edit, duplicate key) |
| 422 Unprocessable Entity | Validation failed (some teams prefer 400) — pick one and document |
| 429 Too Many Requests | Rate limited; include `Retry-After` |
| 5xx | Server error; don't leak stack traces |

### Error format (problem details)

Use RFC 7807:

```json
{
  "type": "https://example.com/errors/insufficient-funds",
  "title": "Insufficient funds",
  "status": 422,
  "detail": "Your balance is 5.00 EUR; the transfer requires 10.00 EUR.",
  "instance": "/transfers/abc-123",
  "errors": [
    { "field": "amount", "code": "out_of_range", "message": "must be <= balance" }
  ]
}
```

- `type` is a stable URI a client can switch on.
- Never leak internal errors. "Database connection failed" → 500 with a generic message + log the detail server-side with a correlation ID.

### Pagination

Two acceptable styles — pick one per API:

- **Cursor-based** (preferred for large or mutating datasets):
  ```
  GET /events?limit=50&cursor=eyJpZCI6IjEyMyJ9
  → { "data": [...], "next_cursor": "eyJpZCI6IjE3MyJ9" }
  ```
- **Offset-based** (acceptable for small, stable datasets):
  ```
  GET /users?page=2&page_size=20
  → { "data": [...], "page": 2, "total_pages": 47, "total_count": 928 }
  ```

Never expose offset on big tables — performance cliff and skipped/duplicated results during mutation.

### Filtering, sorting, sparse fields

- Filter: `?status=active&created_after=2024-01-01`.
- Sort: `?sort=-created_at,name` (`-` for desc).
- Sparse: `?fields=id,name,email` (return only those).
- Document every supported param. Reject unknown params (`400`), don't silently ignore.

### Versioning

- URL-prefixed: `/v1/users`. Simple, visible, easy to route.
- Header-based: `Accept: application/vnd.myapi.v2+json`. More flexible but harder to debug.
- Pick one. Add a new version only for breaking changes. Document deprecation dates.

### Idempotency

- For non-GET requests that can be retried, support `Idempotency-Key` header. Server stores the key → response mapping for some TTL.
- All `PUT`, `DELETE`, `PATCH` should be inherently idempotent. `POST` needs the key.

### Rate limiting

- Return `429 Too Many Requests` with `Retry-After` header (seconds or HTTP-date).
- Include current limit info in response headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`.

---

## OpenAPI

- **Single source of truth.** Server code, client SDKs, docs all generated from it.
- Version the spec file alongside the code. Review changes in PRs.
- Use `$ref` for shared schemas (errors, pagination). Don't duplicate.
- Document every status code, every error type, every header.
- Tooling: `redocly lint`, `spectral` for rule-based linting.
- Generate clients with `openapi-generator` or `orval` (TS) — don't hand-write SDKs.

```yaml
openapi: 3.1.0
info:
  title: My API
  version: 1.2.0
paths:
  /users/{id}:
    get:
      summary: Get a user by id
      parameters:
        - { name: id, in: path, required: true, schema: { type: string, format: uuid } }
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema: { $ref: '#/components/schemas/User' }
        '404': { $ref: '#/components/responses/NotFound' }
```

---

## GraphQL

### Schema design

- **Nullability is a contract.** Mark fields `!` only if they will ALWAYS resolve. Otherwise leave nullable — and handle the null in the client.
- Avoid deeply nested mandatory fields — one resolver failure cascades.
- Use **enum** types for closed sets of values. Don't use `String` for status.
- Pagination: follow the **Relay connection spec** (`edges { node, cursor }`, `pageInfo`).
- Mutations return a payload type with both the mutated object AND a `userErrors: [UserError!]!` field for domain errors:

```graphql
type CreateOrderPayload {
  order: Order
  userErrors: [UserError!]!
}

type UserError {
  field: [String!]!
  message: String!
  code: String!
}
```

### Performance pitfalls

- **N+1**: solve with `dataloader` (Node) / `graphql-batch` / per-resolver batching. Mandatory for any non-trivial schema.
- **Query depth**: enforce a max depth (`graphql-depth-limit`). 5-7 is usually enough.
- **Query cost**: assign a cost per field; reject queries above a threshold.
- **Persisted queries** for production clients: clients send a hash, server resolves to the actual query. Smaller payloads, fewer DoS vectors.

### Schema evolution

- Adding fields = safe.
- Removing fields = breaking. Use `@deprecated(reason: "...")` first, remove after a deprecation window.
- Renaming fields = always breaking. Add new, deprecate old.

---

## Security cross-cutting

- **Authentication** at the edge. The API itself trusts a signed token (JWT, session).
- **Authorization** per resource. Don't rely solely on edge filtering — check ownership in handlers.
- **Input validation** at the boundary. Length limits, enum constraints, regex for free-form text.
- **Output filtering**: never return fields the caller can't see (passwords, internal flags). Define DTOs explicitly.
- **CORS**: allowlist origins, don't `*` with credentials.
- **TLS only**. Redirect HTTP → HTTPS. HSTS header.
- **Rate limiting** on auth endpoints especially.
- See `security` skill for the full checklist.

---

## What NOT to do

- No verbs in REST URLs: `/createUser` is wrong; `POST /users` is right.
- No mixing pagination styles in the same API.
- No 200 OK with `{"error": "..."}` in the body — use the right status code.
- No undocumented fields in responses — clients will start depending on them.
- No breaking changes without a version bump and deprecation period.
- No leaking internal error details (stack traces, SQL errors) to clients.
- No "magic" GraphQL queries — every field a client uses must be in the schema.

---

## Verification commands

```bash
# OpenAPI
redocly lint openapi.yaml
spectral lint openapi.yaml

# GraphQL
graphql-inspector validate schema.graphql ./queries
graphql-schema-linter schema.graphql

# Generic API contract tests
schemathesis run http://localhost:3000/openapi.json    # property-based fuzzing
```

---

## Final response requirements

Always report:
- Endpoints / queries / mutations added or changed.
- Breaking vs non-breaking classification.
- Schema / OpenAPI file updates.
- Error types added (with `type` URIs or GraphQL error codes).
- Tests added (contract tests, schema linting).
- Deprecation plan if anything was removed or renamed.

---
name: node
description: >
  Use when modifying Node.js backend code: Express, NestJS, Fastify,
  Hono, server-side TypeScript, Vitest/Jest tests, package management
  (pnpm/npm), or any Node service structure.
---

# Node.js (Backend) Skill

## Goal

Strict-typed, layered, testable Node services. No `any`, no callback soup,
no magic strings. A junior should be able to trace a request end-to-end.

---

## Project structure

```
src/
  domain/           # pure logic, no I/O, no framework
  application/      # use cases, ports (interfaces)
  infrastructure/   # DB, HTTP clients, queues, file system
  interfaces/       # HTTP routes (Express/NestJS/Fastify), workers, CLI
tests/
  unit/
  integration/
```

Rules:
- Domain has no `import` from `express`, `@nestjs/*`, `fastify`, or any infra.
- Application defines `interface ...Repository` / `interface ...Service`; Infrastructure implements them.
- Interfaces (HTTP layer) call application use cases — never put business logic in controllers.

---

## TypeScript config (mandatory)

```jsonc
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "noImplicitOverride": true,
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext"
  }
}
```

- No `any`. Use `unknown` and narrow.
- No `as` casts unless the type cannot be inferred — and add a comment why.
- Use `zod` (or `valibot`) for runtime validation at HTTP / queue / config boundaries.
- Prefer `type` over `interface` for closed shapes; `interface` for extensible contracts.

---

## Package management

- **pnpm preferred** (disk-efficient, strict). `npm` is fine; `yarn classic` is end-of-life.
- Lockfile committed. CI runs `pnpm install --frozen-lockfile`.
- No global installs in scripts. Use `npx` or `pnpm dlx`.
- Engine pinned in `package.json`: `"engines": { "node": ">=20.0.0" }`.

---

## NestJS

- One module per bounded context. Don't dump everything into `AppModule`.
- DI via constructor injection. Don't use `@Inject('TOKEN')` unless you actually have a token.
- Use `@Module({ imports, controllers, providers, exports })` explicitly.
- DTOs with `class-validator` + `class-transformer`, OR switch to `zod` + `nestjs-zod`.
- Guards for authz. Interceptors for cross-cutting (logging, transform). Pipes for validation.
- Tests via `Test.createTestingModule({...})` — override real providers with fakes/mocks.

---

## Express

- Use a typed router. Group by feature, not by HTTP verb.
- Middleware order matters: helmet → cors → body parsing → logging → auth → routes → error handler.
- Centralised error handler (4-arg function) at the end. Never `try/catch` in every route.
- Async routes: wrap with `express-async-errors` or `(req, res, next) => fn().catch(next)`.
- Don't mutate `req` to attach untyped data — extend `Request` with module augmentation.

---

## Fastify

- Use plugins (`fastify.register(...)`). One plugin per concern.
- Schema-first: declare JSON Schema on every route → free validation + serialization speedup.
- Use `@fastify/sensible` for HTTP errors, `@fastify/jwt`, `@fastify/cors` etc. — official plugins only.
- Avoid `done()` callbacks — return promises.

---

## Configuration

- Read env vars **once** at startup via a `zod`-validated `Config` object.
- Fail fast if a required var is missing. Don't read `process.env.X` deep in code.
- Use `dotenv-flow` or platform-native env injection — never commit `.env`.

---

## Logging

- `pino` (structured JSON, fast). Avoid `console.log` outside scripts.
- Log request IDs / correlation IDs. Use `pino-http` or NestJS interceptor.
- Never log secrets, tokens, full request bodies with sensitive fields, or PII.

---

## Testing

- **Vitest** preferred (fast, ESM-native, TS-aware). Jest is OK if already present.
- AAA pattern. Behavior-focused, not mock-call counting.
- Test files: `*.spec.ts` colocated with source, OR mirrored under `tests/`. Pick one and stick.
- Integration tests: real Postgres via `testcontainers`, not SQLite, not in-memory.
- HTTP: use `supertest` (Express) or `app.inject()` (Fastify) or `Test.createTestingModule` (Nest).
- Avoid `jest.mock()` of internal modules. Inject a fake instead.

```ts
import { describe, it, expect, vi } from 'vitest';

describe('CreateOrder', () => {
  it('rejects when stock is empty', async () => {
    const repo = { findStock: vi.fn().mockResolvedValue(0) };
    const usecase = new CreateOrder(repo);
    await expect(usecase.run({ sku: 'X' })).rejects.toThrow(OutOfStock);
  });
});
```

---

## What NOT to do

- No `require()` in TS code — use `import`.
- No `// @ts-ignore` — fix the type or use `// @ts-expect-error` with explanation.
- No `JSON.parse(JSON.stringify(x))` to "clone" — use `structuredClone`.
- No bare `new Date()` for "now" inside domain — inject a clock for testability.
- No `process.exit()` outside the entry point.
- No `Buffer.from(x)` without specifying encoding when `x` is a string.

---

## Verification commands

```bash
pnpm install --frozen-lockfile
pnpm tsc --noEmit
pnpm lint           # eslint
pnpm format         # prettier --check
pnpm test           # vitest run
pnpm test --coverage
```

---

## Final response requirements

Always report:
- Layer of each changed file.
- Tests added or updated.
- TypeScript / lint / test results.
- Any new dependency: name, version, **license (MIT only — see `dependencies` skill)**.

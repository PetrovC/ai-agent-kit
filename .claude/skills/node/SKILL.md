---
name: node
description: >
  Use when modifying Node.js, Bun, or Deno backend code: Express, NestJS,
  Fastify, Hono, Elysia, server-side TypeScript, Vitest/Jest tests, package
  management (pnpm/npm/bun), or any JS/TS service structure.
paths:
  - "**/package.json"
  - "**/*.js"
  - "**/*.mjs"
  - "**/*.cjs"
  - "**/tsconfig*.json"
  - "**/bun.lockb"
  - "**/bunfig.toml"
  - "**/deno.json"
  - "**/deno.jsonc"
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(pnpm:*)"
  - "Bash(yarn:*)"
  - "Bash(node:*)"
  - "Bash(npx:*)"
  - "Bash(bun:*)"
  - "Bash(deno:*)"
version: "1.0.0"
---

# Node.js (Backend) Skill

## Goal
Strict-typed, layered, testable Node services. No `any`, no callback soup,
no magic strings. A junior should be able to trace a request end-to-end.

## Quick reference

| Concept | Best practice |
|---|---|
| TypeScript | Use strict mode, ESM imports (`"type": "module"`), correct path aliases |
| Frameworks | Fastify or NestJS with ChangeDetectionStrategy / proper DI |
| Performance | Do not block the event loop, use worker threads for CPU-heavy tasks |
| Key commands | `npm run dev`, `npm run build`, `npm test`, `npx tsc --noEmit` |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

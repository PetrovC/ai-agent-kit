---
name: testing
description: >
  Use when adding, modifying, fixing, or reviewing tests, test strategy,
  CI validation, regression coverage, test naming, or test infrastructure.
  Covers all backend languages (.NET, Python, Node, Go, Rust, Java) and
  frontend stacks (Vue, Angular, React). Includes characterization tests as the
  safety net for legacy / brownfield modernization.
keywords:
  - characterization
  - legacy
  - brownfield
  - modernize
  - modernization
  - strangler
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(pnpm:*)"
  - "Bash(pytest:*)"
  - "Bash(go:*)"
  - "Bash(cargo:*)"
  - "Bash(dotnet:*)"
  - "Bash(mvn:*)"
  - "Bash(./gradlew:*)"
version: "1.0.0"
---

# Testing Skill

## Goal
Ensure that changed behavior is verified by meaningful, maintainable tests.

A test suite that nobody trusts is worse than no test suite. Write tests that
fail when the behavior breaks, and pass when it works — nothing more.

## Quick reference

| Pattern | When to use |
|---|---|
| Unit test | Domain rules, pure logic, fast feedback |
| Integration test | DB, external APIs, DI container boundaries |
| E2E test | Critical user flows only — keep few, keep stable |
| `--watch` mode | TDD inner loop |
| `--coverage` | Before merging new features |

Key commands:
- `dotnet test` / `pytest -x` / `go test ./...` / `npm test`
- `npx vitest run --coverage` — frontend coverage

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

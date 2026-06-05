---
name: angular
description: >
  Use when modifying Angular frontend code: components, services, routing,
  signals, RxJS, HTTP client, forms, pipes, or Angular project structure.
  Covers Angular 17+ standalone components, new control flow syntax,
  signal-based APIs (input/output/model), deferrable views, and functional interceptors.
paths:
  - "**/angular.json"
  - "**/*.component.ts"
  - "**/*.component.html"
  - "**/*.component.scss"
  - "**/*.module.ts"
  - "**/*.service.ts"
  - "**/*.spec.ts"
allowed-tools:
  - "Bash(ng:*)"
  - "Bash(npm:*)"
  - "Bash(npx:*)"
  - "Bash(pnpm:*)"
version: "1.0.0"
keywords:
  - angular
  - typescript
  - component
  - ng
  - ngrx
  - angular material
task_intents:
  - implement
  - review
  - fix
  - refactor
delegation_hints:
  can_delegate: true
  when: >
    When the task also involves backend (.NET, Node, etc.) — delegate frontend
    to a focused subagent.
---

# Angular Skill

## Goal
Produce clean, maintainable Angular code. Components should be small and focused.
Business logic belongs in services, not in templates or component classes.
Default to Angular 17+ patterns: standalone components, signals, new control flow syntax.

## Quick reference

| Concept | Best practice |
|---|---|
| Architecture | Feature folders, separate business logic into services, 1 component/file |
| Standalone | Use standalone components (Angular 14+, default in 17+) |
| Signals | Use `signal`, `computed`, `effect`, `input()`, `output()`, and `model()` |
| Templates | Use `@if`, `@for`, `@switch` control flow syntax (Angular 17+) |
| Performance | Use `ChangeDetectionStrategy.OnPush` and trackBy functions |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

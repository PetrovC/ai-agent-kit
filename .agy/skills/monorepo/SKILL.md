---
name: monorepo
description: >
  Use when working in a monorepo: Nx, Turborepo, pnpm / npm / yarn workspaces,
  Cargo workspaces, Go workspaces, Lerna, Bazel. Covers project structure,
  affected detection, build caching, dependency boundaries, CI matrix.
paths:
  - "**/nx.json"
  - "**/turbo.json"
  - "**/pnpm-workspace.yaml"
  - "**/lerna.json"
  - "**/.bazelrc"
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(pnpm:*)"
  - "Bash(npx:*)"
version: "1.0.0"
---

# Monorepo Skill

## Goal
A single repo with many packages that stays fast, builds only what changed,
and enforces dependency boundaries. The goal is the speed and atomic-change
benefits of a monorepo without it turning into a tangled big-ball-of-mud.

## Quick reference

| Concept | Best practice |
|---|---|
| Tooling | Use pnpm workspaces, Nx, Turborepo, or Go/Cargo workspaces |
| Boundaries | Enforce dependency rules between libraries/apps; restrict deep imports |
| Cache | Configure remote/local task caching for build, lint, and test tasks |
| CI | Use affected detection (e.g. `nx affected`) to run only changed tasks |
| Versioning | Keep shared dependencies unified at root; version packages independently |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

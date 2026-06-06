---
name: react
description: >
  Use when modifying React components, hooks, Next.js (app router or
  pages), Remix routes, state management, React Testing Library, or
  any React-based frontend project.
paths:
  - "**/*.jsx"
  - "**/*.tsx"
  - "**/next.config.*"
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(pnpm:*)"
  - "Bash(npx:*)"
version: "1.0.0"
---

# React Skill

## Goal
Predictable, declarative React. Components describe what the UI should look
like for given props/state, never side effects in render. State lives at the
right level — not too high (re-render storm), not too low (prop drilling).

## Quick reference

| Concept | Best practice |
|---|---|
| Hooks | Follow Rules of Hooks, keep dependency arrays correct, avoid custom state sync |
| State | Keep state local if possible; lift up or use Context/Redux/Zustand when shared |
| Performance | Use `useMemo`, `useCallback`, `React.memo` only when profiling justifies it |
| TS | Declare strict types for props, states, and event handlers |
| Key commands | `npm run dev`, `npm run build`, `npm run test` |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

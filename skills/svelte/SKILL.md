---
name: svelte
description: >
  Use when working with Svelte components, SvelteKit routes, stores,
  transitions/animations, form actions, server-side rendering, or
  any Svelte/SvelteKit project structure.
paths:
  - "**/*.svelte"
  - "**/svelte.config.*"
  - "**/vite.config.*"
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(pnpm:*)"
  - "Bash(npx:*)"
  - "Bash(vite:*)"
version: "1.0.0"
---

# Svelte Skill

## Goal
Produce simple, reactive Svelte/SvelteKit code that leverages the compiler's
advantages: minimal boilerplate, co-located state, and zero-runtime overhead
for reactivity. Default to SvelteKit for any multi-page or SSR/SSG project.

## Quick reference

| Concept | Best practice |
|---|---|
| State | Use `$state`, `$derived`, `$effect` runes (Svelte 5) or `let` and `$` (Svelte 4) |
| Stores | Prefix store references with `$` for auto-subscription |
| SvelteKit | Use Load functions (`+page.ts` / `+page.server.ts`) and Form Actions |
| Styling | Keep styles scoped inside `<style>` blocks; use CSS variables for global |
| Key commands | `npm run dev`, `npm run build`, `npx svelte-check --tsconfig ./tsconfig.json` |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

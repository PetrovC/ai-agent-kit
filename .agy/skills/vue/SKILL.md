---
name: vue
description: >
  Use when modifying Vue 3 frontend code: components, composables, Pinia stores,
  Vue Router, script setup, TypeScript, reactivity, error handling, or
  performance patterns. Covers Vue 3.4+ including defineModel, composable patterns,
  and Nuxt 3 SSR considerations.
paths:
  - "**/*.vue"
  - "**/vite.config.*"
  - "**/vitest.config.*"
  - "**/nuxt.config.*"
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(pnpm:*)"
  - "Bash(npx vitest:*)"
  - "Bash(vite:*)"
  - "Bash(vue-tsc:*)"
  - "Bash(nuxt:*)"
version: "1.0.0"
---

# Vue Skill

## Goal
Produce clean, maintainable Vue 3 code using the Composition API.
Components should be small and focused. Business logic belongs in composables or stores,
not in `<template>` expressions or component `<script setup>` blocks.

## Quick reference

| Concept | Best practice |
|---|---|
| API Style | Use Composition API with `<script setup>` and TypeScript |
| Reactivity | Use `ref()` for primitives, `reactive()` for objects, `computed()` for derived |
| Props/Emits | Use `defineProps`, `defineEmits`, and `defineModel` (Vue 3.4+) |
| State | Use Pinia for global state; avoid mutating state directly from components |
| Key commands | `npm run dev`, `npm run build`, `npm run test:unit`, `npx vue-tsc --noEmit` |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

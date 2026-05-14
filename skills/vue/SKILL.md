---
name: vue
description: >
  Use when modifying Vue 3 frontend code: components, composables, Pinia stores,
  Vue Router, script setup, TypeScript, or Vue project structure.
paths:
  - "**/*.vue"
  - "**/vite.config.*"
  - "**/vitest.config.*"
allowed-tools:
  - "Bash(npm:*)"
  - "Bash(pnpm:*)"
  - "Bash(npx vitest:*)"
  - "Bash(vite:*)"
  - "Bash(vue-tsc:*)"
---

# Vue Skill

## Goal

Produce clean, maintainable Vue 3 code using the Composition API.
Components should be small and focused. Business logic belongs in composables or stores.

---

## Structure

```
src/
  components/     ← reusable, generic UI components
  composables/    ← reusable stateful logic (useX pattern)
  features/       ← one folder per feature/page
    leave-request/
      components/
      composables/
      stores/
      types/
  stores/         ← global Pinia stores
  router/
  types/
```

---

## Components

- Use `<script setup lang="ts">` for all new components.
- Use `defineProps<T>()` and `defineEmits<T>()` with explicit TypeScript types.
- Keep templates simple. Extract complex logic into composables.
- Use `v-model` with `defineModel()` for two-way binding (Vue 3.4+).
- Use `computed()` for derived state. Do not compute in templates.

---

## Composables

- Name composables with the `use` prefix: `useLeaveRequest`, `useAuth`.
- Return only what the consumer needs. Do not expose internal refs unnecessarily.
- Handle cleanup in `onUnmounted()` for event listeners, timers, and subscriptions.

---

## Pinia stores

- Define stores with `defineStore` using the composition API style (not options style).
- Keep stores focused on one domain concept.
- Do not put API calls directly in components — use stores or composables.
- Use `storeToRefs()` to destructure reactive state from a store.

---

## TypeScript

- Type everything. Avoid `any`.
- Define explicit interfaces for API response shapes.
- Use `Ref<T>`, `ComputedRef<T>`, and `MaybeRef<T>` where appropriate.

---

## Routing

- Use Vue Router with typed routes where possible.
- Use lazy-loaded route components: `() => import('./views/LeaveRequestView.vue')`.
- Use navigation guards (`beforeEach`) for authentication.

---

## Testing

- Use Vitest with Vue Test Utils.
- Test component behavior from the user's perspective (rendered output, interactions).
- Mock API calls with `vi.mock` or MSW.
- Do not test implementation details (internal refs, private methods).

---

## Verification commands

```bash
npm run build
npm run test
npm run lint
npm run type-check
```

---

## Final response requirements

Always report:
- Components / composables / stores changed.
- Tests added or updated.
- Build/lint/type-check result.

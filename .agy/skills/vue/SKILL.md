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
---

# Vue Skill

## Goal

Produce clean, maintainable Vue 3 code using the Composition API.
Components should be small and focused. Business logic belongs in composables or stores,
not in `<template>` expressions or component `<script setup>` blocks.

---

## Project structure

```
src/
  components/     ← reusable, generic UI components (Button, Modal, Input)
  composables/    ← reusable stateful logic (useX pattern)
  features/       ← one folder per domain feature
    leave-request/
      components/ ← feature-local components
      composables/
      stores/
      types/
  stores/         ← global Pinia stores
  router/         ← route definitions, guards
  types/          ← shared interfaces and DTOs
  utils/          ← pure helper functions (no Vue imports)
```

---

## Components — `<script setup>` patterns

Use `<script setup lang="ts">` for all new components.

```vue
<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useLeaveBalance } from '@/composables/useLeaveBalance'

// Props and emits with TypeScript types
const props = defineProps<{
  userId: string
  readonly?: boolean
}>()

const emit = defineEmits<{
  submitted: [leaveId: string]
  cancelled: []
}>()

// Two-way binding with defineModel (Vue 3.4+)
const modelValue = defineModel<string>()

// Local state
const loading = ref(false)
const { balance, refresh } = useLeaveBalance(props.userId)

// Derived state — never compute in templates
const canSubmit = computed(() => balance.value > 0 && !props.readonly)

// Side effects with cleanup
watch(() => props.userId, (id) => { refresh(id) }, { immediate: true })
</script>

<template>
  <form @submit.prevent="handleSubmit">
    <input v-model="modelValue" :disabled="!canSubmit" />
    <button type="submit" :disabled="loading || !canSubmit">Submit</button>
  </form>
</template>
```

**Rules:**
- `defineProps<T>()` / `defineEmits<T>()` — always typed, never runtime-only.
- `defineModel()` for two-way bindings instead of manual prop + emit pairs.
- `computed()` for any derived value — not inline ternaries in `<template>`.
- One concept per component. If the template exceeds ~100 lines, decompose.

---

## Composables

```typescript
// composables/useLeaveBalance.ts
import { ref, watch, onUnmounted } from 'vue'
import type { Ref } from 'vue'
import { fetchBalance } from '@/api/leave'

export function useLeaveBalance(userId: Ref<string> | string) {
  const balance = ref<number | null>(null)
  const error = ref<Error | null>(null)
  const loading = ref(false)

  async function refresh(id: string) {
    loading.value = true
    error.value = null
    try {
      balance.value = await fetchBalance(id)
    } catch (e) {
      error.value = e instanceof Error ? e : new Error(String(e))
    } finally {
      loading.value = false
    }
  }

  // Cleanup timers, subscriptions, event listeners here
  const timer = setInterval(() => {
    const id = typeof userId === 'string' ? userId : userId.value
    if (id) refresh(id)
  }, 30_000)
  onUnmounted(() => clearInterval(timer))

  return { balance, error, loading, refresh }
}
```

**Rules:**
- Name with `use` prefix: `useLeaveBalance`, `useAuth`, `useFeatureFlag`.
- Return only what the consumer needs — don't expose raw internal `ref`s.
- Always clean up in `onUnmounted()`: event listeners, timers, WebSocket connections.
- Handle errors inside the composable and expose an `error` ref — don't let async composables throw uncaught.
- Accept both `Ref<T>` and `T` with `MaybeRef<T>` from `vue` for flexible inputs.

---

## Pinia stores — composition style

```typescript
// stores/leaveStore.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { fetchLeaves, submitLeave } from '@/api/leave'
import type { LeaveRequest } from '@/types'

export const useLeaveStore = defineStore('leave', () => {
  // State
  const items = ref<LeaveRequest[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Getters
  const pendingCount = computed(() => items.value.filter(l => l.status === 'pending').length)

  // Actions
  async function loadLeaves(userId: string) {
    loading.value = true
    try {
      items.value = await fetchLeaves(userId)
    } catch (e) {
      error.value = 'Failed to load leaves'
    } finally {
      loading.value = false
    }
  }

  async function submit(req: Omit<LeaveRequest, 'id' | 'status'>) {
    const created = await submitLeave(req)
    items.value.push(created)
    return created
  }

  return { items, loading, error, pendingCount, loadLeaves, submit }
})
```

**In components:**
```typescript
import { storeToRefs } from 'pinia'
import { useLeaveStore } from '@/stores/leaveStore'

const store = useLeaveStore()
const { items, loading, pendingCount } = storeToRefs(store) // ← reactive destructuring
// Actions are not reactive — call directly:
store.submit(data)
```

**Rules:**
- Composition style (`() =>` factory) not options style (`{ state, getters, actions }`).
- `storeToRefs()` to destructure reactive state — plain destructuring breaks reactivity.
- Never call `HttpClient` / `fetch` directly from a component — go through a store or composable.
- Keep stores focused on one domain concept. Don't create a single mega-store.

---

## Vue Router 4

```typescript
// router/index.ts
import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  {
    path: '/leaves',
    component: () => import('@/features/leave-request/views/LeaveListView.vue'), // lazy
    meta: { requiresAuth: true },
  },
  {
    path: '/leaves/:id',
    component: () => import('@/features/leave-request/views/LeaveDetailView.vue'),
    props: true, // pass route params as component props
  },
]

const router = createRouter({ history: createWebHistory(), routes })

// Navigation guard
router.beforeEach((to) => {
  if (to.meta.requiresAuth && !useAuthStore().isLoggedIn) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }
})
```

**In components:**
```typescript
import { useRouter, useRoute } from 'vue-router'

const router = useRouter()
const route = useRoute()

// Typed params
const id = route.params.id as string
router.push({ name: 'leave-detail', params: { id } })
```

**Rules:**
- Lazy-load every route: `() => import('./views/…')`.
- Route guards use `router.beforeEach` — not in-component lifecycle hooks for auth.
- Pass params as props (`props: true`) instead of reading `route.params` in templates.

---

## Provide / Inject (typed)

```typescript
// Typed injection key
import type { InjectionKey } from 'vue'
import type { ThemeService } from '@/services/theme'

export const ThemeKey: InjectionKey<ThemeService> = Symbol('ThemeService')

// Parent provides:
provide(ThemeKey, new ThemeService())

// Child injects (type-safe, no cast needed):
const theme = inject(ThemeKey)!
```

Only use `provide`/`inject` for cross-cutting concerns (theme, i18n, auth context). For feature state, use a Pinia store.

---

## Performance patterns

- **`shallowRef()`** for large objects where you only swap the whole value — avoids deep reactive traversal.
- **`markRaw()`** to exclude objects that should never be reactive (third-party class instances, chart objects).
- **`v-memo="[dep1, dep2]"`** on expensive repeated subtrees (list items that rarely change).
- **`defineAsyncComponent()`** for heavy components to code-split at the component level.
- **Avoid reactive on large arrays** used only for read — use a regular `ref<T[]>` and reassign rather than `reactive([])`.

```vue
<!-- Only re-renders this subtree when item.id or item.selected changes -->
<div v-for="item in items" :key="item.id" v-memo="[item.id, item.selected]">
  <HeavyItem :item="item" />
</div>
```

---

## Nuxt 3 (SSR) considerations

- Use `useFetch()` / `useAsyncData()` for data fetching — not `onMounted` + fetch (runs server-side).
- Wrap browser-only code in `if (process.client)` or `<ClientOnly>`.
- Use `useState()` for SSR-compatible shared state (hydrates from server to client).
- Composables in `~/composables/` are auto-imported — no explicit import needed.
- Avoid accessing `window` / `document` at the module level — they don't exist on the server.

---

## Common anti-patterns to reject

| Anti-pattern | Fix |
|---|---|
| Direct mutation of props | Emit an event; use `defineModel()` for two-way |
| `v-if` + `v-for` on the same element | Wrap with `<template v-if>` outside the loop |
| Heavy computation in `<template>` expressions | Move to `computed()` |
| `watch` with no cleanup for async effects | Use `watchEffect` with cleanup, or abort controllers |
| Calling `store.state.foo` (raw Pinia state) | Use `storeToRefs` or a getter |
| `any` typed props | Define explicit `interface` or `type` |
| Accessing `router` / `route` outside `<script setup>` or a composable | Pass as argument or use within the Composition API context |

---

## Testing

- Use **Vitest** + **@vue/test-utils** (`mount`, not `shallowMount` by default).
- Test component behavior: props → rendered output, user interactions → emitted events.
- Test composables by calling them directly inside `withSetup()` or a minimal wrapper.
- Mock Pinia stores with `createTestingPinia()` from `@pinia/testing`.
- Mock API calls with **MSW** (network-level, not `vi.mock` of fetch).

```typescript
import { mount } from '@vue/test-utils'
import { createTestingPinia } from '@pinia/testing'
import LeaveForm from './LeaveForm.vue'

const wrapper = mount(LeaveForm, {
  global: { plugins: [createTestingPinia({ initialState: { leave: { items: [] } } })] },
  props: { userId: 'user-1' },
})
await wrapper.find('button[type=submit]').trigger('click')
expect(wrapper.emitted('submitted')).toBeTruthy()
```

---

## Verification commands

```bash
pnpm build             # vite build — must be clean
pnpm test              # vitest run
pnpm test --coverage
pnpm lint              # eslint
pnpm type-check        # vue-tsc --noEmit
```

---

## Final response requirements

Always report:
- Components / composables / stores changed.
- Vue version and any new compiler macros used (`defineModel`, etc.).
- Tests added or updated.
- Build / lint / type-check result.
- Any new dependency: name, version, **license (MIT only — see `dependencies` skill)**.

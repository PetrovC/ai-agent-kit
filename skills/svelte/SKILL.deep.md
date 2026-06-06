# Svelte Skill — Deep Reference

> Loaded on demand. The slim [`SKILL.md`](SKILL.md) covers the quick reference.

## Project structure (SvelteKit)

```
src/
├── lib/                  <- shared components, utilities, stores ($lib alias)
│   ├── components/       <- reusable UI components
│   ├── stores/           <- writable/readable/derived stores
│   └── server/           <- server-only utilities (never imported on the client)
├── routes/               <- file-system router
│   ├── +layout.svelte    <- root layout (applies to all routes)
│   ├── +layout.server.ts <- server load for the root layout
│   ├── +page.svelte      <- page component
│   ├── +page.server.ts   <- server load + form actions
│   └── +page.ts          <- universal load (runs on server + client)
├── app.html              <- HTML template
└── app.d.ts              <- App.Locals, App.PageData, App.Error types
```

Rules:
- Keep `+page.svelte` thin — data fetching in `+page.server.ts` / `+page.ts`.
- Use `src/lib/server/` for any code that must never run on the client (DB, secrets).
- Co-locate component styles in the component file (`<style>` block).

---

## Reactivity

Svelte's reactivity is **compile-time**, not runtime. Understand the rules before
reaching for workarounds.

- **`$:`** — reactive statements rerun when their dependencies change.
- **`$store`** — auto-subscribes and unsubscribes to any Svelte store.
- **Reassignment triggers updates** — `arr.push()` does not; `arr = [...arr, item]` does.
- **Object mutations** — `obj.prop = val` triggers if `obj` is declared with `let`.

```svelte
<script lang="ts">
  let count = 0;
  $: doubled = count * 2;        // reactive declaration
  $: if (count > 10) reset();    // reactive statement

  function increment() {
    count += 1;                  // reassignment — triggers reactivity
  }
</script>

<button on:click={increment}>
  {count} × 2 = {doubled}
</button>
```

Do not use reactive statements for side effects that belong in `onMount` or event handlers.

---

## Components

- Use TypeScript: `<script lang="ts">`.
- Export props with explicit types. Provide defaults where sensible.
- Use `$$Props` / `$$Events` / `$$Slots` interfaces for fully typed components.
- Prefer event forwarding (`<button on:click>`) over wrapping every event in a new dispatcher.
- Avoid `document` / `window` at module init — use `onMount` or browser checks.

```svelte
<script lang="ts">
  export let label: string;
  export let disabled = false;

  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher<{ click: void }>();
</script>

<button {disabled} on:click={() => dispatch('click')}>
  {label}
</button>
```

---

## Stores

Use the built-in store primitives. Do not reach for a state management library unless
the store surface is genuinely complex (rare in Svelte apps).

| Store type | When to use |
|---|---|
| `writable(initial)` | Mutable shared state |
| `readable(initial, start)` | Derived from external source (WebSocket, timer) |
| `derived(stores, fn)` | Computed from one or more stores |

```typescript
// src/lib/stores/cart.ts
import { writable, derived } from 'svelte/store';

export const items = writable<CartItem[]>([]);
export const total = derived(items, $items =>
  $items.reduce((sum, item) => sum + item.price * item.qty, 0)
);
```

- Store files live in `src/lib/stores/`.
- Export only what consumers need — keep implementation details in the module.
- Reset stores on logout / session end to avoid state leaks.

---

## SvelteKit data loading

### Server load (`+page.server.ts`)

Use for data that must not be exposed to the client as raw source, or that
requires access to secrets / DB.

```typescript
import type { PageServerLoad } from './$types';
import { error } from '@sveltejs/kit';

export const load: PageServerLoad = async ({ params, locals }) => {
  const post = await db.post.findUnique({ where: { slug: params.slug } });
  if (!post) throw error(404, 'Post not found');
  return { post };
};
```

### Universal load (`+page.ts`)

Use when the data can be fetched on both server and client (e.g., public API).

```typescript
import type { PageLoad } from './$types';

export const load: PageLoad = async ({ fetch, params }) => {
  const res = await fetch(`/api/posts/${params.slug}`);
  if (!res.ok) throw error(res.status);
  return { post: await res.json() };
};
```

Rules:
- Always type the return value of `load` — use `PageServerLoad` / `PageLoad` from `'./$types'`.
- Never access `document`, `window`, or browser APIs in `+page.server.ts`.
- Use `locals` (set in `hooks.server.ts`) for auth — never trust client-sent user IDs.

---

## Form actions

Prefer SvelteKit form actions over fetch-based mutations. They work without JavaScript,
are progressive-enhancement ready, and handle redirects cleanly.

```typescript
// +page.server.ts
import type { Actions } from './$types';
import { fail, redirect } from '@sveltejs/kit';

export const actions: Actions = {
  create: async ({ request, locals }) => {
    const data = await request.formData();
    const title = data.get('title')?.toString().trim();
    if (!title) return fail(400, { error: 'Title is required', values: { title } });
    await db.post.create({ data: { title, userId: locals.user.id } });
    throw redirect(303, '/posts');
  }
};
```

```svelte
<!-- +page.svelte -->
<script lang="ts">
  import { enhance } from '$app/forms';
  export let form; // ActionData typed from $types
</script>

<form method="POST" action="?/create" use:enhance>
  <input name="title" value={form?.values?.title ?? ''} />
  {#if form?.error}<p>{form.error}</p>{/if}
  <button>Create</button>
</form>
```

---

## TypeScript

- Configure `"strict": true` in `tsconfig.json`.
- Use `$types` imports (auto-generated by SvelteKit) for `PageData`, `PageServerLoad`, `Actions`.
- Do not `@ts-ignore` load function return types — fix the type instead.
- Enable `svelte-check` in CI to catch template type errors.

---

## Styling

- Styles are **scoped by default** in `<style>` blocks — no need for CSS modules or BEM.
- Use `:global()` sparingly and document why.
- Prefer Tailwind CSS or vanilla CSS custom properties over CSS-in-JS.
- Do not mix Tailwind utility classes with `<style>` blocks for the same element.

---

## Transitions and animations

- Use `transition:` / `in:` / `out:` for enter/exit animations — avoid manual CSS class toggling.
- Prefer built-in transitions (`fade`, `fly`, `slide`) before writing custom ones.
- Wrap long lists in `{#each}` with a keyed expression: `{#each items as item (item.id)}`.

---

## Testing

- **Unit / component tests**: Vitest + `@testing-library/svelte`.
- **E2E**: Playwright (SvelteKit's official recommendation).
- Test behavior visible to the user, not internal store state.
- Use `render` from `@testing-library/svelte` — avoid direct DOM manipulation.

```typescript
import { render, screen, fireEvent } from '@testing-library/svelte';
import Counter from './Counter.svelte';

test('increments count on click', async () => {
  render(Counter, { label: 'Add' });
  await fireEvent.click(screen.getByRole('button', { name: 'Add' }));
  expect(screen.getByText('1')).toBeInTheDocument();
});
```

---

## What NOT to do

- Do not use `querySelector` / `getElementById` when Svelte's `bind:` or `use:` directives apply.
- Do not mutate arrays/objects in place and expect reactivity — always reassign.
- Do not put secrets in `+page.ts` (universal load) — they are exposed to the client.
- Do not skip the `$types` imports — they are the primary correctness guarantee in SvelteKit.
- Do not use `<svelte:window on:scroll>` on every page — debounce and remove listeners in `onDestroy`.
- Do not write store logic inside a component — extract to `src/lib/stores/`.

---

## Verification commands

```bash
# Type-check Svelte templates
npx svelte-check --tsconfig tsconfig.json

# Build
npm run build

# Unit tests
npx vitest run

# E2E tests
npx playwright test
```

---

## Final response requirements

Always report:
- Components created or modified with their route or `$lib` path.
- Stores introduced or changed.
- Load function type (`PageServerLoad` vs `PageLoad`) and why.
- Tests added or updated.
- Commands run and result.
- Any SSR / client-only consideration (e.g., `browser` guard, `onMount` usage).

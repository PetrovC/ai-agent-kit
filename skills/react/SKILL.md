---
name: react
description: >
  Use when modifying React components, hooks, Next.js (app router or
  pages), Remix routes, state management, React Testing Library, or
  any React-based frontend project.
---

# React Skill

## Goal

Predictable, declarative React. Components describe what the UI should look
like for given props/state, never side effects in render. State lives at the
right level — not too high (re-render storm), not too low (prop drilling).

---

## Project structure

```
src/
  components/      # presentational, reusable
  features/        # one folder per feature (component + hooks + types + tests)
  hooks/           # cross-cutting hooks
  lib/             # framework-agnostic utilities, API clients
  app/ or pages/   # Next.js / Remix routes
```

Rules:
- Co-locate component + test + styles + types in the same feature folder.
- A component is a "feature" when it owns state and talks to external services.
- A component is "presentational" when it only takes props and renders JSX.

---

## TypeScript

- `strict: true`, `noUncheckedIndexedAccess: true`.
- Props: define as `type Props = { ... }` above the component.
- Use `ComponentPropsWithoutRef<'button'>` to extend native HTML props correctly.
- Avoid `React.FC` — it adds an implicit `children`. Type props explicitly.
- Use `as const` for tuple-like literal data.

```tsx
type Props = {
  label: string;
  onClick: () => void;
  variant?: 'primary' | 'ghost';
};

export function Button({ label, onClick, variant = 'primary' }: Props) {
  return <button onClick={onClick} className={variant}>{label}</button>;
}
```

---

## Hooks rules

- Hooks at the top level only. No conditionals, no loops.
- Custom hooks start with `use`. They can call other hooks.
- `useEffect` is for synchronizing with external systems — not for "do this after state changes" (use event handlers or derived state instead).
- `useMemo` / `useCallback` only when you measure a problem. Most reads are premature optimization.
- `useState` for local, `useReducer` when state transitions are non-trivial.

### Avoid the most common useEffect anti-patterns

- ❌ "Fetch data on mount" via `useEffect` for everything → use the framework's data layer (Next.js server components, Remix loaders, TanStack Query) instead.
- ❌ Synchronizing state with props in `useEffect` → derive directly during render.
- ❌ `useEffect` chains where one effect sets state that triggers another effect.

---

## State management

Pick the **smallest** thing that works:

| Need | Use |
|---|---|
| Local UI state | `useState` / `useReducer` |
| Shared state in a subtree | `Context` (rarely; performance trap if value changes often) |
| Server cache | TanStack Query / SWR / RSC fetch |
| Global client state | Zustand (MIT, tiny). Skip Redux unless you actually need its dev tools / middleware. |
| Forms | React Hook Form + zod resolver. Don't reinvent. |

Redux Toolkit is fine if the project already uses it — don't introduce it for new code.

---

## Next.js (App Router)

- Server Components by default. Add `'use client'` only when a component needs hooks, event handlers, or browser APIs.
- Fetch data in Server Components or `route.ts` handlers — not in client `useEffect`.
- `cache()` / React `cache` for request-scoped memoization.
- `revalidateTag` / `revalidatePath` for cache invalidation after mutations.
- Use `<Link>` for internal nav (prefetches). Use `<a>` only for external.
- Metadata via `export const metadata` or `generateMetadata`.

---

## Remix

- Routes own their data via `loader` (read) and `action` (mutate).
- `useLoaderData` returns the loader's return type — typed end-to-end.
- Forms are HTML forms by default — `<Form method="post">`. Progressive enhancement is free.
- Use `useFetcher` for non-navigating mutations.

---

## Testing (React Testing Library)

- Test what the user sees, not the internal state.
- Query by accessible role / label / text: `getByRole('button', { name: /save/i })`.
- Avoid `getByTestId` unless nothing else works.
- For user interactions: `@testing-library/user-event` (not `fireEvent` for typing/clicks).
- For async: `findBy*` queries (they auto-wait).

```tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

test('submits the form when valid', async () => {
  const onSubmit = vi.fn();
  render(<LoginForm onSubmit={onSubmit} />);
  await userEvent.type(screen.getByLabelText(/email/i), 'a@b.co');
  await userEvent.type(screen.getByLabelText(/password/i), 'secret123');
  await userEvent.click(screen.getByRole('button', { name: /sign in/i }));
  expect(onSubmit).toHaveBeenCalledWith({ email: 'a@b.co', password: 'secret123' });
});
```

- For network: MSW (mock service worker, MIT-licensed) — intercept at the network level, not the fetch wrapper.
- Vitest preferred over Jest for new projects.

---

## Performance

- React rerenders are cheap; the cost is usually below render: heavy computation or sub-tree updates.
- Use `key` correctly in lists — never `index` for reorderable data.
- Code-split with `lazy()` + `<Suspense>` for route-level chunks.
- Profile before optimizing. Don't `useMemo` everything.

---

## What NOT to do

- No DOM access via `document.getElementById` — use `ref`.
- No mutation of props or state (`state.items.push(x)`) — return new objects.
- No `dangerouslySetInnerHTML` from user input. Sanitize first (`dompurify`).
- No inline arrow functions in children when the parent rerenders frequently AND the child is memoized — defeats the memo.
- No effect chains: state A → effect sets B → effect sets C. Derive instead.
- No `console.log` left in committed code.

---

## Verification commands

```bash
pnpm tsc --noEmit
pnpm lint               # eslint-plugin-react, eslint-plugin-react-hooks
pnpm test               # vitest
pnpm test --coverage
pnpm build              # catches SSR / RSC errors early
```

---

## Final response requirements

Always report:
- Files changed and their kind (Server Component / Client Component / hook / utility).
- Tests added (queries used: getByRole / userEvent / findBy*).
- TS / lint / test / build results.
- Any new dependency: name, version, **license (MIT only — see `dependencies` skill)**.

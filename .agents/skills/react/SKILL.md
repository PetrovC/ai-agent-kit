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

### Server vs Client Components

```
Default: Server Component
Add 'use client' only when you need:
  - useState / useReducer / useContext
  - useEffect / useRef / lifecycle
  - Event handlers (onClick, onChange, ...)
  - Browser APIs (window, navigator, ...)
  - Third-party components that require a browser context
```

Keep `'use client'` boundaries at the **leaves** of the component tree. A Server Component can import and render a Client Component, not the other way around for async operations.

### Data fetching

```typescript
// Server Component — async by default
export default async function Page() {
  const data = await db.query("...");  // runs on the server, never exposed to client
  return <Component data={data} />;
}
```

- Fetch in Server Components or Route Handlers — not in client `useEffect`.
- Use `React.cache()` for request-scoped deduplication of DB calls.
- `revalidateTag("posts")` / `revalidatePath("/blog")` to purge the cache after mutations.
- `unstable_cache` for per-request caching with TTL.

### Server Actions

Server Actions are async functions that run on the server, callable from Client Components.

```typescript
// app/actions.ts
"use server";
export async function createPost(formData: FormData) {
  const title = formData.get("title") as string;
  // validate, save to DB, revalidate cache
  revalidatePath("/posts");
}

// Client Component
<form action={createPost}>
  <input name="title" />
  <button type="submit">Create</button>
</form>
```

- Validate inputs in the action — treat it like an API endpoint.
- Return `{ error: string }` for user-facing errors; throw for unexpected ones.
- Use `useActionState` / `useFormStatus` for pending state on the client.

### Route Handlers

```typescript
// app/api/posts/route.ts
export async function GET(req: Request) {
  const posts = await db.posts.findMany();
  return Response.json(posts);
}

export async function POST(req: Request) {
  const body = await req.json();
  // validate, create, return
  return Response.json(created, { status: 201 });
}
```

Prefer Server Actions for form mutations. Route Handlers for public APIs consumed by external clients.

### Middleware

```typescript
// middleware.ts (root)
export function middleware(request: NextRequest) {
  const token = request.cookies.get("session");
  if (!token && request.nextUrl.pathname.startsWith("/dashboard")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
}
export const config = { matcher: ["/dashboard/:path*"] };
```

- Use for auth redirects, A/B testing, locale detection, request logging.
- Keep it fast — it runs on every matched request before the page renders.
- Do not do DB queries in middleware; check a lightweight session cookie instead.

### Special files

| File | Purpose |
|---|---|
| `loading.tsx` | Instant loading UI (Suspense boundary) |
| `error.tsx` | Error boundary (must be a Client Component) |
| `not-found.tsx` | 404 page, triggered by `notFound()` |
| `layout.tsx` | Shared UI that wraps all children in a segment |
| `template.tsx` | Like layout but re-mounts on navigation |

### Environment variables

- `NEXT_PUBLIC_*` → bundled into the client. Safe for public values (analytics IDs, public URLs).
- All others → server-only. Never accessible in Client Components.
- Validate all env vars at startup with `zod` in a `env.ts` module.

```typescript
// env.ts
import { z } from "zod";
const schema = z.object({
  DATABASE_URL: z.string().url(),
  NEXT_PUBLIC_APP_URL: z.string().url(),
});
export const env = schema.parse(process.env);
```

### Image and font optimization

```tsx
import Image from "next/image";
// Always provide width/height or fill — prevents layout shift
<Image src="/hero.jpg" alt="Hero" width={1200} height={600} priority />
```

Use `next/font` for zero-layout-shift font loading (`font-display: optional` by default).

### Auth pattern

```typescript
// Recommended pattern: session in cookie, checked in middleware + Server Components
// middleware.ts → redirect if no session
// Server Component → read session, pass user to children
// Server Action → re-validate session before mutation
```

Never check auth only in the middleware — also verify in Server Components and Actions that use sensitive data.

### Metadata

```typescript
// Static
export const metadata: Metadata = { title: "My Page", description: "..." };

// Dynamic
export async function generateMetadata({ params }): Promise<Metadata> {
  const post = await getPost(params.slug);
  return { title: post.title };
}
```

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

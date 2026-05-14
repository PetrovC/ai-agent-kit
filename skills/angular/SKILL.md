---
name: angular
description: >
  Use when modifying Angular frontend code: components, services, routing,
  signals, RxJS, HTTP client, forms, pipes, or Angular project structure.
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
---

# Angular Skill

## Goal

Produce clean, maintainable Angular code. Components should be small and focused.
Business logic belongs in services, not in templates or component classes.

---

## Structure

```
src/
  app/
    core/           ← singleton services, guards, interceptors, app-wide config
    shared/         ← reusable components, pipes, directives, models
    features/       ← one folder per feature/page
      leave-request/
        components/
        services/
        models/
        leave-request.routes.ts
```

Rules:
- One component per file.
- One responsibility per component. Decompose complex UI into child components.
- Keep template logic minimal. Move conditions and transformations into services or pipes.
- Do not import `CoreModule` or feature services directly into unrelated features.

---

## Components

- Prefer standalone components (`standalone: true`) for new code.
- Use `OnPush` change detection for performance-critical components.
- Use signals (`signal()`, `computed()`, `effect()`) for local state in new components.
- Use RxJS only when dealing with async streams, events, or complex async coordination.
- Do not mix signals and RxJS in the same component without a clear reason.
- Unsubscribe from observables: use `takeUntilDestroyed()`, `async pipe`, or `DestroyRef`.

---

## Services

- Services are injectable singletons in `root` or a specific module scope.
- HTTP calls belong in services. Never call `HttpClient` from a component.
- Map HTTP responses to typed models in the service. Do not use `any`.
- Use `inject()` function for dependency injection in new code.

---

## Forms

- Use Reactive Forms for complex, validated forms.
- Use Template-driven Forms only for very simple, non-validated inputs.
- Define form models explicitly with `FormGroup`, `FormControl`, and typed forms (`FormGroup<...>`).

---

## Routing

- Define routes in feature route files (`feature.routes.ts`), not in `app.module.ts`.
- Use lazy loading for all feature routes.
- Use `ResolveFn` and `CanActivateFn` functional guards (Angular 15+).

---

## Naming

- Components: `LeaveRequestListComponent`
- Services: `LeaveRequestService`
- Models/interfaces: `LeaveRequest`, `LeaveRequestDto`
- Pipes: `FormatLeaveDatePipe`
- Guards: `authGuard` (camelCase function)
- Resolvers: `leaveRequestResolver`

---

## Testing

- Use `TestBed` with `provideHttpClientTesting()` for component/service tests.
- Use `jasmine` or `jest` consistently with the existing project.
- Test component rendering and user interactions, not Angular internals.
- Mock HTTP calls with `HttpTestingController`.

---

## Verification commands

```bash
ng build --configuration production
ng test --watch=false
ng lint
```

---

## Final response requirements

Always report:
- Components / services / routes changed.
- State management approach used (signals / RxJS / store).
- Tests added or updated.
- Build/lint result.

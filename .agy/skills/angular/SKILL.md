---
name: angular
description: >
  Use when modifying Angular frontend code: components, services, routing,
  signals, RxJS, HTTP client, forms, pipes, or Angular project structure.
  Covers Angular 17+ standalone components, new control flow syntax,
  signal-based APIs (input/output/model), deferrable views, and functional interceptors.
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
  - "Bash(pnpm:*)"
---

# Angular Skill

## Goal

Produce clean, maintainable Angular code. Components should be small and focused.
Business logic belongs in services, not in templates or component classes.
Default to Angular 17+ patterns: standalone components, signals, new control flow syntax.

---

## Project structure

```
src/
  app/
    core/           ← singleton services, guards, interceptors, app-wide config
    shared/         ← reusable components, pipes, directives, models
    features/       ← one folder per domain feature
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
- Feature modules communicate only via their public route configuration or shared services.

---

## Standalone components (Angular 14+, default in Angular 17+)

```typescript
@Component({
  selector: 'app-leave-form',
  standalone: true,
  imports: [ReactiveFormsModule, RouterLink, AsyncPipe],
  templateUrl: './leave-form.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LeaveFormComponent {
  // Signal-based input (Angular 17.1+)
  userId = input.required<string>()
  readonly = input(false)

  // Signal-based output (replaces @Output + EventEmitter)
  submitted = output<string>()       // emits the created leaveId
  cancelled = output()

  // Signal-based two-way binding (Angular 17.2+)
  value = model<string>('')

  private leaveService = inject(LeaveService)
  protected balance = signal<number | null>(null)
  protected loading = signal(false)

  constructor() {
    // effect() runs reactively whenever userId changes
    effect(() => { this.loadBalance(this.userId()) })
  }

  private async loadBalance(id: string) {
    this.loading.set(true)
    this.balance.set(await this.leaveService.getBalance(id))
    this.loading.set(false)
  }

  protected submit() {
    this.submitted.emit('leave-id-123')
  }
}
```

**Rules:**
- All new components are `standalone: true`.
- Use `ChangeDetectionStrategy.OnPush` — required when using signals.
- Use `inject()` for DI — not constructor parameter injection in new code.
- Use `input()` / `input.required()` instead of `@Input()`.
- Use `output()` instead of `@Output() name = new EventEmitter()`.
- Use `model()` for two-way bindings that replace `@Input value` + `@Output valueChange`.

---

## Signals — local state and reactivity

```typescript
// Local state
const count = signal(0)
count.set(1)           // replace
count.update(n => n + 1)  // transform

// Derived (computed automatically)
const doubled = computed(() => count() * 2)

// Side effects — run when dependencies change
effect(() => {
  console.log('count is now', count())
  // Return a cleanup function if needed:
  return () => cleanup()
})
```

**When to use signals vs RxJS:**

| Scenario | Use |
|---|---|
| Local component state | `signal()` |
| Derived/computed state | `computed()` |
| Async events, streams, complex async coordination | RxJS |
| HTTP responses (single value) | `toSignal(this.http.get(...))` |
| Bridging RxJS → template | `toSignal()` |
| Bridging signal → RxJS operator | `toObservable()` |

Do not mix signals and RxJS inside the same component without a bridging function — it produces confusing data flows.

---

## RxJS interop

```typescript
import { toSignal, toObservable } from '@angular/core/rxjs-interop'

@Component({ standalone: true })
export class LeaveListComponent {
  private leaveService = inject(LeaveService)

  // Observable → signal (auto-unsubscribes with the component)
  protected leaves = toSignal(this.leaveService.getLeaves(), { initialValue: [] })

  // Signal → observable (for use in rxjs pipelines)
  private userId = signal('usr-1')
  private userId$ = toObservable(this.userId)
}
```

---

## New control flow syntax (Angular 17+)

Prefer the new `@if` / `@for` / `@switch` / `@defer` syntax over structural directives.

```html
<!-- ✅ New syntax -->
@if (loading()) {
  <app-spinner />
} @else if (error()) {
  <p>{{ error() }}</p>
} @else {
  <ul>
    @for (item of items(); track item.id) {
      <li>{{ item.name }}</li>
    } @empty {
      <li>No items found.</li>
    }
  </ul>
}

<!-- ❌ Old syntax (don't write new code with these) -->
<app-spinner *ngIf="loading" />
<li *ngFor="let item of items; trackBy: trackById">
```

**`track` is required** in `@for` — use a stable, unique identifier (`item.id`).

---

## Deferrable views (`@defer`)

Use `@defer` to lazy-load heavy components until they're needed:

```html
@defer (on viewport) {
  <app-heavy-chart [data]="chartData()" />
} @loading (minimum 100ms) {
  <app-skeleton />
} @placeholder {
  <div class="chart-placeholder"></div>
} @error {
  <p>Chart failed to load.</p>
}
```

Triggers: `on idle`, `on viewport`, `on interaction`, `on hover`, `when condition`.
Use for below-the-fold content, heavy third-party components, and admin panels not on the critical path.

---

## Services

```typescript
@Injectable({ providedIn: 'root' })
export class LeaveService {
  private http = inject(HttpClient)

  getBalance(userId: string): Observable<number> {
    return this.http.get<number>(`/api/users/${userId}/balance`)
  }

  submit(req: CreateLeaveRequest): Observable<LeaveResponse> {
    return this.http.post<LeaveResponse>('/api/leaves', req).pipe(
      catchError(err => throwError(() => this.mapError(err)))
    )
  }

  private mapError(err: HttpErrorResponse): AppError {
    if (err.status === 409) return new ConflictError('Duplicate leave request')
    return new AppError('Unexpected error', err)
  }
}
```

**Rules:**
- HTTP calls belong in services. Never inject `HttpClient` into a component.
- Map HTTP responses to typed models in the service. No `any`.
- Use `inject()` function — not constructor-parameter DI in new services.
- Map errors to typed `AppError` subclasses — don't let raw `HttpErrorResponse` reach the component.

---

## Functional HTTP interceptors (Angular 15+)

```typescript
// core/interceptors/auth.interceptor.ts
import { HttpInterceptorFn } from '@angular/common/http'
import { inject } from '@angular/core'
import { AuthService } from '@/core/services/auth.service'

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = inject(AuthService).token()
  if (!token) return next(req)
  return next(req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }))
}

// Register in app.config.ts:
export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(withInterceptors([authInterceptor])),
  ]
}
```

Do not use class-based `HttpInterceptor` for new code — functional interceptors are simpler and tree-shakeable.

---

## Routing (standalone / functional)

```typescript
// app.routes.ts
export const APP_ROUTES: Routes = [
  {
    path: 'leaves',
    loadComponent: () => import('./features/leave-request/leave-list.component')
      .then(m => m.LeaveListComponent),
    canActivate: [authGuard],   // functional guard
  },
  {
    path: 'leaves/:id',
    loadComponent: () => import('./features/leave-request/leave-detail.component')
      .then(m => m.LeaveDetailComponent),
    resolve: { leave: leaveResolver },
  },
]

// Functional guard
export const authGuard: CanActivateFn = (route, state) => {
  const auth = inject(AuthService)
  return auth.isLoggedIn() || inject(Router).createUrlTree(['/login'], {
    queryParams: { redirect: state.url }
  })
}

// Functional resolver
export const leaveResolver: ResolveFn<LeaveDetail> = (route) => {
  return inject(LeaveService).getById(route.paramMap.get('id')!)
}
```

**Rules:**
- Every feature route uses `loadComponent` (lazy, standalone) — no `loadChildren` + NgModule.
- Use `CanActivateFn` / `ResolveFn` functional APIs — not class-based guards.
- Use `inject()` inside guards and resolvers.

---

## Reactive Forms (typed)

```typescript
this.form = new FormGroup({
  startDate: new FormControl<Date | null>(null, Validators.required),
  endDate:   new FormControl<Date | null>(null, Validators.required),
  reason:    new FormControl('', [Validators.required, Validators.maxLength(500)]),
})

// Typed value access — no casts:
const start: Date | null = this.form.controls.startDate.value
```

**Rules:**
- Use Reactive Forms for any form with validation — not Template-driven.
- Always type `FormControl<T>` explicitly; the default `FormControl<string | null>` is rarely what you want.
- Use `FormGroup<{...}>` for typed group access.

---

## Common anti-patterns to reject

| Anti-pattern | Fix |
|---|---|
| `*ngIf` / `*ngFor` in new templates | Use `@if` / `@for` with `track` |
| `@Input() value` + `@Output() valueChange` | Use `model<T>()` |
| `@Input() foo` / `@Output() fooChange` | Use `input<T>()` / `output<T>()` |
| Class-based HTTP interceptor | Use `HttpInterceptorFn` |
| `subscribe()` without unsubscribe in components | Use `toSignal()`, `async pipe`, or `takeUntilDestroyed()` |
| Business logic in templates (`*ngIf="list.length > 0 && user.role === 'admin'"`) | Move to a `computed()` or service method |
| `any` typed HTTP responses | Define a typed interface for every API response |
| `NgModule`-based feature modules for new features | Use standalone components + route lazy-loading |

---

## Testing

```typescript
describe('LeaveFormComponent', () => {
  let fixture: ComponentFixture<LeaveFormComponent>

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [LeaveFormComponent],
      providers: [
        provideHttpClientTesting(),
        { provide: LeaveService, useValue: { getBalance: () => of(10) } },
      ],
    }).compileComponents()
    fixture = TestBed.createComponent(LeaveFormComponent)
    fixture.componentRef.setInput('userId', 'user-1')
    fixture.detectChanges()
  })

  it('disables submit when balance is 0', () => {
    // set signal input and assert rendered state
    fixture.componentRef.setInput('balance', 0)
    fixture.detectChanges()
    expect(fixture.debugElement.query(By.css('button[type=submit]')).nativeElement.disabled).toBeTrue()
  })
})
```

**Rules:**
- Use `fixture.componentRef.setInput()` to set signal-based inputs in tests.
- Mock HTTP calls with `HttpTestingController` or `provideHttpClientTesting()`.
- Test rendered output and user interactions — not Angular internals.
- Use `By.css()` / `By.directive()` for element queries — not `document.querySelector`.

---

## Verification commands

```bash
ng build --configuration production   # must be clean (no errors, no warnings)
ng test --watch=false                  # karma or jest
ng lint                                # eslint with @angular-eslint
ng generate component --dry-run        # preview scaffolding
```

---

## Final response requirements

Always report:
- Components / services / routes changed.
- Angular version and which new APIs used (`input()`, `@if`, `@defer`, etc.).
- State management approach (signals / RxJS / both) and where the boundary is.
- Tests added or updated.
- Build / lint result.
- Any new dependency: name, version, **license (MIT only — see `dependencies` skill)**.

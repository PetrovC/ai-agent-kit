---
name: error-handling
description: >
  Use when designing or reviewing error handling, retries, timeouts,
  circuit breakers, bulkheads, fallback strategies, exception design,
  resilience patterns, or recovery flows across any language / stack.
allowed-tools:
  - "Bash(git:*)"
  - "Bash(rg:*)"
---

# Error-Handling Skill

## Goal

Failures are not exceptional — they are routine. Networks blip, dependencies
restart, disks fill. The goal is graceful behavior under failure: clear errors
to the user, recovery without manual intervention where possible, and no silent
data corruption.

---

## Universal principles

- **Make errors data, not control flow.** Return `Result<T, E>` / `Either` / `(T, error)` where the language supports it. Reserve exceptions for genuinely exceptional cases.
- **Fail fast at boundaries.** Validate user input early and return a clear 400. Inside the system, trust your invariants.
- **Don't swallow errors.** A caught exception that's not logged or re-thrown is a bug factory.
- **Don't catch everything.** Catch specific exception types. `catch (Exception e)` is rarely correct.
- **Errors have classes, not just messages.** Build a small taxonomy (validation, not-found, conflict, dependency-failure, internal) and map them to user-visible responses in one place.
- **Don't leak internals.** Stack traces and SQL errors go to logs, not to API responses.

---

## Error taxonomy

Define these at the application boundary; every domain error fits one:

| Class | HTTP equivalent | Retryable? | Examples |
|---|---|---|---|
| `validation` | 400 / 422 | No | Bad input shape, business-rule violation |
| `unauthenticated` | 401 | No | Missing / invalid token |
| `forbidden` | 403 | No | Authenticated but not allowed |
| `not_found` | 404 | No | Resource doesn't exist |
| `conflict` | 409 | Maybe (after refetch) | Optimistic concurrency, duplicate key |
| `rate_limited` | 429 | Yes (with backoff) | Throttled by upstream |
| `dependency_failure` | 502 / 503 | Yes (with backoff) | DB unreachable, external API timeout |
| `internal` | 500 | No | Genuine bug; investigate before retry |

Map domain exceptions / errors → these classes in **one place** (HTTP middleware or equivalent).

---

## Retries

### When to retry

- **Yes**: idempotent operations against a transient failure (network blip, 503, rate limit). 
- **No**: validation errors, 4xx other than 429, non-idempotent ops without an idempotency key.
- **Never**: in a tight loop with no backoff — you'll DOS the dependency.

### Strategy

- **Exponential backoff with jitter**: `delay = min(cap, base * 2^attempt) * random(0.5, 1.5)`.
- **Max attempts**: usually 3-5. After that, return the error.
- **Total deadline**: a parent timeout that caps overall wait, regardless of attempts.
- **Honor `Retry-After`** when the server sends it.

### Libraries

| Stack | Library |
|---|---|
| .NET | Polly (MIT) |
| Python | `tenacity` (MIT) or stdlib loops |
| Node | `p-retry` (MIT) or `axios-retry` |
| Go | `cenkalti/backoff` or hand-rolled with `time.Sleep` + jitter |
| Rust | `backoff` crate, or `tower-retry` for tower services |
| Java | Resilience4j |

---

## Timeouts

**Every external call has a timeout.** No exception.

- HTTP client default timeouts are often `infinite` — override.
- DB queries: set per-statement timeout.
- Long-running ops: implement cancellation (context.Context, CancellationToken, AbortSignal).
- Parent timeout > sum of child timeouts; otherwise the parent fires while children are mid-retry.

```
total budget    : 5 s
  per call      : 1 s
  retries (3)   : 1 s + 2 s + 4 s = 7 s   <-- exceeds budget
```

Reconcile: shorter per-call timeout, fewer retries, or longer budget.

---

## Circuit breakers

When a dependency is failing, **stop calling it** instead of retrying every request.

- **States**: `closed` (normal) → `open` (fail fast) → `half-open` (probe before closing).
- **Trip condition**: error rate over a window (e.g., > 50% errors in last 30 s).
- **Recovery**: after a cool-off, allow N probes; if successful, close.
- Use Polly / Resilience4j / `tower::ServiceBuilder::layer(BreakerLayer)` — don't write your own.
- Fall back to a sensible default response when open (cached value, "service unavailable", queue for later).

---

## Bulkheads

Isolate failure domains so one slow dependency doesn't exhaust the whole service.

- **Separate thread pools / connection pools** per downstream.
- **Separate consumer groups** per queue topic.
- **Limit concurrent calls** to each dependency (semaphore).
- The goal: when service B is down, traffic to A still works.

---

## Idempotency for retries

If a client may retry, the operation must be idempotent — or it must accept an `Idempotency-Key` and dedup server-side.

- HTTP `GET`, `PUT`, `DELETE` are idempotent by spec — design them accordingly.
- HTTP `POST` is not — accept `Idempotency-Key` header for state-changing endpoints that may be retried.
- See the `api-design` and `messaging` skills for more.

---

## Common bug patterns to flag

- **Empty `catch` block** — almost always wrong.
- **`catch (Exception e) { log.Error(e); throw; }`** — useless; the exception already propagates with its stack. Either add context or remove.
- **Retry without backoff** — hammers the failing dependency.
- **Try / catch around the *whole* function** — hides where the error actually came from.
- **Returning `null` on error** — caller must remember to check; use Result / Optional / exceptions instead.
- **Logging the same exception twice** as it bubbles up — log it once at the top, or in the layer that has context.
- **`finally` block that throws** — masks the original exception.
- **Catching cancellation** (`OperationCanceledException`, `asyncio.CancelledError`) and continuing — breaks cancellation propagation.
- **Generic 500 with no correlation ID** — un-debuggable in production.

---

## Per-language idioms

### .NET

- Throw typed exceptions in domain (`InsufficientBalanceException`); map to API responses in a single middleware.
- Use `ArgumentNullException.ThrowIfNull(x)` for guards.
- Polly for retries / circuit breakers.
- `IAsyncEnumerable<T>` with `[EnumeratorCancellation]` for cancellable streams.

### Python

- Define exceptions in a `errors.py` per module. Inherit from a common `AppError`.
- Use `try / except SpecificError`, never bare `except:`.
- `contextlib.suppress(SomeError)` for the rare case you want to ignore.
- `tenacity` for retries with backoff.

### Node / TypeScript

- Custom error classes extending `Error`. Set `name` for type discrimination.
- `error instanceof MyError` works only within a realm — use a discriminator field if crossing worker boundaries.
- `p-retry`, `axios-retry`, or `undici`'s built-in retry.

### Go

- Idiomatic: `if err != nil { return fmt.Errorf("...: %w", err) }`.
- Sentinel errors for known cases: `errors.Is`, `errors.As`.
- `context.Context` for cancellation; check `ctx.Err()` in loops.

### Rust

- `Result<T, E>` everywhere. `thiserror` for typed errors, `anyhow` for binary code.
- Never `.unwrap()` on values from I/O / user input.
- `tokio::time::timeout(...)` for time-bounded operations.

---

## What NOT to do

- No `panic!` / `unwrap` / silent `null` returns in business logic.
- No retries on non-idempotent operations without an idempotency key.
- No timeouts of `None` / `0` / `MaxValue`.
- No circuit breaker with thresholds tuned by guesswork — base on observed error rates.
- No swallow + log without re-throwing or returning a meaningful error.
- No catching `KeyboardInterrupt` / cancellation and ignoring it.
- No "fix" that hides the bug — e.g., `try / except: pass` to "make the test pass".

---

## Verification commands

```bash
# .NET — find empty catches and over-broad catches
grep -rn "catch (Exception" --include="*.cs" .
grep -rn "catch {" --include="*.cs" .

# Python
grep -rn "except:" --include="*.py" .
grep -rn "except Exception:" --include="*.py" .

# Node / TS
grep -rn "catch (e)" --include="*.ts" .  # consider whether 'e' is logged

# Go
grep -rn "_ = err" --include="*.go" .    # explicit error discards
```

---

## Final response requirements

Always report:
- Error classes touched and where they map to user-visible responses.
- Retry / timeout / circuit-breaker policies added or modified.
- Tests verifying the new error path (failing dependency, timeout, 429).
- Whether the change is idempotent if retried.
- Logging changes (no sensitive data, correlation ID present).
- Any new dependency (Polly, tenacity, etc.): name, version, **license (MIT only — see `dependencies` skill)**.

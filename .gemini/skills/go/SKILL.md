---
name: go
description: >
  Use when modifying Go code, modules, HTTP services, CLIs, table-driven
  tests, error handling, or any Go service / library structure.
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
allowed-tools:
  - "Bash(go:*)"
---

# Go Skill

## Goal

Idiomatic, simple, explicit Go. Small interfaces, error handling everywhere,
no hidden control flow. Code that reads top-to-bottom.

---

## Project structure

```
cmd/
  myapp/main.go            # entry point only; minimal logic
internal/                  # private packages — not importable externally
  domain/                  # pure types and rules
  app/                     # use cases
  adapter/                 # DB, HTTP clients, file system
  http/                    # handlers, middleware
pkg/                       # public, reusable packages (rare)
go.mod
go.sum
```

Rules:
- Business logic in `internal/domain` and `internal/app`. Not in handlers.
- `internal/` blocks external imports — use it for everything that's not a published library.
- One package = one cohesive concept. Don't create a `util` package.

---

## Idiomatic Go

- Receiver names: 1-2 letters, consistent across methods on the same type.
- Exported names: `CamelCase`. Unexported: `camelCase`. Acronyms: `HTTPServer`, not `HttpServer`.
- Short variable names in short scopes (`i`, `r`, `ctx`). Long names for package-level identifiers.
- `gofmt` is non-negotiable. Use `goimports` to manage imports.
- Prefer `any` over `interface{}` (Go 1.18+).
- Don't pre-allocate slices with `make([]T, 0, 10)` unless the capacity is meaningful.

---

## Errors

- Return errors as the last value. Never panic in library code.
- Wrap with context: `fmt.Errorf("loading user %s: %w", id, err)`.
- Compare with `errors.Is` (sentinel) or `errors.As` (typed).
- Define sentinel errors at the package level: `var ErrNotFound = errors.New("not found")`.
- Don't use `panic` for control flow. Reserve it for "impossible" conditions and program startup.

```go
user, err := repo.Find(ctx, id)
if err != nil {
    if errors.Is(err, ErrNotFound) {
        return nil, fmt.Errorf("user %s: %w", id, ErrNotFound)
    }
    return nil, fmt.Errorf("find user %s: %w", id, err)
}
```

---

## Context

- First parameter of any function doing I/O or that may block: `ctx context.Context`.
- Don't store `ctx` in structs.
- Always pass `ctx` to DB calls, HTTP calls, goroutines.
- Set deadlines / cancellations at the entry point (HTTP middleware, CLI root command).

---

## Interfaces

- **Define interfaces where they are consumed**, not where they are implemented.
- Keep interfaces small. `io.Reader`, `io.Writer`. Single-method interfaces are common and good.
- Never define an interface "just in case" — only when you actually have two implementations or need a mock.

---

## Concurrency

- Goroutines: only when you need concurrency. Don't sprinkle them.
- Always know how a goroutine terminates. Leaks are real bugs.
- Use `errgroup.Group` for fan-out with errors.
- Channels for ownership transfer / signaling. Mutexes for protecting state. Don't mix.
- Avoid `time.Sleep` for synchronization — use channels or `context` cancellation.

---

## HTTP (net/http or chi/echo/gin)

- `net/http` + `chi` is a great default. Keep frameworks minimal.
- Handlers: small functions that parse → call use case → encode response. No business logic.
- Middleware for cross-cutting: logging, auth, request ID, recovery.
- JSON: define request/response structs with json tags. Validate explicitly.
- Always set a timeout server-side (`Server.ReadTimeout`, `WriteTimeout`, `IdleTimeout`).

---

## Testing

- Tests live in the same package (`_test.go`) for white-box, or `package x_test` for black-box.
- Table-driven tests are idiomatic:

```go
func TestParseEmail(t *testing.T) {
    cases := []struct {
        name    string
        in      string
        want    string
        wantErr bool
    }{
        {"valid", "a@b.co", "a@b.co", false},
        {"empty", "", "", true},
    }
    for _, tc := range cases {
        t.Run(tc.name, func(t *testing.T) {
            got, err := ParseEmail(tc.in)
            if (err != nil) != tc.wantErr {
                t.Fatalf("err = %v, wantErr %v", err, tc.wantErr)
            }
            if got != tc.want {
                t.Errorf("got %q, want %q", got, tc.want)
            }
        })
    }
}
```

- Use `t.Helper()` in test helpers.
- Use `t.Cleanup(func(){...})` instead of defer for fixture teardown.
- For integration: `testcontainers-go` (Postgres, Redis), not SQLite.
- Benchmarks: `func BenchmarkX(b *testing.B)`. Don't optimize without one.

---

## What NOT to do

- No `init()` for anything other than package-level constants. Avoid it.
- No global mutable state — pass dependencies as struct fields.
- No `interface{}` parameters when you can use generics (Go 1.18+) or a concrete type.
- No "stringly typed" APIs — define a typed enum (`type Status string` + const).
- No `nil` map writes (panic). Initialize before writing.
- No goroutine without a clear termination path.

---

## Verification commands

```bash
go mod tidy
go build ./...
go vet ./...
gofmt -l .                   # lists files not formatted
golangci-lint run            # if installed
go test -race -count=1 ./...
go test -cover ./...
```

---

## Final response requirements

Always report:
- Packages changed (with their role: domain / app / adapter / http).
- Tests added or updated (mention table-driven if used).
- `go vet`, `go test -race`, and lint results.
- Any new dependency: module path, version, **license (MIT only — see `dependencies` skill)**.

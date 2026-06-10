---
name: rust
description: >
  Use when modifying Rust code: cargo workspaces, async (tokio), error
  handling (Result, thiserror/anyhow), traits, tests, CLI or service
  structure.
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
allowed-tools:
  - "Bash(cargo:*)"
version: "1.0.0"
keywords:
  - rust
  - cargo
  - tokio
  - lifetime
  - borrow checker
  - crate
  - clippy
  - axum
  - sqlx
task_intents:
  - implement
  - fix
  - refactor
  - review
---

# Rust Skill

## Goal

Idiomatic, type-safe, explicit Rust. Use the type system to make invalid
states unrepresentable. No `unwrap()` in production paths. No `unsafe`
unless documented and isolated.

---

## Project structure

```
Cargo.toml                # workspace root
crates/
  myapp-domain/           # pure types, no I/O, no async
  myapp-app/              # use cases, traits (ports)
  myapp-adapter-db/       # DB impl
  myapp-adapter-http/     # HTTP impl
  myapp-bin/              # main.rs — entry point only
```

Workspace `Cargo.toml`:
```toml
[workspace]
members = ["crates/*"]
resolver = "2"
```

Rules:
- Domain crate has no `tokio`, no `sqlx`, no `axum` — just types and pure functions.
- Application crate defines traits (`trait UserRepository`); Adapter crates implement them.
- Use `cargo workspace` features to compose, not feature flags scattered everywhere.

---

## Error handling

- **Library code**: `thiserror` for typed errors. Each crate defines its own `Error` enum.
- **Application / binary code**: `anyhow::Result<T>` for ergonomics.
- Never `.unwrap()` or `.expect()` on values that come from I/O, user input, or external systems. Reserve `expect` for invariants you can prove ("this regex compiles").
- Use `?` for propagation. Add `.context("...")` (anyhow) or `.map_err(|e| MyError::...)` for context.

```rust
#[derive(Debug, thiserror::Error)]
pub enum UserError {
    #[error("user {0} not found")]
    NotFound(UserId),
    #[error("database error")]
    Db(#[from] sqlx::Error),
}
```

---

## Async (tokio)

- One async runtime per binary, in `main`. Don't spawn runtimes from libraries.
- `#[tokio::main]` for binaries. Don't use it in libraries.
- Use `tokio::spawn` only when you need concurrency. Each spawn must have a clear lifecycle.
- Cancel-safety: anything passed to `tokio::select!` must be cancel-safe. Read the docs.
- For shared state: `Arc<Mutex<T>>` (std or tokio depending on need). Prefer message-passing (`mpsc`) over locks when possible.
- Always set timeouts on external calls: `tokio::time::timeout(...)`.

---

## Ownership and lifetimes

- Prefer owned types in public APIs unless borrowing is clearly cheaper and the lifetime is obvious.
- Don't sprinkle `'static` to silence the borrow checker — fix the design.
- Use `Cow<'a, str>` only when you have a real ownership-or-borrow situation.
- Newtype pattern for domain primitives: `struct UserId(uuid::Uuid)` — not raw `String`/`Uuid` everywhere.

---

## HTTP (axum / actix-web)

- **axum** is the modern default (built on tokio + tower).
- Handlers: `async fn handler(State(app): State<App>, Json(payload): Json<...>) -> Result<Json<...>, AppError>`.
- Use `axum::extract` for typed inputs. Don't parse the request manually.
- Implement `IntoResponse` on your error type to map errors → HTTP responses in one place.
- Middleware via `tower::ServiceBuilder`. Don't write middleware from scratch.

---

## SQL (sqlx / sea-orm / diesel)

- **sqlx** is a popular default — async, compile-time-checked queries with `query!` / `query_as!`.
- Connection pool: `PgPool`. Pass it in `State<AppState>`.
- Migrations: `sqlx migrate add` / `sqlx migrate run`. Commit them.
- Never build SQL by string concatenation — always parameterized queries.

---

## Testing

- Unit tests in the same file: `#[cfg(test)] mod tests { ... }`.
- Integration tests in `tests/` directory at the crate root — each file is a separate test binary.
- Use `assert_eq!` / `assert!`. For pretty diffs, `pretty_assertions` (MIT-licensed).
- Async tests: `#[tokio::test]`.
- For DB integration: `testcontainers` (Postgres in Docker), not in-memory SQLite.
- Property-based testing: `proptest` for edge cases on pure functions.

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_valid_email() {
        let result = parse_email("a@b.co");
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn fetches_user() {
        let repo = InMemoryRepo::new();
        repo.insert(User::new("alice"));
        let got = repo.find_by_name("alice").await.unwrap();
        assert_eq!(got.name(), "alice");
    }
}
```

---

## What NOT to do

- No `unsafe` unless absolutely required, with a `// SAFETY:` comment explaining why it's sound. Isolate it.
- No `unwrap()` / `expect()` on `Option` / `Result` from I/O or external input.
- No `clone()` everywhere to silence the borrow checker — fix the data flow.
- No `String` parameters when `&str` works.
- No `Vec<T>` parameters when `&[T]` works.
- No silent `Result` dropping (`let _ = ...` without a real reason).
- No async traits via macros if you can avoid it (use `async fn` in traits, stable since 1.75).

---

## Verification commands

```bash
cargo fmt --all
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-features
cargo test --doc                # doctests
cargo machete                   # detect unused deps (optional)
cargo audit                     # CVE check
```

---

## Godot (gdext)

For Rust inside a Godot project — GDExtension via the `godot` crate (gdext) —
use the `godot` skill: its `references/rust-gdextension.md` covers class
registration, `.gdextension` descriptors, per-platform builds, and the
GDScript ↔ Rust boundary. The crate-layout and error-handling rules in this
skill still apply to the Rust side.

---

## Final response requirements

Always report:
- Crates changed (with their role: domain / app / adapter / bin).
- Tests added or updated, including doctests if relevant.
- `clippy`, `test`, and `audit` results.
- Any new dependency: crate name, version, **license (MIT only — see `dependencies` skill)**.
- Any `unsafe` block introduced — with safety justification.

---
name: python
description: >
  Use when modifying Python code, FastAPI, Django, Flask, pytest,
  type-checked async code, dependency management (uv/poetry), or any
  Python backend / data project structure.
paths:
  - "**/*.py"
  - "**/pyproject.toml"
  - "**/requirements*.txt"
  - "**/setup.py"
  - "**/setup.cfg"
allowed-tools:
  - "Bash(python3:*)"
  - "Bash(python:*)"
  - "Bash(uv:*)"
  - "Bash(pytest:*)"
  - "Bash(ruff:*)"
---

# Python Skill

## Goal

Produce explicit, type-checked, testable Python code that a junior can read
and a senior would not refactor in 6 months. No "clever" comprehensions
when a loop is clearer.

---

## Project structure

```
src/
  myapp/
    __init__.py
    domain/           # pure logic, no I/O
    application/      # use cases, orchestration
    infrastructure/   # DB, HTTP, external APIs
    interfaces/       # FastAPI routes, CLI, workers
tests/
  unit/
  integration/
pyproject.toml
```

Rules:
- Domain has no framework imports (no FastAPI, no SQLAlchemy).
- Application defines protocols (typing.Protocol) implemented by Infrastructure.
- Interfaces call application use cases — no business logic inline.

---

## Tooling

- **Dependency / venv**: `uv` (preferred — fast, lockfile, deterministic) or `poetry`. Never `pip install` directly into a global env.
- **Type checking**: `mypy --strict` or `pyright`. Treat type errors as build failures.
- **Linting / formatting**: `ruff check` + `ruff format`. Drop `black` + `isort` + `flake8` — `ruff` replaces all three.
- **Testing**: `pytest` + `pytest-asyncio` for async. `pytest-cov` for coverage.

`pyproject.toml` must pin tool config explicitly. Don't rely on defaults.

---

## Type hints (mandatory)

- Annotate every function signature, including return type.
- Use `from __future__ import annotations` to allow forward refs (Python 3.10+ OK without it).
- Prefer `T | None` over `Optional[T]`.
- Use `TypedDict` / `Protocol` / `dataclass(slots=True, frozen=True)` for structured data.
- Pydantic models for validation at boundaries (HTTP, config). Not for internal types.

---

## FastAPI

- One router per bounded context, mounted at `app.include_router(...)`.
- Use `Depends()` for DI: DB sessions, current user, settings.
- Request/response models: Pydantic `BaseModel`. Never expose ORM entities directly.
- Use `response_model=...` on every route — strips fields not in the schema.
- Async routes only when actually doing async I/O. Don't sprinkle `async def` on sync code.
- Validation lives in Pydantic. Business rules live in the application layer.

---

## Django

- Apps small and focused. One app per bounded context, not one giant `core` app.
- Business rules in services modules, not in models or views.
- Querysets/managers for reusable queries. Avoid `.filter()` chains scattered everywhere.
- Migrations: `python manage.py makemigrations <app>` — never edit migration files manually except `RunPython` data ops.
- Use `select_related` / `prefetch_related` to avoid N+1.

---

## SQLAlchemy / ORM

- 2.x-style: `Mapped[...]` annotations and `mapped_column()`.
- Session per request via `Depends()` in FastAPI; close it in a `finally`.
- Repository pattern only when it adds something — don't wrap `session.query()` 1-for-1.
- Migrations via Alembic. Auto-generate then review and edit.

---

## Async

- `async def` only if the body actually awaits something.
- Never call sync I/O from async without `asyncio.to_thread()`.
- Use `anyio` for portability across asyncio / trio.
- Set timeouts on every external call (`asyncio.timeout(...)` or library-level).

---

## Testing (pytest)

- Test behavior, not internals. No tests on private functions.
- AAA structure (Arrange / Act / Assert).
- Use fixtures for shared setup. Scope them correctly (`function` default; `session` for expensive).
- `pytest.mark.parametrize` for table-driven cases.
- Async tests: `@pytest.mark.asyncio` and a real event loop.
- For HTTP: `httpx.AsyncClient(app=app)` — no need to spin up a server.
- For DB: use real Postgres via `testcontainers-python`, not SQLite. SQLite hides real-world bugs.

```python
@pytest.mark.parametrize("input,expected", [
    ("", False),
    ("a@b.co", True),
])
def test_is_valid_email(input: str, expected: bool) -> None:
    assert is_valid_email(input) is expected
```

---

## What NOT to do

- No `from x import *`.
- No mutable default arguments (`def f(x: list = [])`).
- No bare `except:` — always `except SomeError:`.
- No `print()` in library code — use `logging`.
- No global state for config — use `Settings` (Pydantic) injected via DI.
- No `eval` / `exec` on untrusted input.

---

## Verification commands

```bash
uv sync                          # install deps from lockfile
uv run ruff check . --fix
uv run ruff format .
uv run mypy src tests
uv run pytest -q
uv run pytest --cov=src --cov-report=term-missing
```

For Poetry, replace `uv run` with `poetry run`.

---

## Final response requirements

Always report:
- Layer of each changed file (Domain / Application / Infrastructure / Interfaces).
- Tests added or updated, with parametrize cases if relevant.
- Type-check, lint, test results.
- Any new dependency: name, version, **license (MIT only — see `dependencies` skill)**.

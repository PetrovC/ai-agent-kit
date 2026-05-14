# Architecture

> ⚠️ **STOP — Fill this file before letting any agent read it.**
> An empty template causes the agent to invent layers, modules, and dependencies.
> Once filled, remove this notice.

---

## Overview

<!-- Describe the system in 3–5 sentences. What does it do and how is it structured? -->

---

## Layer structure

> Adapt the names below to the actual stack. Examples by language:
> - .NET / Java / Kotlin: Domain / Application / Infrastructure / Interfaces
> - Python: domain / application / infrastructure / interfaces (snake_case)
> - Go: internal/domain, internal/app, internal/adapter, internal/http
> - Rust: crates/domain, crates/app, crates/adapter-*, crates/bin
> - Node: src/domain, src/application, src/infrastructure, src/interfaces

```
<Layer 1>  → Business concepts, entities, value objects, rules.
             No external dependencies (no framework, no ORM, no HTTP).

<Layer 2>  → Use cases, orchestration, ports (interfaces for I/O).
             Depends on Layer 1 only.

<Layer 3>  → External adapters: DB, HTTP clients, queues, file system.
             Implements Layer 2 ports.

<Layer 4>  → Entry points: HTTP controllers, workers, CLI, event consumers.
             Calls Layer 2 use cases. No business logic here.
```

---

## Modules / bounded contexts

<!-- List the main modules or bounded contexts and their responsibilities. -->

| Module | Responsibility |
|---|---|
| | |

---

## Dependency rules

<!-- Document what can depend on what in this specific project. -->

- ...
- ...

---

## Key flows

<!-- Describe the 2–3 most important technical flows (e.g. command processing, query, event handling). -->

### Flow 1: ...

```
Request → Controller → Dispatcher → Handler → Domain → Repository → DB
```

---

## Integration points

<!-- External systems, APIs, databases, queues. -->

| Integration | Type | Direction | Notes |
|---|---|---|---|
| | | | |

---

## Folder structure

<!-- Add the actual project folder structure here once established. -->

```
src/
  Domain/
  Application/
  Infrastructure/
  Web/
tests/
  Domain.Tests/
  Application.Tests/
  Integration.Tests/
```

---

## Architecture decisions

See [DECISIONS.md](./DECISIONS.md).

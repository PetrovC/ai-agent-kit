---
name: architecture
description: >
  Use when a task affects module boundaries, layer dependencies, Clean Architecture,
  DDD, CQRS, Event Sourcing, service decomposition, bounded contexts, cross-cutting
  concerns, or long-term maintainability decisions.
---

# Architecture Skill

## Goal

Protect maintainability, scalability, testability, and readability over time.

Architecture exists to serve the business. Do not introduce patterns for their own sake.
A simple, explicit design that a new developer can understand in one hour is always
preferable to a "correct" design that requires three architecture diagrams to explain.

---

## Before proposing any architectural change

Ask yourself, in order:

1. What business capability is affected?
2. What is the simplest design that preserves clear dependencies?
3. Is the proposed abstraction removing real duplication or protecting a real boundary?
4. Will a developer unfamiliar with the project understand this in 30 minutes?
5. Is this change reversible, or does it lock us in?

If you cannot clearly answer 1, 2, and 3 — simplify.

---

## Layer boundaries

```
Domain        → no external dependencies. Pure business logic.
Application   → depends on Domain only. Ports/interfaces defined here.
Infrastructure→ implements Application ports. Depends on Domain + Application.
Interfaces    → depends on Application only. No business logic here.
```

These rules are non-negotiable unless the project explicitly documents an exception
with a justification in `docs/ai/DECISIONS.md`.

---

## When to use each pattern

| Situation | Use |
|---|---|
| Simple CRUD with business rules | Layered architecture + domain model |
| Read/write models genuinely diverge | CQRS |
| Other parts of the system react to state changes | Domain events |
| The history of state changes is itself a product requirement | Event Sourcing |
| Independent business capability, separate deployability needed | Microservice / bounded context |
| Shared data, shared team, no strong reason to split | Modular monolith |

Default: use a **modular monolith** until there is a concrete reason to split.

Do not introduce microservices, event sourcing, or message buses because they are
"best practice." Introduce them when the business problem requires them.

---

## DDD

Use DDD concepts when:
- The domain has real complexity (not just CRUD).
- Business rules are non-trivial and likely to change.
- Multiple aggregates with invariants exist.

Apply:
- Entities: have identity, manage their own invariants.
- Value objects: immutable, equality by value, no identity.
- Aggregates: enforce consistency boundaries. One repository per aggregate root.
- Domain services: stateless business logic that doesn't belong to one entity.
- Domain events: signal that something meaningful happened in the domain.

Do not create domain objects just to follow a checklist.

---

## Bounded contexts

When the project uses multiple bounded contexts:
- Each context has its own model. Do not share entities across contexts.
- Use explicit contracts (DTOs, events, anti-corruption layers) at the boundary.
- Document each context in `docs/ai/ARCHITECTURE.md`.

---

## Decision rule for abstractions

Add an abstraction only when one of these is true:
- It removes real, stable duplication (not just speculative).
- It protects a meaningful boundary (infrastructure behind a port).
- It improves testability of business logic.

Do not add base classes, generic helpers, or extension methods speculatively.

---

## Verification

After any architectural change:
- Read `docs/ai/ARCHITECTURE.md` — confirm it still describes the system correctly; update if it doesn't.
- Read `docs/ai/DECISIONS.md` — add an entry if this constitutes a new architecture decision.
- Check that no new cross-layer dependency was introduced without a matching port/interface.
- Confirm the change is covered by at least one integration test (or document why it cannot be).

---

## Final response requirements

When proposing an architecture change, always structure your response as:

1. **Business capability affected** — what problem does this solve?
2. **Current state** — what is the existing design?
3. **Proposed change** — what changes and why?
4. **Layers affected** — which boundaries are touched?
5. **Dependencies introduced or removed** — what now depends on what?
6. **Why this is not over-engineered** — justify the complexity.
7. **Reversibility** — how hard is it to undo if wrong?
8. **Validation approach** — how do we know it works?

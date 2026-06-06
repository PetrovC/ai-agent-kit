---
name: architecture
description: >
  Use when a task affects module boundaries, layer dependencies, Clean Architecture,
  DDD, CQRS, Event Sourcing, service decomposition, bounded contexts, cross-cutting
  concerns, or long-term maintainability decisions.
allowed-tools:
  - "Bash(git:*)"
  - "Bash(rg:*)"
version: "1.0.0"
---

# Architecture Skill

## Goal
Protect maintainability, scalability, testability, and readability over time.

Architecture exists to serve the business. Do not introduce patterns for their own sake.
A simple, explicit design that a new developer can understand in one hour is always
preferable to a "correct" design that requires three architecture diagrams to explain.

## Quick reference

| Concept | Best practice |
|---|---|
| Layers | Domain (no dependencies) -> Application -> Infrastructure -> Interfaces/UI |
| Domain | Use Entities, Value Objects, and Domain Events for business rules |
| Boundaries | Access databases/APIs only via Ports (interfaces); implement in Adapters |
| Contexts | Keep bounded contexts isolated; map data transformations at boundaries |
| Abstractions | Introduce only when they protect a real boundary or remove duplication |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

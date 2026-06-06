---
name: error-handling
description: >
  Use when designing or reviewing error handling, retries, timeouts,
  circuit breakers, bulkheads, fallback strategies, exception design,
  resilience patterns, or recovery flows across any language / stack.
allowed-tools:
  - "Bash(git:*)"
  - "Bash(rg:*)"
version: "1.0.0"
---

# Error-Handling Skill

## Goal
Failures are not exceptional — they are routine. Networks blip, dependencies
restart, disks fill. The goal is graceful behavior under failure: clear errors
to the user, recovery without manual intervention where possible, and no silent
data corruption.

## Quick reference

| Concept | Best practice |
|---|---|
| Taxonomy | Distinguish between transient (network, timeout) and permanent (validation) errors |
| Resilience | Apply circuit breakers, retries with exponential backoff and jitter |
| Timeouts | Set explicit timeouts on all HTTP requests, database queries, and external calls |
| Recovery | Implement graceful fallback behaviors, bulkheads to contain failures |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

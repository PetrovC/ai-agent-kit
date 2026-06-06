---
name: performance
description: >
  Use when a task involves profiling, benchmarking, query optimization,
  memory usage, Core Web Vitals, API latency, caching strategy, or
  any measurable performance concern across backend or frontend.
allowed-tools:
  - "Bash(hyperfine:*)"
  - "Bash(wrk:*)"
  - "Bash(ab:*)"
  - "Bash(npm:*)"
  - "Bash(npx:*)"
version: "1.0.0"
---

# Performance Skill

## Goal
Make the slow thing fast, the expensive thing cheap, or the large thing small —
but only where it matters. Measure first. Never optimize without a baseline.

**The rule: profile → identify the bottleneck → fix the bottleneck → re-measure.**

## Quick reference

| Concept | Best practice |
|---|---|
| Bottlenecks | Use profilers (dotnet trace, cProfile, pprof, flamegraph) to find bottlenecks |
| Database | Add indexes, optimize queries (avoid N+1), use connection pools |
| Caching | Apply Cache-Aside pattern (Redis/Memcached) with proper TTL |
| Concurrency | Leverage async/await, worker pools, or goroutines/virtual threads |
| Key commands | `k6 run load-test.js`, `lighthouse http://localhost:3000` |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

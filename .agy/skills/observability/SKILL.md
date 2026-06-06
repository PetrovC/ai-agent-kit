---
name: observability
description: >
  Use when adding or reviewing logs, metrics, traces, health checks,
  alerting, SLOs / SLIs, structured logging, OpenTelemetry instrumentation,
  or anything that helps answer "what is the system doing right now?".
allowed-tools:
  - "Bash(otelcol:*)"
  - "Bash(curl:*)"
  - "Bash(jq:*)"
version: "1.0.0"
---

# Observability Skill

## Goal
A running system you can debug without SSH-ing in. Three pillars: **logs**
(what happened), **metrics** (how much / how fast), **traces** (across services).
A bug report should always be answerable from these three sources alone.

## Quick reference

| Concept | Best practice |
|---|---|
| Logging | Use JSON structured logging, include correlation IDs, NEVER log secrets |
| Tracing | Instrument HTTP/gRPC boundaries, database queries, and long background jobs |
| Metrics | Track RED (Rate, Errors, Duration) for services and USE for infrastructure |
| Alerts | Alert on symptoms (high error rate, high latency) not causes (high CPU) |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

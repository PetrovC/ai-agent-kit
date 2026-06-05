---
name: messaging
description: >
  Use when designing or modifying message-driven systems: Kafka, RabbitMQ,
  SQS, NATS, Redis Streams, EventBridge, in-process event buses, event sourcing,
  outbox pattern, idempotency, dead-letter queues, consumer groups, ordering.
allowed-tools:
  - "Bash(kafka-topics.sh:*)"
  - "Bash(rabbitmqctl:*)"
  - "Bash(redis-cli:*)"
  - "Bash(aws:*)"
version: "1.0.0"
---

# Messaging / Event-Driven Skill

## Goal
Async communication that survives restarts, redeploys, and partial failures.
Producers don't lose messages on crash. Consumers don't double-process on retry.
The system is observable: you can answer "what happened to message X?".

## Quick reference

| Concept | Best practice |
|---|---|
| Outbox Pattern | Save events to DB outbox in same transaction, publish asynchronously |
| Idempotency | Enforce idempotent message consumers using message deduplication IDs |
| Saga | Use orchestration or choreography to coordinate distributed transactions |
| Hygiene | Handle poison pills using Dead-Letter Queues (DLQ), configure proper retries |

## Full guidance
Extended how-to, patterns, anti-patterns, and checklists: [`SKILL.deep.md`](SKILL.deep.md)

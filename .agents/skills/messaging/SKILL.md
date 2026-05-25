---
name: messaging
description: >
  Use when designing or modifying message-driven systems: Kafka, RabbitMQ,
  SQS, NATS, Redis Streams, EventBridge, in-process event buses, event sourcing,
  outbox pattern, idempotency, dead-letter queues, consumer groups, ordering.
---

# Messaging / Event-Driven Skill

## Goal

Async communication that survives restarts, redeploys, and partial failures.
Producers don't lose messages on crash. Consumers don't double-process on retry.
The system is observable: you can answer "what happened to message X?".

---

## Universal principles

- **At-least-once delivery is the default.** Design every consumer to be **idempotent**. Exactly-once is a hard distributed problem; don't assume your broker gives it to you.
- **The broker is not your database.** Use it for transport. Persist business state in your DB.
- **Schemas are contracts.** Version them. Adding fields = safe. Removing / renaming = breaking.
- **Dead letters exist.** Plan where bad messages go and who looks at them.
- **Ordering is per-key, not global.** If you need order, partition by a stable key (user ID, order ID).

---

## Pattern: Outbox

The classic "publish + write to DB atomically" problem.

**Don't** publish to the broker first, then commit to DB — if the DB write fails, you've published a phantom event.
**Don't** commit first, then publish — if the publish fails, the event is lost.

**Do** use the **outbox pattern**:
1. In the same DB transaction as your domain write, insert a row in an `outbox` table.
2. A background relay reads `outbox`, publishes to the broker, marks the row as sent.
3. Failures are retried by the relay; nothing is lost.

```sql
CREATE TABLE outbox (
    id          uuid PRIMARY KEY,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    topic       text NOT NULL,
    key         text NOT NULL,
    payload     jsonb NOT NULL,
    sent_at     timestamptz,
    attempts    int NOT NULL DEFAULT 0
);
CREATE INDEX outbox_unsent_idx ON outbox (occurred_at) WHERE sent_at IS NULL;
```

A relay polls (`SELECT ... FOR UPDATE SKIP LOCKED`) or uses logical replication (Debezium).

---

## Pattern: Idempotency

Every consumer must handle the same message arriving more than once.

**Two approaches:**
1. **Natural idempotency**: the operation is repeatable (`SET status = 'paid' WHERE id = X` is idempotent; `INCREMENT balance` is not).
2. **Idempotency key + dedup table**: store a `(consumer, message_id)` row at the start of processing. If the row already exists, skip.

```sql
CREATE TABLE consumed_messages (
    consumer   text NOT NULL,
    message_id uuid NOT NULL,
    consumed_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (consumer, message_id)
);
```

Combine with the business write in the same transaction.

---

## Pattern: Saga / process manager

For multi-step workflows across services: each step emits an event; the next step consumes it. Compensating events undo earlier steps on failure.

- Keep saga state in **its own** persisted document, not scattered across services.
- Log every transition (`started`, `step1_ok`, `step2_failed`, `compensating`, `done`).
- Set a max duration per saga; if exceeded, alert.

---

## Brokers — when to use which

| Broker | Sweet spot | Avoid when |
|---|---|---|
| **Kafka** | High-throughput event streams, replay, multiple consumers. | You need per-message TTLs or priority queues. |
| **RabbitMQ** | Classic work queues, RPC-like patterns, complex routing (topic exchanges). | You need long retention / replay. |
| **AWS SQS** | Simple managed work queues, decoupling AWS services. | You need ordering across many partitions; standard SQS is unordered. |
| **AWS SNS + SQS** | Pub/sub on AWS without running a broker. | You need exactly-once or replay. |
| **NATS / NATS JetStream** | Low-latency in-cluster messaging. | You don't need NATS-specific features. |
| **Redis Streams** | Existing Redis, modest throughput, simple consumer groups. | You need durability guarantees beyond what Redis offers. |
| **EventBridge** | AWS-native event routing across services. | You need replay. |
| **In-process event bus** | Same-service domain events (no network). | You think you need a broker — most apps don't until they have >2 services. |

---

## Kafka specifics

- **Partition = unit of parallelism.** Choose a partition key that distributes load evenly AND preserves the order you care about.
- **Consumer groups**: each partition is consumed by one consumer in the group at a time.
- **Offsets are stored**, but commit them after processing — auto-commit is a footgun.
- **Replication factor ≥ 3** for production. `min.insync.replicas = 2`.
- **No infinite topics for transient data** — set retention (`retention.ms` or `retention.bytes`).
- **Schema registry** (Confluent, Apicurio) for Avro / Protobuf to enforce schema evolution rules.

---

## RabbitMQ specifics

- **Exchanges** route to queues; consumers read from queues.
- **Durable queues + persistent messages + publisher confirms** = at-least-once.
- **Dead-letter exchange (DLX)** on every business queue. Routing key: `<queue>.dead`.
- **Prefetch (QoS)**: tune `basic.qos(prefetch_count=N)` so a slow consumer doesn't hoard messages.
- **Don't use auto-delete queues** for anything important.

---

## SQS specifics

- **Standard vs FIFO**: FIFO gives ordering + dedup, but lower throughput and per-region limits.
- **Visibility timeout** must exceed the longest processing time, or the message reappears.
- **Dead-letter queue** with `maxReceiveCount` (typically 3-5).
- **Long polling** (`WaitTimeSeconds=20`) — avoid busy-looping.
- **Batch operations** (`SendMessageBatch`, `DeleteMessageBatch`) — 10 messages max per call.

---

## Schemas and versioning

- Use Avro / Protobuf / JSON Schema. Pick one per platform.
- Register schemas centrally if possible; otherwise version them in a `schemas/` repo.
- Evolution rules (Avro defaults):
  - Add a field with a default → backward-compatible.
  - Remove a field → breaks readers expecting it.
  - Rename → always breaking; deprecate first, remove later.

---

## Consumer hygiene

- **Validate** the incoming message before processing. Bad schema → DLQ, not crash.
- **Bound the work** per message. Reject messages that would take > 30 s, or split them.
- **Log the message ID** in every log line touching that message.
- **Track DLQ depth** as a metric. Alert when it grows.
- **Replay tooling**: have a way to re-consume from the DLQ after a fix.

---

## What NOT to do

- No reading message → calling external service → writing DB without idempotency. Crash mid-way and you'll double-write.
- No retry loops without an upper bound or exponential backoff.
- No `at most once` semantics for anything that matters — losing payments / orders is unacceptable.
- No mixing serialization formats in the same topic.
- No producing before the schema is published / agreed upon.
- No infinite retention without a reason.
- No "we'll add a DLQ later" — add it now.

---

## Verification commands

```bash
# Kafka
kafka-topics --bootstrap-server localhost:9092 --list
kafka-console-consumer --bootstrap-server localhost:9092 --topic leaves.created --from-beginning --max-messages 5
kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group leavedesk-balance-consumer

# RabbitMQ
rabbitmqctl list_queues name messages consumers
rabbitmqctl list_consumers

# SQS
aws sqs get-queue-attributes --queue-url $URL --attribute-names ApproximateNumberOfMessages
aws sqs receive-message --queue-url $URL --max-number-of-messages 10

# NATS
nats stream ls
nats consumer info STREAM CONSUMER
```

---

## Final response requirements

Always report:
- Producers and consumers added / changed.
- Topic / queue names and their retention / DLQ settings.
- Schema versioning impact (backward-compatible or breaking).
- Idempotency strategy for new consumers.
- Outbox usage if producing alongside a DB write.
- Replay / recovery plan if a consumer fails for an hour.
- Any new dependency (client lib, serializer): name, version, **license (MIT only — see `dependencies` skill)**.

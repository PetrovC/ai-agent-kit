---
name: observability
description: >
  Use when adding or reviewing logs, metrics, traces, health checks,
  alerting, SLOs / SLIs, structured logging, OpenTelemetry instrumentation,
  or anything that helps answer "what is the system doing right now?".
---

# Observability Skill

## Goal

A running system you can debug without SSH-ing in. Three pillars: **logs**
(what happened), **metrics** (how much / how fast), **traces** (across services).
A bug report should always be answerable from these three sources alone.

---

## Universal principles

- **Structured by default.** JSON logs to stdout. The platform aggregates.
- **Correlation everywhere.** Every log line, metric, trace span carries a `trace_id` / `request_id` so you can pivot from one to the other.
- **Cardinality control.** Labels with unbounded values (`user_id`, `request_id`) explode metric storage. Use them in logs and traces, not metric labels.
- **Sample, don't drop.** Head-sample traces (1-10%) but keep error/slow traces (tail-sampling).
- **Cost is real.** Logs are the most expensive pillar. Don't `INFO`-log every line of a hot path.

---

## Logging

### Structure

Every log entry must include:
- `timestamp` (ISO 8601, UTC)
- `level` (DEBUG / INFO / WARN / ERROR)
- `message` (human-readable, fixed string with context in fields)
- `service` (service name)
- `trace_id` / `span_id` if inside a request
- `request_id` (HTTP correlation, propagated as `X-Request-Id`)

```json
{
  "timestamp": "2026-05-14T10:23:11.42Z",
  "level": "ERROR",
  "message": "leave approval rejected",
  "service": "leavedesk-api",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "request_id": "req_abc123",
  "user_id": "usr_42",
  "leave_id": "lv_xyz",
  "reason": "insufficient_balance"
}
```

### Levels

| Level | When |
|---|---|
| DEBUG | Dev / staging diagnosis. Off in prod (or sampled). |
| INFO | Business events: "leave created", "user signed in". Not for hot paths. |
| WARN | Recoverable issues: retry succeeded, fallback used. |
| ERROR | Failed operation that the user / caller observes. Include the exception class. |

### Libraries

| Stack | Recommended |
|---|---|
| .NET | Serilog → JSON formatter |
| Python | `structlog` or stdlib `logging` with `python-json-logger` |
| Node | `pino` (fast, MIT, structured) |
| Go | `slog` (stdlib, Go 1.21+) or `zap` |
| Rust | `tracing` + `tracing-subscriber` with JSON output |
| Flutter | `logger` package, send important events to a backend collector |

### Never log

- Passwords, tokens, API keys, session IDs.
- PII unless legally required and clearly tagged.
- Full request bodies if they may contain secrets.
- Stack traces from expected exceptions (e.g., validation failures).

---

## Metrics

### Types

- **Counter**: monotonically increasing (`http_requests_total`).
- **Gauge**: current value (`queue_depth`, `active_connections`).
- **Histogram**: distribution of values (`http_request_duration_seconds`).

### Naming

- Lowercase, underscored: `http_request_duration_seconds`.
- Suffix the unit: `_seconds`, `_bytes`, `_total` (for counters).
- Use OpenMetrics / Prometheus conventions even when sending to Datadog / NewRelic — keeps you portable.

### The four golden signals (per service)

1. **Latency**: how long requests take (histogram, p50 / p95 / p99).
2. **Traffic**: how many requests / sec (counter).
3. **Errors**: how many requests fail (counter, by status code).
4. **Saturation**: how full the system is (gauge: CPU %, memory %, queue depth).

Alert on **symptoms** (high p99, error rate) not **causes** (high CPU) — symptoms are user-visible.

### Cardinality

Bad:
```
http_requests_total{user_id="usr_42"}     # explodes — 1 series per user
```

Good:
```
http_requests_total{method="POST",route="/leaves",status="200"}
```

Push `user_id` into logs / traces, not metric labels.

---

## Tracing

- **OpenTelemetry (OTel)** is the modern, vendor-neutral standard. Use the language SDK.
- Span = an operation (HTTP request, DB query, function call). Spans nest into a trace.
- Propagate the W3C `traceparent` header across services. Most SDKs do this automatically.
- Add semantic attributes: `http.method`, `db.statement`, `messaging.system`. Follow the OTel semantic conventions.
- Sample at the edge (entry point), not per-service.

```
Trace: POST /leaves (root span)
├── DB: SELECT user WHERE id = ?
├── DB: INSERT INTO leaves ...
├── HTTP: POST internal-auth/verify
└── (response)
```

### What to instrument

- Inbound HTTP / gRPC requests (auto-instrumentation usually covers this).
- DB queries (auto with most ORMs).
- Outbound HTTP calls.
- Message queue produce / consume.
- Significant in-process operations (a 50 ms computation worth a span).

### What NOT to trace

- Every function call (you'll drown).
- Hot loops.
- Anything that produces 1000+ spans per request — split or drop.

---

## Health checks

### Liveness vs readiness

- **Liveness**: "am I alive?" — if false, restart the pod. Should not check downstream dependencies (DB, Redis) because a transient DB outage shouldn't crash all your pods.
- **Readiness**: "am I ready to serve traffic?" — should check critical dependencies. If false, take this instance out of the load balancer.

```
GET /health/live    → 200 if process is running
GET /health/ready   → 200 if can reach DB, Redis, etc. (with short timeout)
```

Liveness is cheap. Readiness can be expensive — cache the result for 5-10 seconds.

---

## Alerting

- **Alert on SLO breaches, not raw errors.** "Error rate > 1% over 5 min" is actionable. "One 500 happened" is noise.
- **Pageable alerts must be actionable.** If the on-call can't fix it at 3 AM, it's a dashboard, not a page.
- **Symptoms over causes.** Page on "users seeing 500s", not "CPU is high".
- **Runbook link in the alert message.** Every alert has a one-page runbook.
- **Alert fatigue is real.** Review monthly: which alerts fired? Which were actionable? Tune or delete.

---

## SLO / SLI basics

- **SLI** (indicator): a measurable metric (`successful HTTP requests / total HTTP requests`).
- **SLO** (objective): the target (`99.9% successful, measured over 30 days`).
- **Error budget**: `1 - SLO = 0.1%`. You can "spend" it on risky deploys or feature work.
- Set SLOs **based on what users care about**, not on what's easy to measure.

---

## What NOT to do

- No `console.log` / `print()` in committed code — use the logging library.
- No logging in tight loops without sampling — you'll DOS your log pipeline.
- No `WARN` for every recoverable hiccup — reserve for things that need investigation.
- No high-cardinality labels in metrics.
- No alerting on every error — alert on rates / SLO breaches.
- No "alerts as inbox" — every page must demand action within minutes.
- No metric / log without a documented meaning. If you can't explain why you added it, remove it.

---

## Verification commands

```bash
# Quick local check that logs are JSON
curl -s http://localhost:3000/api/health | head -1 | jq .

# Prometheus scrape endpoint
curl -s http://localhost:9090/metrics | grep http_request_duration_seconds

# Trace export sanity (if running an OTel collector locally)
curl -s http://localhost:55679/debug/tracez

# Production-style log query (Loki / Cloudwatch / etc. — depends on platform)
# logcli query '{service="leavedesk-api", level="ERROR"} | json | trace_id="abc"'
```

---

## Final response requirements

Always report:
- New instrumentation added (logs / metrics / traces) and at which layer.
- Cardinality assessment for any new metric.
- Any new SLO / SLI proposed.
- Alert rules added or changed.
- Cost implication if the change is high-volume (logs especially).
- Any new dependency: name, version, **license (MIT only — see `dependencies` skill)**.

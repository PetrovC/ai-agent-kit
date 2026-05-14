---
name: performance
description: >
  Use when a task involves profiling, benchmarking, query optimization,
  memory usage, Core Web Vitals, API latency, caching strategy, or
  any measurable performance concern across backend or frontend.
---

# Performance Skill

## Goal

Make the slow thing fast, the expensive thing cheap, or the large thing small —
but only where it matters. Measure first. Never optimize without a baseline.

**The rule: profile → identify the bottleneck → fix the bottleneck → re-measure.**

---

## Universal principles

- **Do not guess.** Profile before changing anything. A well-intentioned optimization
  in the wrong place wastes time and adds complexity.
- **Establish a baseline** before any change: response time p50/p95/p99, memory, throughput.
- **One change at a time.** Mixing changes makes it impossible to isolate the cause.
- **Premature optimization is the root of all evil.** Make it correct first, then fast.
- **Know your bottleneck type**: CPU-bound, I/O-bound, memory-bound, or network-bound.
  Each has different fixes.

---

## Backend — profiling and diagnosis

### Identify the bottleneck

```bash
# .NET — CPU/memory profile
dotnet-trace collect --process-id <pid> --providers Microsoft-DotNETCore-SampleProfiler
dotnet-counters monitor --process-id <pid>

# Python — CPU profile
python -m cProfile -o profile.out app.py
python -m pstats profile.out

# Go — pprof
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30
go tool pprof http://localhost:6060/debug/pprof/heap

# Node.js — built-in profiler
node --prof app.js
node --prof-process isolate-*.log > processed.txt

# Rust — flamegraph
cargo flamegraph --bin myapp
```

### Database queries

Slow queries are the most common backend bottleneck.

- **EXPLAIN / EXPLAIN ANALYZE** every slow query before adding an index.
- Add indexes on columns used in `WHERE`, `JOIN`, `ORDER BY`, and `GROUP BY`.
- Avoid N+1 queries — eager-load relationships.
- Avoid `SELECT *` — select only the columns you need.
- Paginate large result sets — never load unbounded rows.

```sql
-- Postgres: show query plan with actual timings
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;

-- Find slow queries (pg_stat_statements extension)
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;
```

**Stack-specific ORM patterns:**

| Stack | Anti-pattern | Fix |
|---|---|---|
| .NET EF Core | Lazy loading in a loop | Use `.Include()` / `.ThenInclude()` |
| Python SQLAlchemy | `session.query(Model).all()` then iterate | Use `selectinload` / `joinedload` |
| Node Prisma | Nested `findMany` in a loop | Use `include` at the top level |
| Go sqlx | `db.Get()` inside a loop | Use `db.Select()` with `IN` clause |

### Caching

- **Cache at the right layer**: in-process (memory) → distributed (Redis) → CDN.
- Always define a TTL and an eviction strategy.
- Cache results that are expensive to compute and read far more often than written.
- Invalidate on write, not on read.

```python
# Redis cache-aside pattern (Python)
def get_user(user_id: int) -> User:
    key = f"user:{user_id}"
    cached = redis.get(key)
    if cached:
        return User.parse_raw(cached)
    user = db.query(User).filter_by(id=user_id).first()
    redis.setex(key, 300, user.json())  # TTL: 5 min
    return user
```

### Async / concurrency

- Replace synchronous I/O with async I/O for network-heavy workloads.
- Use connection pooling — opening a new DB connection per request is expensive.
- For CPU-heavy tasks: offload to a background queue (Celery, BullMQ, Hangfire, Go goroutines).
- Do not block the event loop in Node.js — move CPU work to a worker thread.

---

## Frontend — Core Web Vitals

Target thresholds (Google "Good" range):

| Metric | Target | Meaning |
|---|---|---|
| LCP (Largest Contentful Paint) | ≤ 2.5 s | Perceived load speed |
| INP (Interaction to Next Paint) | ≤ 200 ms | Responsiveness |
| CLS (Cumulative Layout Shift) | ≤ 0.1 | Visual stability |

### LCP

- Pre-load the LCP image: `<link rel="preload" as="image" href="hero.webp">`.
- Serve images in modern formats (WebP, AVIF). Use `<picture>` for fallbacks.
- Serve fonts with `display: swap` and preload critical fonts.
- Use a CDN for static assets.

### INP

- Do not run long tasks (> 50 ms) on the main thread.
- Break long tasks into microtasks with `scheduler.yield()` or `requestAnimationFrame`.
- Debounce and throttle event handlers.
- Virtualize long lists (react-window, @tanstack/virtual).

### CLS

- Always set explicit `width` and `height` on images and videos.
- Do not inject content above existing content after load.
- Reserve space for ads and embeds with a fixed container size.

### Bundle size

```bash
# Analyze bundle (Vite)
npx vite-bundle-visualizer

# Analyze bundle (webpack)
npx webpack-bundle-analyzer stats.json

# Check what's large (generic)
npx bundlephobia-cli <package-name>
```

- Code-split at the route level — dynamic `import()`.
- Tree-shake: import named exports, not default objects (`import { fn } from 'lib'`).
- Replace heavy libraries with lighter alternatives (e.g., `date-fns` instead of `moment`).
- Lazy-load below-the-fold components and images (`loading="lazy"`).

---

## HTTP and API performance

- **HTTP/2 or HTTP/3** — multiplex requests. Verify your server supports it.
- **Compression**: enable gzip / Brotli for text responses.
- **Cache headers**: set `Cache-Control` and `ETag` on static assets and API responses.
- **Pagination**: cursor-based for large or frequently-updated datasets; offset-based for UIs with page numbers.
- **Response shape**: return only the fields the client needs — avoid over-fetching.

```
Cache-Control: public, max-age=31536000, immutable   # static assets (hash in filename)
Cache-Control: no-cache                               # HTML (must revalidate)
Cache-Control: private, max-age=300                  # authenticated API responses
```

---

## Memory

- **Profile before assuming a leak.** Many "leaks" are intentional caches.
- Common patterns:
  - Unbounded in-memory caches (no max size, no TTL).
  - Event listeners not removed on unmount (frontend).
  - Closures holding large objects alive.
  - Long-lived connections or streams that are never closed.

```bash
# Node.js heap snapshot
node --inspect app.js
# then open chrome://inspect → Memory → Take Heap Snapshot

# Go — pprof heap
go tool pprof http://localhost:6060/debug/pprof/heap
```

---

## Benchmarking

Use a benchmarking tool appropriate to the layer:

| Layer | Tool |
|---|---|
| HTTP API | `k6`, `wrk`, `hey`, `artillery` |
| .NET code | `BenchmarkDotNet` |
| Go | `go test -bench=. -benchmem` |
| Rust | `criterion` |
| Python | `pytest-benchmark` |
| Node.js | `tinybench`, `Benchmark.js` |
| Browser | Lighthouse CI, WebPageTest |

Always benchmark in production-like conditions (same OS, similar hardware, real data volumes).

---

## What NOT to do

- Do not add a cache before profiling — you may be caching the wrong thing.
- Do not micro-optimize hot paths without measuring the impact.
- Do not optimize for throughput when the problem is latency (or vice versa).
- Do not remove `await` from async functions to "speed things up" — you'll break error handling and ordering.
- Do not enable `NOLOCK` / `READ UNCOMMITTED` as a performance hack — it trades correctness for speed.
- Do not add indexes without analyzing the query plan — over-indexing slows writes.

---

## Verification

```bash
# Lighthouse CI (frontend)
npx lhci autorun

# k6 load test (HTTP API)
k6 run --vus 50 --duration 30s load-test.js

# pg_stat_statements top queries (Postgres)
SELECT query, mean_exec_time, calls FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 20;
```

---

## Final response requirements

Always report:
- **Baseline before** the change (p50/p95 latency, or LCP/INP/CLS score, or memory usage).
- **After measurement** — the same metric, same conditions.
- **What was changed** and why it addresses the bottleneck.
- **Trade-offs introduced** (e.g., cache invalidation complexity, memory vs CPU swap).
- Commands run and profiling tools used.

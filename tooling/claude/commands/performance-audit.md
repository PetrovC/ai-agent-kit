---
description: Performance audit on the given page/endpoint/feature. Measure baseline, find bottleneck, propose fixes, verify gain.
argument-hint: <what-is-slow>
---

Audit the performance of $ARGUMENTS.

Use the `performance` skill.

── Step 1: Establish a baseline ─────────────────────────────────────────────

Measure the current state before touching anything.

Backend:
- Time the slow endpoint or function end-to-end (p50, p95, p99).
- Check the DB query plan: `EXPLAIN ANALYZE` for the slowest queries.
- Check N+1 patterns: count DB queries per request.

Frontend:
- Run Lighthouse on the affected page (Chrome DevTools or CLI).
- Record Core Web Vitals: LCP, INP, CLS targets and current values.
- Profile JS bundle size: check the largest chunks.

Document the baseline numbers — you cannot know if an optimization helped without them.

── Step 2: Identify the bottleneck ──────────────────────────────────────────

Classify the bottleneck before optimizing:

- [ ] Database — slow query, missing index, N+1, large result set
- [ ] Network — payload too large, too many requests, no compression
- [ ] Application code — inefficient algorithm, blocking I/O, excessive allocation
- [ ] Frontend rendering — large JS bundle, render-blocking resources, layout thrash
- [ ] Caching — missing cache layer, low hit rate, cache stampede

Profile one layer at a time. The biggest bottleneck first.

── Step 3: Propose targeted fixes ───────────────────────────────────────────

For each bottleneck found:
- State the problem precisely.
- Propose the smallest change that fixes it.
- Estimate the expected gain (order-of-magnitude is fine).
- State any trade-offs.

Do NOT optimize without a clear bottleneck identified.

── Step 4: Apply and re-measure ─────────────────────────────────────────────

After each change:
- Re-run the same benchmark / Lighthouse run / query EXPLAIN.
- Compare to the baseline. Report actual gain, not estimated.
- If the gain is < 10%, question whether the change is worth the complexity.

── Report ────────────────────────────────────────────────────────────────────

1. Baseline numbers (p50/p95 latency, Lighthouse scores, query time).
2. Bottleneck identified (layer + root cause).
3. Changes applied (one per bottleneck).
4. Results after change (actual measured improvement).
5. Follow-up items (optimizations not applied in this pass, with estimated effort).

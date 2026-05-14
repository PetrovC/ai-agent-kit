# Prompt: On-call Incident Investigation

> Use when you are investigating a live incident or outage. Work through each step in order.
> Speed matters — triage before deep-dive.

```
We have a live incident. Use the observability skill.

Symptoms: [DESCRIBE WHAT IS BROKEN OR DEGRADED — error messages, affected users, dashboard link]

── Step 1: Triage (5 minutes max) ──────────────────────────────────────────

Answer these before going deeper:
- Is this a complete outage or partial/degraded service?
- What % of users or requests are affected?
- Is the impact growing, stable, or recovering?
- What changed in the last 2 hours? (deploys, config, traffic spikes, upstream changes)

If a quick rollback or feature flag can stop the bleeding: do it first, investigate second.

── Step 2: Narrow the scope ─────────────────────────────────────────────────

- Compare error rate (last 1h) vs baseline (same window yesterday).
- Check per-service / per-endpoint breakdown — is it one endpoint or all?
- Check infra signals: DB connection pool, cache hit rate, queue depth, CPU/memory.
- Check downstream dependencies: is an upstream or third-party API degraded?

── Step 3: Identify root cause ──────────────────────────────────────────────

- Read the most recent error traces in detail — find the first failure, not a cascade symptom.
- Cross-reference with deploy history: did a specific commit or config change correlate?
- Check if the failure is local to one pod/region or systemic.

── Step 4: Mitigate ─────────────────────────────────────────────────────────

Apply the smallest effective mitigation first:
  1. Rollback the last deploy if it correlates.
  2. Scale up if it is a capacity problem.
  3. Toggle a feature flag to disable the broken path.
  4. Add a circuit breaker / rate limit if an upstream is cascading.

Do not refactor under pressure. Restore first.

── Step 5: Post-incident write-up ───────────────────────────────────────────

Once stable, document:
1. Timeline: when it started, when detected, when mitigated, when resolved.
2. Root cause: one clear sentence.
3. Impact: users/requests affected, SLO breach (yes/no), revenue/reputation risk.
4. Fix applied: what was done and when.
5. Follow-up tickets:
   - Permanent fix (if mitigation was a workaround).
   - Monitoring gap: what alert would have caught this 10 minutes earlier?
   - Test gap: what test would have caught this in CI?
```

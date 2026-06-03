# Agent Audit Storage — Layout Reference

On-demand companion to [AGENT_AUDIT_STORAGE.md](../AGENT_AUDIT_STORAGE.md): the
full central directory tree, index/rollup record details, the report-reading
workflow, and fixture expectations. The core doc holds the storage directives
(branch strategy, naming, required artifacts, consent, official mode).

## Central Layout

The central repository stores audit data under `agent-audit/`.

```text
agent-audit/
  README.md
  policy/
    README.md
  indexes/
    README.md
    years/
      YYYY.json
    months/
      YYYY-MM.json
    projects/
      project-hash.json
  rollups/
    cross-run-rollup.json
    cross-run-rollup.md
  runs/
    YYYY/
      MM/
        project-hash/
          run-id/
            README.md
            run-summary.json
            governance-events.ndjson
            token-context.json
            agent-invocations.json
            friction.json
            activity.json
            report-quality.json
            governance-recommendations.json
            pricing-estimate.json
            recommendations.md
```

`master` may contain anonymized fixtures that use this layout. Real generated
run data belongs on `agent-audit-data`.

## Index Layout

Indexes are generated convenience files. They must contain only data already
safe to store in run artifacts.

| Path | Purpose |
|---|---|
| `indexes/years/YYYY.json` | One year of run-summary pointers and aggregate counters. |
| `indexes/months/YYYY-MM.json` | One month of run-summary pointers and aggregate counters. |
| `indexes/projects/project-hash.json` | Runs for one anonymized project hash. |

Index records should include:

- `schema_version`;
- index period or project hash;
- generated timestamp;
- run count;
- aggregate task type, technical scope, status, and token estimate buckets;
- relative pointers to `run-summary.json` files.

Index records must not copy raw report text, recommendations, command output,
file names, file paths, prompts, responses, or branch names.

## Rollup Layout

Cross-run calibration rollups are generated convenience files produced by
`rollup` (see the agent-audit runtime). They aggregate ACROSS finalized runs —
quality, model-fit distribution, tokens, cache-hit, speed, cost, context
exhaustion, retries, and noise hotspots — grouped by project hash, agent
category, and task type. They are the lever to calibrate `MODEL_ROUTING.md`,
subagent assignments, and agent usage.

| Path | Purpose |
|---|---|
| `rollups/cross-run-rollup.json` | Machine-readable cross-run aggregate (canonical). |
| `rollups/cross-run-rollup.md` | Human-readable companion for maintainers. |

The rollup JSON also carries two cross-run sections:

- `skill_usage` — total skill activations and a per-skill distribution, sourced
  from `skill.activated` events (`run-summary.json` → `skill_usage`). This makes
  skill usage measurable across runs.
- `findings` — per-run `governance-recommendations.json` aggregated across runs
  by `(category, summary_code)`, with occurrence and affected-run counts, the
  strongest evidence/confidence seen, and an `issue_candidate`. **Issue creation
  stays manual:** a finding only flags a candidate (when a recommendation already
  flagged it, evidence/confidence is high, or the pattern repeats across runs) —
  the generator never opens an issue.

Like indexes, rollups contain only data already safe to store in run artifacts
(numeric aggregates and enum distributions); they must not copy raw report text,
prompts, responses, command output, file paths, or branch names. The rollup
generator is read-only over run folders and never rewrites them.

## Reading Reports to Improve the Architecture

The audit pays off only when its reports drive concrete changes. Read them in
this order:

1. **Per-run `report-quality.json`** — was the report accepted, and was the model
   fit appropriate? An `underpowered`/`overkill` `model_fit` with strong evidence
   is a routing signal; `observed_model_tier` vs `expected_model_tier` shows the
   gap.
2. **Cross-run `rollups/cross-run-rollup.json`** — the calibration lever:
   - `by_task_type` / `by_agent` model-fit distributions reveal which task classes
     or agents are routinely under- or over-powered → adjust `MODEL_ROUTING.md`
     and the per-subagent model assignments.
   - `context_exhaustion.rate` and `noise_hotspots` show where prompts/scope waste
     context → tighten skill instructions or split work.
   - `tokens` / `cost` / `cache_hit` per group show where efficiency work pays off.
   - `skill_usage` shows which skills actually fire → prune unused skills, fix
     under-triggering descriptions.
3. **`findings`** — the actionable shortlist. Each issue candidate is safe for a
   human to review and, if warranted, turn into a GitHub issue manually. Cite the
   finding's `summary_code`, `affected_run_count`, and evidence in the issue.

Calibration is a loop: change a policy, let new runs accumulate, re-run `rollup`,
and confirm the distribution moved in the intended direction before the next
change.

## Fixture Expectations

An anonymized fixture should:

- live under the same `runs/YYYY/MM/project-hash/run-id/` layout;
- use obvious fake hashes such as `hmac_sha256_example_project`;
- include main session, at least one subagent, one retry, one escalation, token
  estimates, report quality, and recommendations;
- parse as valid JSON or NDJSON where applicable;
- avoid all forbidden M0A data, even in Markdown examples.

See [agent-audit/](../../../agent-audit/) for the repository fixture.


## External Project Ingestion Flow

Audit data produced while working in an external source project must not be
written into that source project (the directive lives in the core doc). The flow:

1. The agent runs in an external project.
2. Runtime audit metadata is buffered in a local runtime folder outside the
   source repository.
3. The runtime folder keeps any local-only mapping files and hash salts outside
   source control.
4. The final anonymized report is written to the central audit repository under
   `agent-audit/runs/YYYY/MM/project-hash/run-id/`.
5. The writer switches to or targets `agent-audit-data` before committing audit
   run data.
6. Generated indexes are updated on `agent-audit-data`.

## Contributor-facing Consent Wording

Suggested wording for the opt-in (the consent *requirements* are in the core doc):

> This project can contribute anonymized agent audit metadata to a central
> ai-agent-kit audit repository. The report stores technical counters,
> timings, task classifications, and estimates only. It does not store prompts,
> responses, command output, file contents, exact paths, repository URLs, branch
> names, credentials, or business data. You can disable audit contribution
> without changing normal agent behavior.

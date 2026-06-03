# Agent Audit Governance

This document defines the M0C governance scoring and escalation rules for
anonymized agent audit reports. It builds on:

- [AGENT_AUDIT_SCHEMA.md](./AGENT_AUDIT_SCHEMA.md) for payload schemas and
  privacy rules;
- [AGENT_AUDIT_STORAGE.md](./AGENT_AUDIT_STORAGE.md) for storage layout;
- [MODEL_ROUTING.md](./MODEL_ROUTING.md) for model-tier expectations;
- [SUBAGENT_GOVERNANCE.md](./SUBAGENT_GOVERNANCE.md) for delegation rules and
  the active governance loop that emits the events scored here.

The scoring rules below are implemented deterministically by the audit runtime
(`finalize-run` computes `report-quality.json` and `governance-recommendations.json`
from the sanitized event stream). The runtime does not implement runtime
enforcement, provider integration, exact token gates, hard model blocking,
automatic policy edits, or automatic issue creation; those remain advisory and
require human review.

## Governance Inputs

Governance decisions must be computable from sanitized audit metadata:

- task profile: type, scope, risk, complexity, expected outputs;
- invocation metadata: agent category, model tier, status, duration, retry and
  escalation links;
- token and context estimates;
- activity counters: read/write/search/test/git calls, large output counters,
  extension buckets, and technical area buckets;
- friction counters: retries, blockers, rework, wasted context estimates, and
  stop reason;
- validation state and report-quality fields.

Governance decisions must not require raw prompts, responses, command output,
source code, file contents, exact paths, repository URLs, branch names, issue
titles, or business data.

## Report Quality Score

`report-quality.json` uses a 0 to 10 score where higher is better.

| Score range | Category | Default action |
|---:|---|---|
| `8.0` to `10.0` | `accepted` | Accept the report. |
| `6.0` to `7.9` | `weak` | Request repair when the gap is small and local. |
| `3.0` to `5.9` | `unusable` | Retry with narrower scope or escalate when evidence supports it. |
| `0.0` to `2.9` | `failed` | Reject the report and consider stopping. |

### Scoring Criteria

Start from `10.0` and subtract bounded penalties. Scores are rounded to one
decimal place.

| Criterion | Penalty | Evidence |
|---|---:|---|
| Missing direct answer to assigned task | `-3.0` | `result_kind`, acceptance checklist, or reviewer verdict. |
| Missing evidence for claims | `-2.0` | Findings lack file, test, schema, command, or artifact references allowed by privacy policy. |
| Missing next action when action is expected | `-1.5` | Expected output includes `review_report`, `issue_update`, `pr`, or `release_artifact`. |
| Unsafe or non-anonymized detail attempted | `-4.0` | Privacy redaction dropped fields or detected forbidden data. |
| Excessive noise or off-scope material | `-2.0` | Noise score is high or activity counters show broad low-value work. |
| Unverified conclusion where validation was possible | `-1.5` | Tests, parse checks, or lint checks were skipped without a safe reason. |
| Duplicated prior report without new evidence | `-2.0` | Retry report repeats the same result summary and evidence counters. |
| Contradictory status or incomplete artifact links | `-2.0` | Status says success but required artifacts or references are missing. |

Real run signals are authoritative over the agent's self-assessment. A failed
validation is a reviewer verdict that the assigned task was not answered (it
triggers `missing_direct_answer` even when the agent self-reported success); a
skipped validation triggers `unverified_conclusion`; and a recorded blocker
means a next action is expected (so a missing next action is penalized). The
self-assessment flags (`answered_assigned_task`, `has_sanitized_evidence`,
`has_next_action`) remain optional inputs the governing model may emit at the
checkpoint.

Required evidence for acceptance:

- assigned task category is represented;
- scope inspected or artifact inspected is summarized with allowed metadata;
- findings, if any, include sanitized evidence;
- validation state is present or explicitly unavailable;
- next action is present when the report asks for human or agent follow-up;
- privacy status is `complete` or a safe `partial` with dropped-field count.

Worked accepted/weak/failed scoring examples are in the
[scoring reference](./references/governance-scoring.md#report-quality--examples).

### Agent Self-Evaluation (optional)

At the mandatory checkpoint the governing model may emit `report.evaluated` with
its own `quality_category`. This self-evaluation is optional and advisory: it is
surfaced in `report-quality.json` under `agent_self_evaluation` (with an
`agrees_with_score` flag comparing it to the deterministic category) but never
overrides the computed score. A persistent disagreement across runs is itself a
signal worth aggregating. When no checkpoint evaluation was emitted, the field is
`null`.

## Noise Score Formula

`noise_score` is a deterministic 0–10 score (higher = more avoidable context
waste), separate from `quality_score` — a report can be correct but noisy.
Thresholds: `0.0–2.9` low, `3.0–5.9` medium, `6.0–10.0` high; create a governance
recommendation when high noise repeats. The six bounded components (repeated
reads, large output, retries, extra subagents, verbosity vs
`target_report_tokens`, scope churn), their exact coefficients, and worked
low/high examples are in the
[scoring reference](./references/governance-scoring.md#noise-score-formula). Noise
lowers `quality_score` only when it hides evidence, omits next actions, or
consumes context without answering the task.

## Retry, Repair, Escalate, And Stop Rules

Governance decisions are explicit control-flow choices.

| Decision | Use when | Limits |
|---|---|---|
| `accept` | Quality is `accepted` and required evidence is present. | None. |
| `repair` | Quality is `weak`, the report is mostly correct, and the missing part is small. | One repair request per invocation. |
| `retry_narrower` | Quality is `unusable` because the scope was broad, noisy, or ambiguous. | One narrower retry per failed scope. |
| `escalate_model` | Quality is `unusable` or `failed` on decision-bearing work and evidence suggests the model tier was too weak. | One escalation per task unless the user explicitly continues. |
| `reject` | Quality is `failed`, unsafe, or unrelated to the assignment. | Record reason. |
| `stop` | Repeated attempts fail, privacy cannot be proven, validation is blocked, or cost/noise is no longer justified. | Stop after the configured maximum attempts. |

Maximum retry expectations:

- request at most one repair for a weak report;
- retry at most once with narrower scope before escalating or stopping;
- escalate at most once for the same technical question;
- stop after three consecutive weak, unusable, or failed outputs for the same
  blocker;
- stop immediately when privacy redaction cannot make the artifact safe.

Escalation requires evidence. Valid evidence includes:

- high task risk or decision-bearing category;
- missing or incorrect reasoning in a lower-tier report;
- repeated weak output after scope narrowing;
- validation failure that the lower-tier output did not address;
- security, architecture, or review work attempted by a cheap or fast tier.

Each decision should be logged as:

- a `governance-events.ndjson` event such as `report.evaluated`,
  `retry.requested`, `escalation.started`, or `recommendation.created`;
- updated counters in `friction.json`;
- a decision record in `report-quality.json` when evaluating a report.

## Model Fit Detection

Model-fit findings are **advisory** — they never hard-block a model choice or
edit policy. The observed tier comes from the real model id in `session.metrics`
(`opus`/`pro` → `review`, `sonnet` → `standard`, `haiku`/`flash` → `fast`; Codex
falls back to an emitted `observed_model_tier`); the expected tier comes from
task type, risk, and agent category. `underpowered` and `overkill` each require
concrete run-level evidence before any policy recommendation. The expected-tier
table, the full underpowered/overkill signal lists, the evidence requirements,
and examples are in the
[scoring reference](./references/governance-scoring.md#model-fit-detection).

## Governance Recommendations

Recommendations are machine-readable in `governance-recommendations.json`
(categories: `model_routing`, `prompt_scope`, `subagent_policy`, `validation`,
`privacy`, `storage`, `pricing`, `context_management`, `testing`,
`documentation`). A recommendation should become a new issue when evidence
strength is `strong`, confidence is `high`, it affects policy / security /
privacy / CI / default model routing, or repeated moderate evidence appears
across runs. **Automatic issue creation stays out of scope** — every
recommendation must be safe for a human to review and decide. The full field
table, the `report-quality.json` schema, and examples are in the
[scoring reference](./references/governance-scoring.md#governance-recommendation-format).

## Issue Coverage

| Issue | Covered by |
|---|---|
| [#274](https://github.com/PetrovC/ai-agent-kit/issues/274) | Report quality score range, criteria, categories, required evidence, noise impact, and examples. |
| [#275](https://github.com/PetrovC/ai-agent-kit/issues/275) | Repair, retry, escalation, stop rules, maximum attempts, evidence requirements, and logging. |
| [#276](https://github.com/PetrovC/ai-agent-kit/issues/276) | Overkill and underpowered model detection tied to task type, risk, complexity, outcome, and confidence. |
| [#277](https://github.com/PetrovC/ai-agent-kit/issues/277) | Machine-readable governance recommendation format and issue-candidate rules. |
| [#287](https://github.com/PetrovC/ai-agent-kit/issues/287) | Deterministic noise score formula, thresholds, metadata-only inputs, and examples. |

## Related Documents

- [Scoring reference](./references/governance-scoring.md) — worked examples, the
  full noise formula, model-fit signal lists, recommendation fields, and the
  `report-quality.json` schema.
- [AGENT_AUDIT_SCHEMA.md](./AGENT_AUDIT_SCHEMA.md) · [AGENT_AUDIT_STORAGE.md](./AGENT_AUDIT_STORAGE.md) · [SUBAGENT_GOVERNANCE.md](./SUBAGENT_GOVERNANCE.md) · [MODEL_ROUTING.md](./MODEL_ROUTING.md)

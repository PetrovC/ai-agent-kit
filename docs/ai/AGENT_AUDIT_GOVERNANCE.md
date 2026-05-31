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

Required evidence for acceptance:

- assigned task category is represented;
- scope inspected or artifact inspected is summarized with allowed metadata;
- findings, if any, include sanitized evidence;
- validation state is present or explicitly unavailable;
- next action is present when the report asks for human or agent follow-up;
- privacy status is `complete` or a safe `partial` with dropped-field count.

### Examples

The example scores below are computed from the penalty table above (start at
`10.0`, subtract the listed penalties, round to one decimal), so they match the
deterministic runtime output.

Accepted report (no penalties apply):

```json
{
  "quality_score": 10.0,
  "quality_category": "accepted",
  "default_action": "accept",
  "weaknesses": [],
  "evidence": {
    "answered_assigned_task": true,
    "has_sanitized_evidence": true,
    "has_next_action": true,
    "validation_state": "passed",
    "privacy_status": "complete"
  }
}
```

Weak report (`-2.0` missing evidence, `-1.5` missing next action → `6.5`):

```json
{
  "quality_score": 6.5,
  "quality_category": "weak",
  "default_action": "repair",
  "weaknesses": ["missing_evidence", "missing_next_action"],
  "repair_request": {
    "repair_scope": "add_evidence_and_next_action",
    "max_attempts": 1
  }
}
```

Failed report (`-3.0` no direct answer, `-2.0` missing evidence, `-2.0`
excessive noise, `-2.0` contradictory status → `1.0`):

```json
{
  "quality_score": 1.0,
  "quality_category": "failed",
  "default_action": "reject",
  "weaknesses": [
    "missing_direct_answer",
    "missing_evidence",
    "excessive_noise",
    "contradictory_status"
  ],
  "stop_recommended": true
}
```

## Noise Score Formula

`noise_score` is a deterministic 0 to 10 score where higher means more avoidable
context waste. It is separate from `quality_score`: a report can be correct but
noisy, or concise but wrong.

Formula:

```text
noise_score =
  min(10,
      repeated_read_component
    + large_output_component
    + retry_component
    + subagent_component
    + verbosity_component
    + scope_churn_component)
```

All components use stored metadata only.
For formula inputs, booleans are `1` for true and `0` for false.
`target_report_tokens` must be a positive configured target; if unavailable,
the verbosity component should be recorded as unavailable instead of guessed.

| Component | Formula | Maximum |
|---|---|---:|
| `repeated_read_component` | `min(2.0, repeated_read_count * 0.4)` | `2.0` |
| `large_output_component` | `min(2.0, large_output_event_count * 0.7 + truncated_output_count * 0.5)` | `2.0` |
| `retry_component` | `min(2.0, retry_count * 0.8)` | `2.0` |
| `subagent_component` | `min(1.5, max(0, subagent_invocation_count - expected_subagent_count) * 0.5)` | `1.5` |
| `verbosity_component` | `min(1.5, max(0, report_tokens - target_report_tokens) / target_report_tokens)` | `1.5` |
| `scope_churn_component` | `min(1.0, scope_narrowing_count * 0.5 + rework_detected * 0.5)` | `1.0` |

Thresholds:

| Noise score | Level | Meaning |
|---:|---|---|
| `0.0` to `2.9` | `low` | Normal exploration and reporting. |
| `3.0` to `5.9` | `medium` | Some avoidable context waste; consider narrower prompts or better tool filtering. |
| `6.0` to `10.0` | `high` | Significant avoidable waste; create a governance recommendation when evidence repeats. |

Low-noise example (computed from the formula above):

```json
{
  "noise_score": 0.4,
  "noise_level": "low",
  "inputs": {
    "repeated_read_count": 1,
    "large_output_event_count": 0,
    "retry_count": 0,
    "subagent_invocation_count": 1,
    "expected_subagent_count": 1,
    "report_tokens": 900,
    "target_report_tokens": 1200,
    "scope_narrowing_count": 0,
    "rework_detected": false
  }
}
```

High-noise example (computed from the formula above):

```json
{
  "noise_score": 9.1,
  "noise_level": "high",
  "inputs": {
    "repeated_read_count": 4,
    "large_output_event_count": 2,
    "truncated_output_count": 1,
    "retry_count": 2,
    "subagent_invocation_count": 5,
    "expected_subagent_count": 2,
    "report_tokens": 3600,
    "target_report_tokens": 1200,
    "scope_narrowing_count": 1,
    "rework_detected": true
  }
}
```

Noise affects quality when it hides evidence, omits next actions, or consumes
context without answering the task. Otherwise, record it as a governance signal
without lowering the quality score.

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

Example:

```json
{
  "decision": "retry_narrower",
  "reason": "scope_too_broad",
  "quality_score": 5.4,
  "noise_score": 6.1,
  "max_attempts_remaining": 1,
  "log_events": ["report.evaluated", "retry.requested"]
}
```

## Model Fit Detection

Model fit recommendations are advisory. They do not hard-block model choices or
edit model policy automatically.

### Expected Tier By Task

| Task signal | Expected tier |
|---|---|
| Security review, architecture review, PR review, decision-bearing investigation | `deep` or `review` |
| Normal bug fix, test repair, documentation update, straightforward feature implementation | `standard` |
| Formatting, fixture updates, simple mechanical edits, parse-only validation | `fast` or `standard` |

Risk and complexity can raise the expected tier. Low risk and mechanical output
can lower it.

### Underpowered Signals

Underpowered model usage may be present when:

- model tier is below expected tier for task risk and category;
- quality category is `unusable` or `failed`;
- retry or escalation was needed for reasoning quality rather than missing
  context;
- validation failed due to flawed reasoning, incomplete review, or unsupported
  conclusion;
- a higher-tier retry succeeded on the same narrowed task.

Cheap model failure example:

```json
{
  "model_fit": "underpowered",
  "confidence": "high",
  "evidence_strength": "strong",
  "task_type": "security_review",
  "risk_level": "high",
  "observed_model_tier": "fast",
  "expected_model_tier": "review",
  "observed_failures": ["missing_evidence", "incorrect_risk_assessment"],
  "follow_up": "recommend_policy_review"
}
```

### Overkill Signals

Overkill model usage may be present when:

- model tier is above expected tier for low-risk mechanical work;
- quality is accepted without retries, escalation, or complex reasoning;
- validation was deterministic and cheap;
- output was small, structured, and easy to verify;
- repeated evidence across runs shows a lower tier succeeds for the same task
  class.

Strong model overuse example:

```json
{
  "model_fit": "overkill",
  "confidence": "medium",
  "evidence_strength": "moderate",
  "task_type": "docs_update",
  "risk_level": "low",
  "complexity": "trivial",
  "observed_model_tier": "deep",
  "expected_model_tier": "standard",
  "observed_outcome": "accepted_without_retry",
  "follow_up": "aggregate_more_runs"
}
```

Evidence required before recommending policy changes:

- at least one concrete run-level model-fit record;
- task type, risk, complexity, observed tier, and expected tier;
- outcome and quality category;
- retry, escalation, and validation state;
- confidence and evidence strength;
- human review requirement.

## Governance Recommendation Format

Recommendations are structured and machine-readable in
`governance-recommendations.json`. A sanitized `recommendations.md` may exist as
a human-readable companion, but the JSON file is canonical for aggregation.

Recommendation categories:

- `model_routing`
- `prompt_scope`
- `subagent_policy`
- `validation`
- `privacy`
- `storage`
- `pricing`
- `context_management`
- `testing`
- `documentation`

Evidence strength values:

- `weak`: one noisy signal or incomplete evidence;
- `moderate`: one clear run or repeated weak signals;
- `strong`: repeated clear signals or one high-risk validated failure.

Confidence values:

- `low`
- `medium`
- `high`

Fields:

| Field | Type | Notes |
|---|---|---|
| `recommendation_id` | string | Opaque id unique within the run. |
| `category` | enum | Recommendation category. |
| `summary_code` | string | Controlled short code, not free-form project text. |
| `recommended_action` | enum | `open_issue`, `review_policy`, `tighten_prompt`, `lower_model_tier`, `raise_model_tier`, `add_validation`, `monitor`, `no_action`. |
| `evidence_strength` | enum | `weak`, `moderate`, `strong`. |
| `confidence` | enum | `low`, `medium`, `high`. |
| `human_review_required` | boolean | Always true for policy changes. |
| `task_type` | string | Sanitized task classification link. |
| `agent_category` | string | Related agent category when applicable. |
| `observed_model_tier` | string | Related tier when applicable. |
| `observed_failures` | string array | Controlled failure codes. |
| `supporting_event_ids` | string array | Event ids from `governance-events.ndjson`. |
| `supporting_invocation_ids` | string array | Invocation ids from `agent-invocations.json`. |
| `issue_candidate` | object | Whether this should become a new issue. |

Example:

```json
{
  "schema_version": "0.1.0",
  "recommendations": [
    {
      "recommendation_id": "rec_001",
      "category": "model_routing",
      "summary_code": "raise_tier_for_high_risk_review",
      "recommended_action": "review_policy",
      "evidence_strength": "strong",
      "confidence": "high",
      "human_review_required": true,
      "task_type": "security_review",
      "agent_category": "security",
      "observed_model_tier": "fast",
      "observed_failures": ["missing_evidence", "retry_required"],
      "supporting_event_ids": ["evt_004", "evt_006"],
      "supporting_invocation_ids": ["inv_002", "inv_004"],
      "issue_candidate": {
        "should_open_issue": true,
        "reason": "repeated_high_risk_failure",
        "suggested_issue_type": "docs"
      }
    }
  ]
}
```

A recommendation should become a new issue when:

- evidence strength is `strong`; or
- confidence is `high`; or
- the recommendation affects policy, security, privacy, CI, or default model
  routing; or
- repeated moderate evidence appears across multiple runs.

Automatic issue creation remains out of scope. The recommendation should be
safe for a human to review manually and decide.

## `report-quality.json`

Recommended fields:

| Field | Type | Notes |
|---|---|---|
| `quality_score` | number | 0 to 10. |
| `quality_category` | enum | `accepted`, `weak`, `unusable`, `failed`. |
| `default_action` | enum | `accept`, `repair`, `retry_narrower`, `escalate_model`, `reject`, `stop`. |
| `weaknesses` | string array | Controlled penalty codes that lowered the score. |
| `noise_score` | number | 0 to 10. |
| `noise_level` | enum | `low`, `medium`, `high`. |
| `noise_components` | object | Per-component noise contributions; `verbosity_component` is `null` when the token target is unavailable. |
| `noise_inputs` | object | The metadata-only inputs used by the noise formula. |
| `model_fit` | enum | `appropriate`, `overkill`, `underpowered`, `unknown`. |
| `evidence_strength` | enum | `weak`, `moderate`, `strong`. |
| `confidence` | enum | `low`, `medium`, `high`. |
| `decision_log` | array | Sanitized governance decisions. |
| `warnings` | array | Controlled warnings. |

Example:

```json
{
  "schema_version": "0.1.0",
  "quality_score": 10.0,
  "quality_category": "accepted",
  "default_action": "accept",
  "weaknesses": [],
  "noise_score": 2.1,
  "noise_level": "low",
  "model_fit": "appropriate",
  "evidence_strength": "moderate",
  "confidence": "medium",
  "decision_log": [
    {
      "decision": "accept",
      "reason": "required_evidence_present"
    }
  ],
  "warnings": []
}
```

## Issue Coverage

| Issue | Covered by |
|---|---|
| [#274](https://github.com/PetrovC/ai-agent-kit/issues/274) | Report quality score range, criteria, categories, required evidence, noise impact, and examples. |
| [#275](https://github.com/PetrovC/ai-agent-kit/issues/275) | Repair, retry, escalation, stop rules, maximum attempts, evidence requirements, and logging. |
| [#276](https://github.com/PetrovC/ai-agent-kit/issues/276) | Overkill and underpowered model detection tied to task type, risk, complexity, outcome, and confidence. |
| [#277](https://github.com/PetrovC/ai-agent-kit/issues/277) | Machine-readable governance recommendation format and issue-candidate rules. |
| [#287](https://github.com/PetrovC/ai-agent-kit/issues/287) | Deterministic noise score formula, thresholds, metadata-only inputs, and examples. |

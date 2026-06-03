# Agent Audit Governance — Scoring Reference

On-demand companion to [AGENT_AUDIT_GOVERNANCE.md](../AGENT_AUDIT_GOVERNANCE.md):
worked scoring examples and the exhaustive formulas, signal lists, field tables,
and JSON schemas. The core doc holds the directives an agent applies first; load
this when you need exact coefficients, field definitions, or examples.

## Report Quality — Examples

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


## Model Fit Detection

Model fit recommendations are advisory. They do not hard-block model choices or
edit model policy automatically.

The observed tier is derived from the real model id captured in `session.metrics`
(see [AGENT_AUDIT_SCHEMA.md](../AGENT_AUDIT_SCHEMA.md)), mapped to a routing tier
(`opus`/`pro` → `review`, `sonnet` → `standard`, `haiku`/`flash` → `fast`). When
the model id is unmappable — notably Codex, where every profile shares one model
id and only `model_reasoning_effort` differs — detection falls back to an
explicitly emitted `observed_model_tier`. The expected tier comes from task type,
risk, and agent category. A blocker counts as a recovery signal alongside retries
and escalations.

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


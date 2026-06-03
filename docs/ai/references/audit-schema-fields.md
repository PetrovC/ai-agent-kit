# Agent Audit Schema — Field Reference

On-demand companion to [AGENT_AUDIT_SCHEMA.md](../AGENT_AUDIT_SCHEMA.md): the
full per-artifact field tables and anonymized examples. The core doc holds the
privacy contract, classification, and artifact set; load this only when you
need exact field definitions.

## `run-summary.json`

`run-summary.json` is the top-level index record for one run.

| Field | Type | Required | Notes |
|---|---|---:|---|
| `schema_version` | string | Yes | Semantic schema version, for example `0.1.0`. |
| `audit_run_id` | string | Yes | Random UUID or equivalent opaque id. |
| `generated_at` | string | Yes | UTC timestamp for the audit artifact, not a project timestamp. |
| `project_ref` | object | Yes | Anonymous project reference. |
| `source_ref` | object | No | Anonymous source reference for issue, PR, local task, or CI run. |
| `task_profile` | object | Yes | Task classification object. |
| `status` | enum | Yes | `completed`, `completed_with_warnings`, `blocked`, `failed`, `stopped`. |
| `outcome` | object | Yes | Result counters and validation state. |
| `duration_ms` | integer | No | Whole-run duration. |
| `usage_summary` | object | No | Compact token/context totals. |
| `activity_summary` | object | No | Compact tool/file counters. |
| `friction_summary` | object | No | Compact retry/blocker/escalation counters. |
| `artifacts` | object | Yes | Relative artifact file names. |
| `privacy` | object | Yes | Redaction and dropped-field metadata. |

Example:

```json
{
  "schema_version": "0.1.0",
  "audit_run_id": "run_7f4c9a1d2b6e4a90",
  "generated_at": "2026-05-28T12:00:00Z",
  "project_ref": {
    "project_hash": "hmac_sha256:4f7b7b4e2c2a",
    "hash_salt_scope": "local-only",
    "project_kind": "repository"
  },
  "source_ref": {
    "source_kind": "github_issue",
    "source_hash": "hmac_sha256:0f4d7a7c2d11"
  },
  "task_profile": {
    "task_type": "docs_update",
    "task_subtype": "schema_definition",
    "technical_scopes": ["docs", "ai"],
    "stack_ids": ["markdown", "json"],
    "risk_level": "low",
    "complexity": "medium",
    "expected_outputs": ["docs", "pr"]
  },
  "status": "completed",
  "outcome": {
    "validation_state": "passed",
    "tests_run_count": 1,
    "recommendation_count": 2,
    "pr_created": true,
    "merged": false
  },
  "duration_ms": 842000,
  "usage_summary": {
    "measurement_mode": "estimated",
    "confidence": "medium",
    "total_tokens": 52000,
    "peak_context_ratio": 0.41
  },
  "activity_summary": {
    "tool_call_count": 18,
    "file_read_count": 7,
    "file_write_count": 1
  },
  "friction_summary": {
    "retry_count": 1,
    "blocker_count": 0,
    "escalation_count": 0
  },
  "artifacts": {
    "events": "governance-events.ndjson",
    "token_context": "token-context.json",
    "invocations": "agent-invocations.json",
    "friction": "friction.json",
    "activity": "activity.json",
    "pricing": "pricing-estimate.json"
  },
  "privacy": {
    "redaction_status": "complete",
    "dropped_field_count": 0,
    "contains_raw_content": false,
    "exact_paths_allowed": false
  }
}
```

## `token-context.json`

Token and context records must separate exact measurements from estimates.

| Field | Type | Notes |
|---|---|---|
| `measurement_mode` | enum | `exact`, `estimated`, `mixed`, `unavailable`; transcript imports add `imported-transcript` (full provider usage), `imported-transcript-structural` (counts only), `unsupported-format`. |
| `confidence` | enum | `high`, `medium`, `low`, `unavailable` (transcript imports use `measured` or `structural`). |
| `provider_usage_available` | boolean | Whether exact provider usage was available. |
| `main_session` | object | Main-session token buckets. |
| `subagents` | array | One record per invocation or aggregated agent category. |
| `context_window` | object | Context size, start, peak, end, pressure thresholds. |
| `compression` | object | Recommended and executed compaction/compression counts. |
| `waste_estimate` | object | Estimated rework or discarded-context tokens. |

> `import-session-metrics` emits a flatter, provider-dependent variant rooted at
> `tokens` (`input`/`output`/`cache_creation`/`cache_read`/`total`/`cache_hit_ratio`),
> adding `reasoning` and `rate_limit` (session-budget %) when the provider reports
> them (Codex), and `context.step_count`/`generation_count` for structural-only
> imports (Antigravity).

Token bucket fields:

- `input_tokens`
- `output_tokens`
- `tool_call_tokens`
- `tool_result_tokens`
- `report_tokens`
- `total_tokens`

Example:

```json
{
  "schema_version": "0.1.0",
  "measurement_mode": "estimated",
  "confidence": "medium",
  "provider_usage_available": false,
  "main_session": {
    "input_tokens": 29000,
    "output_tokens": 7000,
    "tool_call_tokens": 2000,
    "tool_result_tokens": 12000,
    "report_tokens": 2000,
    "total_tokens": 52000
  },
  "subagents": [
    {
      "invocation_id": "inv_02",
      "agent_category": "code-review",
      "measurement_mode": "estimated",
      "input_tokens": 9000,
      "output_tokens": 1800,
      "tool_result_tokens": 4000,
      "total_tokens": 14800
    }
  ],
  "context_window": {
    "window_tokens": 128000,
    "start_tokens_estimate": 18000,
    "peak_tokens_estimate": 53000,
    "end_tokens_estimate": 42000,
    "peak_context_ratio": 0.41,
    "pressure_thresholds": {
      "notice_ratio": 0.5,
      "compact_ratio": 0.7,
      "critical_ratio": 0.85
    }
  },
  "compression": {
    "recommended_count": 0,
    "executed_count": 0
  },
  "waste_estimate": {
    "measurement_mode": "estimated",
    "rework_tokens": 2500,
    "discarded_tool_output_tokens": 1200
  }
}
```

## `agent-invocations.json`

Invocation records cover the main agent and any subagents. Assigned work and
results must be represented as controlled metadata, not raw task text.

| Field | Type | Notes |
|---|---|---|
| `invocation_id` | string | Opaque id unique within the run. |
| `parent_invocation_id` | string or null | Parent invocation when nested. |
| `agent_key` | string | Generic agent identifier, for example `main`, `code-reviewer`, `test-runner`. |
| `agent_category` | enum | `main`, `investigation`, `test`, `review`, `security`, `architecture`, `implementation`, `other`. |
| `provider` | enum | Tool/provider family such as `codex`, `claude`, `agy`, `other`. |
| `model_tier` | enum | `fast`, `standard`, `deep`, `review`, `unknown`; avoid storing unstable exact model names unless policy allows it. |
| `assigned_task` | object | Sanitized task classification subset. |
| `selection_reason` | enum | `user_requested`, `routing_rule`, `risk_level`, `large_output`, `specialized_review`, `retry`, `escalation`, `other`. |
| `started_at` / `completed_at` | string | UTC timestamps. |
| `duration_ms` | integer | Invocation duration. |
| `status` | enum | `success`, `weak_output`, `retry_requested`, `escalated`, `failed`, `stopped`, `skipped`. |
| `result_summary` | object | Structured counts and result category only. |
| `retry_of_invocation_id` | string or null | Retry link. |
| `escalated_to_invocation_id` | string or null | Escalation link. |

Example:

```json
{
  "schema_version": "0.1.0",
  "invocations": [
    {
      "invocation_id": "inv_01",
      "parent_invocation_id": null,
      "agent_key": "main",
      "agent_category": "main",
      "provider": "codex",
      "model_tier": "standard",
      "assigned_task": {
        "task_type": "docs_update",
        "technical_scopes": ["docs", "ai"]
      },
      "selection_reason": "user_requested",
      "started_at": "2026-05-28T12:00:00Z",
      "completed_at": "2026-05-28T12:14:02Z",
      "duration_ms": 842000,
      "status": "success",
      "result_summary": {
        "result_kind": "artifact_updated",
        "files_changed_count": 1,
        "findings_count": 0,
        "confidence": "high"
      },
      "retry_of_invocation_id": null,
      "escalated_to_invocation_id": null
    }
  ]
}
```

## `governance-events.ndjson`

The event stream is append-only and reconstructs the governance timeline. Each
line is one JSON object. Events must use controlled payloads and must not embed
project data or raw content.

Envelope fields:

| Field | Type | Notes |
|---|---|---|
| `schema_version` | string | Event schema version. |
| `event_id` | string | Opaque id. |
| `audit_run_id` | string | Parent run id. |
| `sequence` | integer | Monotonic sequence within the run. |
| `occurred_at` | string | UTC timestamp. |
| `event_type` | enum | Event name. |
| `actor_kind` | enum | `main_agent`, `subagent`, `system`, `hook`, `ci`, `user`. |
| `invocation_id` | string or null | Related invocation id. |
| `payload` | object | Event-specific controlled metadata. |

Event types:

- `run.started`
- `run.completed`
- `task.classified`
- `agent.selected`
- `agent.invoked`
- `agent.completed`
- `model.decision`
- `report.evaluated`
- `retry.requested`
- `escalation.started`
- `recommendation.created`
- `blocker.recorded`
- `tool.observed`
- `hook.observed`
- `compact.observed`
- `session.metrics`
- `skill.activated`

`skill.activated` makes skill usage measurable: its payload carries the
controlled `skill_key` (the skill name), and nothing else is required. Per-run
counts surface in `run-summary.json` under `skill_usage`; the cross-run rollup
aggregates them by skill.

Example:

```ndjson
{"schema_version":"0.1.0","event_id":"evt_001","audit_run_id":"run_7f4c9a1d2b6e4a90","sequence":1,"occurred_at":"2026-05-28T12:00:00Z","event_type":"run.started","actor_kind":"system","invocation_id":null,"payload":{"source_kind":"github_issue","project_hash":"hmac_sha256:4f7b7b4e2c2a"}}
{"schema_version":"0.1.0","event_id":"evt_002","audit_run_id":"run_7f4c9a1d2b6e4a90","sequence":2,"occurred_at":"2026-05-28T12:00:08Z","event_type":"task.classified","actor_kind":"main_agent","invocation_id":"inv_01","payload":{"task_type":"docs_update","technical_scopes":["docs","ai"],"risk_level":"low"}}
{"schema_version":"0.1.0","event_id":"evt_003","audit_run_id":"run_7f4c9a1d2b6e4a90","sequence":3,"occurred_at":"2026-05-28T12:14:02Z","event_type":"run.completed","actor_kind":"system","invocation_id":"inv_01","payload":{"status":"completed","validation_state":"passed"}}
```

## `friction.json`

Friction records explain why work became slower, repeated, blocked, narrowed, or
escalated.

| Field | Type | Notes |
|---|---|---|
| `blockers` | array | Controlled blocker records. |
| `retry_counters` | object | Counts by retry reason. |
| `scope_narrowing` | object | Number and reason categories for narrowing. |
| `escalations` | object | Count by escalation target or reason. |
| `rework` | object | Flags and token estimates for repeated work. |
| `stop_reason` | enum | Final stop reason. |
| `wasted_context_estimate` | object | Estimated tokens or time spent on failed paths. |

Blocker categories:

- `missing_context`
- `ambiguous_requirements`
- `failing_tests`
- `flaky_tests`
- `permission_denied`
- `sandbox_denied`
- `dependency_unavailable`
- `tool_unavailable`
- `merge_conflict`
- `validation_failure`
- `external_service`
- `policy_block`
- `other`

Stop reasons:

- `completed`
- `completed_with_warnings`
- `user_stopped`
- `budget_limit`
- `blocked`
- `ci_failed`
- `tests_failed`
- `unsafe_to_continue`
- `unavailable_dependency`
- `merged`
- `other`

Example:

```json
{
  "schema_version": "0.1.0",
  "blockers": [
    {
      "category": "sandbox_denied",
      "count": 1,
      "resolved": true,
      "resolution_kind": "user_approval"
    }
  ],
  "retry_counters": {
    "tool_retry_count": 1,
    "test_retry_count": 0,
    "implementation_retry_count": 0
  },
  "scope_narrowing": {
    "narrowing_count": 0,
    "reason_categories": []
  },
  "escalations": {
    "model_escalation_count": 0,
    "human_approval_count": 1,
    "specialist_agent_count": 0
  },
  "rework": {
    "rework_detected": false,
    "reworked_files_bucket": "none",
    "rework_token_estimate": 0
  },
  "wasted_context_estimate": {
    "measurement_mode": "estimated",
    "confidence": "low",
    "failed_attempt_tokens": 1200
  },
  "stop_reason": "completed"
}
```

## `activity.json`

Activity records store counters only. They must not store command output, exact
commands, file contents, exact paths, or exact repository structure.

| Field | Type | Notes |
|---|---|---|
| `tool_usage` | object | Counters by tool and command family. |
| `large_outputs` | object | Counts and size buckets for large outputs. |
| `file_activity` | object | Read/write/create/delete counters and buckets. |
| `technical_area_buckets` | object | Coarse area counts. |
| `path_policy` | object | Explicit statement that exact paths are forbidden. |

Tool usage counters:

- `shell_call_count`
- `search_call_count`
- `read_call_count`
- `write_call_count`
- `test_call_count`
- `git_call_count`
- `github_api_call_count`
- `browser_call_count`
- `apply_patch_count`
- `failed_tool_call_count`
- `escalated_tool_call_count`

Command families are coarse values such as `git`, `test`, `lint`, `build`,
`search`, `read`, `write`, `package_manager`, `other`.

File activity buckets:

- `extension_buckets`: file extension counts such as `.md`, `.json`, `.ps1`.
- `technical_area_buckets`: `docs`, `tests`, `ci`, `scripts`, `tooling`,
  `config`, `source`, `unknown`.
- `path_depth_buckets`: `root`, `shallow`, `medium`, `deep`.

Example:

```json
{
  "schema_version": "0.1.0",
  "tool_usage": {
    "shell_call_count": 9,
    "search_call_count": 4,
    "read_call_count": 8,
    "write_call_count": 1,
    "test_call_count": 1,
    "git_call_count": 3,
    "github_api_call_count": 2,
    "browser_call_count": 0,
    "apply_patch_count": 1,
    "failed_tool_call_count": 1,
    "escalated_tool_call_count": 1,
    "command_family_counts": {
      "git": 3,
      "search": 4,
      "read": 8,
      "test": 1,
      "write": 1
    }
  },
  "large_outputs": {
    "large_output_event_count": 0,
    "truncated_output_count": 0,
    "max_output_bucket": "small"
  },
  "file_activity": {
    "file_read_count": 8,
    "file_write_count": 1,
    "file_create_count": 1,
    "file_delete_count": 0,
    "extension_buckets": {
      ".md": 9
    },
    "path_depth_buckets": {
      "root": 0,
      "shallow": 1,
      "medium": 8,
      "deep": 0
    }
  },
  "technical_area_buckets": {
    "docs": 9,
    "tests": 0,
    "ci": 0,
    "scripts": 0,
    "tooling": 0,
    "config": 0,
    "source": 0,
    "unknown": 0
  },
  "path_policy": {
    "exact_paths_allowed": false,
    "path_hashes_allowed": false,
    "file_contents_allowed": false
  }
}
```

## `pricing-estimate.json`

Pricing is optional and approximate. Token estimates remain useful when
currency estimates are disabled, unavailable, or stale.

Do not hardcode permanent provider prices into this schema. A writer that emits
currency values must also emit the source and date of its pricing assumptions.

| Field | Type | Notes |
|---|---|---|
| `status` | enum | `disabled`, `unavailable`, `estimated`, `stale`. |
| `currency` | string | ISO currency code when estimated, for example `USD`. |
| `estimate_generated_at` | string | UTC timestamp. |
| `token_estimate_ref` | string | Relative reference to `token-context.json` or equivalent summary. |
| `pricing_table` | object | Provider, source label, source URL, observed date, stale-after date. |
| `input_cost_estimate` | number or null | Approximate value. |
| `output_cost_estimate` | number or null | Approximate value. |
| `tool_cost_estimate` | number or null | Approximate value if separately priced. |
| `total_cost_estimate` | number or null | Approximate value. |
| `warnings` | string array | Controlled warnings such as `approximate`, `stale_pricing`, `missing_provider_usage`. |

Example:

```json
{
  "schema_version": "0.1.0",
  "status": "estimated",
  "currency": "USD",
  "estimate_generated_at": "2026-05-28T12:15:00Z",
  "token_estimate_ref": "token-context.json",
  "pricing_table": {
    "provider": "example-provider",
    "source_label": "public pricing page",
    "source_url": "https://example.invalid/pricing",
    "observed_at": "2026-05-28",
    "stale_after": "2026-06-27"
  },
  "input_cost_estimate": 0.12,
  "output_cost_estimate": 0.08,
  "tool_cost_estimate": null,
  "total_cost_estimate": 0.2,
  "warnings": ["approximate", "missing_provider_usage"]
}
```

If pricing is disabled:

```json
{
  "schema_version": "0.1.0",
  "status": "disabled",
  "currency": null,
  "estimate_generated_at": "2026-05-28T12:15:00Z",
  "token_estimate_ref": "token-context.json",
  "pricing_table": null,
  "total_cost_estimate": null,
  "warnings": ["currency_estimate_disabled"]
}
```


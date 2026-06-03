# Agent Audit Schema

This document defines the M0A central anonymized data model for agent audit
runs. It is a documentation contract for future writers, validators, indexes,
and dashboards. It does not implement runtime capture, tokenizers, billing
integration, or a dashboard.

The model is intentionally privacy-first: central audit artifacts may describe
technical activity, cost shape, friction, and outcomes, but must not store
project identity, source content, prompts, responses, exact paths, repository
URLs, branch names, issue titles, command output, credentials, environment
values, or business data.

## Artifact Set

Each run may write one folder containing these machine-readable artifacts:

| Artifact | Required | Purpose |
|---|---:|---|
| `run-summary.json` | Yes | Compact overview for monthly indexes and dashboards. |
| `governance-events.ndjson` | No | Append-only event stream for reconstructing the run timeline. |
| `token-context.json` | No | Token and context usage estimates or exact provider values. |
| `agent-invocations.json` | No | Main-agent and subagent invocation records. |
| `friction.json` | No | Retries, blockers, escalations, rework, and stop reasons. |
| `activity.json` | No | Tool and file-activity counters without raw command output or paths. |
| `report-quality.json` | No | Quality, noise, model-fit, and governance decision metadata. |
| `governance-recommendations.json` | No | Machine-readable governance recommendations for human review. |
| `pricing-estimate.json` | No | Optional approximate currency estimate with staleness metadata. |

Artifacts referenced from `run-summary.json` must be relative file names inside
the same run folder, never absolute paths.

## Privacy Contract

### Allowed Metadata

| Category | Examples |
|---|---|
| Stable anonymous identity | Random run id, HMAC project hash, local-only source hash. |
| Timing | Start/end timestamps, duration buckets, tool duration totals. |
| Technical classification | Task type, scope buckets, stack identifiers, risk, complexity. |
| Counts | Tool calls, reads, writes, retries, escalations, blockers, findings. |
| Coarse file activity | Extension buckets, technical area buckets, path-depth buckets. |
| Token and context shape | Exact provider counts when available, estimates with confidence when not. |
| Outcome | Completed, stopped, failed validation, blocked, merged, not merged. |
| Approximate cost | Optional currency estimate marked approximate and tied to dated pricing assumptions. |

### Forbidden Data

Central artifacts must not contain:

- project names, repository URLs, organization names, branch names, or issue and
  pull request titles;
- prompts, model responses, review comments, command output, stack traces, file
  contents, source snippets, or generated patches;
- exact project paths, exact file paths, exact shell commands, environment
  values, credentials, tokens, API keys, database URLs, or connection strings;
- customer, product, user, incident, or business-domain identifiers;
- free-form summaries that could accidentally embed project data.

When a field cannot be populated safely, the writer must omit it or set an
explicit `unavailable` state. It must not fall back to raw text.

### Anonymization Rules

Use stable hashes only where longitudinal grouping is needed.

| Field | Rule |
|---|---|
| `project_hash` | HMAC-SHA-256 over a canonical project identifier using a local secret salt. |
| `source_hash` | HMAC-SHA-256 over the local source reference if grouping by issue or PR is needed. |
| `hash_salt_scope` | Must be `local-only`; the salt and mapping file never leave the workstation. |
| `path_hash` | Forbidden by default because hashed paths can still leak stable structure. Use buckets instead. |
| `raw_text` | Forbidden. Use controlled enums, counters, and booleans. |

Fail-safe behavior:

- drop unsafe fields before writing;
- increment `privacy.dropped_field_count`;
- set `privacy.redaction_status` to `partial` when safe metadata was dropped;
- stop writing the artifact if the writer cannot prove the payload is safe.

## Task And Technical Scope Classification

Task classification describes technical work without business terms.

| Field | Type | Allowed values |
|---|---|---|
| `task_type` | enum | `bug_fix`, `feature_implementation`, `refactor`, `docs_update`, `test_repair`, `ci_change`, `architecture_review`, `code_review`, `security_review`, `dependency_update`, `performance_work`, `release_work`, `investigation`, `other` |
| `task_subtype` | string enum | Repository-defined controlled value such as `schema_definition`, `hook_policy`, `workflow_lint`, `unit_test`, `api_contract`, `migration`, `documentation_index`. |
| `technical_scopes` | string array | `backend`, `frontend`, `api`, `database`, `ci`, `docs`, `security`, `architecture`, `tests`, `tooling`, `infrastructure`, `mobile`, `ai`, `release`, `unknown`. |
| `stack_ids` | string array | Examples: `csharp`, `dotnet-10`, `angular`, `postgresql`, `python`, `go`, `rust`, `node`, `docker`, `github-actions`, `powershell`, `bash`, `markdown`. |
| `risk_level` | enum | `low`, `medium`, `high`, `critical`. |
| `complexity` | enum | `trivial`, `small`, `medium`, `large`. |
| `expected_outputs` | string array | `code`, `tests`, `docs`, `config`, `review_report`, `pr`, `issue_update`, `release_artifact`. |

Example:

```json
{
  "task_type": "docs_update",
  "task_subtype": "schema_definition",
  "technical_scopes": ["docs", "ai", "architecture"],
  "stack_ids": ["markdown", "json"],
  "risk_level": "low",
  "complexity": "medium",
  "expected_outputs": ["docs", "pr"]
}
```

## Per-Artifact Schemas

Full field tables and anonymized examples for each artifact live in the on-demand
[field reference](./references/audit-schema-fields.md). Load it only when you need
exact field definitions; the contract above (privacy, classification, artifact
set) is what an agent needs first.

| Artifact | Fields reference |
|---|---|
| `run-summary.json` | [fields](./references/audit-schema-fields.md#run-summaryjson) |
| `token-context.json` | [fields](./references/audit-schema-fields.md#token-contextjson) |
| `agent-invocations.json` | [fields](./references/audit-schema-fields.md#agent-invocationsjson) |
| `governance-events.ndjson` | [fields](./references/audit-schema-fields.md#governance-eventsndjson) |
| `friction.json` | [fields](./references/audit-schema-fields.md#frictionjson) |
| `activity.json` | [fields](./references/audit-schema-fields.md#activityjson) |
| `pricing-estimate.json` | [fields](./references/audit-schema-fields.md#pricing-estimatejson) |

## Issue Coverage

| Issue | Covered by |
|---|---|
| [#262](https://github.com/PetrovC/ai-agent-kit/issues/262) | Privacy contract, allowed/forbidden data, stable hashing, fail-safe behavior. |
| [#263](https://github.com/PetrovC/ai-agent-kit/issues/263) | Task and technical-scope classification. |
| [#264](https://github.com/PetrovC/ai-agent-kit/issues/264) | `run-summary.json` schema and anonymized example. |
| [#265](https://github.com/PetrovC/ai-agent-kit/issues/265) | Token and context usage schema with subagent example. |
| [#266](https://github.com/PetrovC/ai-agent-kit/issues/266) | Agent invocation schema and status/retry/escalation fields. |
| [#267](https://github.com/PetrovC/ai-agent-kit/issues/267) | Governance event stream schema and example NDJSON. |
| [#268](https://github.com/PetrovC/ai-agent-kit/issues/268) | Friction, retry, blocker, escalation, rework, wasted-context, and stop-reason schema. |
| [#269](https://github.com/PetrovC/ai-agent-kit/issues/269) | Tool and file-activity metadata schema without output, contents, or exact paths. |
| [#289](https://github.com/PetrovC/ai-agent-kit/issues/289) | Optional pricing estimate policy with staleness and approximate-value warnings. |

## Related Documents

- [Field reference](./references/audit-schema-fields.md) — full per-artifact schemas

- [AGENT_AUDIT_STORAGE.md](./AGENT_AUDIT_STORAGE.md)
- [AGENT_AUDIT_GOVERNANCE.md](./AGENT_AUDIT_GOVERNANCE.md)
- [THREAT_MODEL.md](./THREAT_MODEL.md)
- [CONTEXT_SANITIZATION.md](./CONTEXT_SANITIZATION.md)
- [WORKFLOW.md](./WORKFLOW.md)

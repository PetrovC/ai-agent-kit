# Agent Audit Runtime

This document defines the M0D runtime contract for the opt-in anonymized agent
audit writer. It turns the M0A schema, M0B storage layout, and M0C governance
rules into local scripts that can record sanitized events and finalize a run
without writing audit data into the source project.

## Global Config

The runtime reads a global config from `~/.ai-agent-kit/config.json` unless
`AAK_AUDIT_CONFIG` or `--config` points somewhere else. On Windows the same
path lives under the user's profile directory.

The install scripts keep audit disabled by default. A user must choose
`--audit official` or `-Audit official`, or answer the optional prompt with
explicit consent, before the config is created as enabled.

Required config fields:

| Field | Meaning |
|---|---|
| `audit.enabled` | Must be `true` before any event is written. Missing or `false` fails closed. |
| `audit.mode` | `official-central-repo` for the built-in central repository mode. |
| `audit.official_remote_url` | Approved central repository URL. Default: `https://github.com/PetrovC/ai-agent-kit.git`. |
| `audit.branch` | Audit data branch. Default: `agent-audit-data`. |
| `audit.runtime_path` | Local event buffer and outbox path outside source projects. |
| `audit.central_repo_path` | Local clone of the central audit repository outside source projects. |
| `audit.source_project_write_policy` | Must be `never`. |
| `audit.anonymization` | Local-only salt scope and raw-content drop policy. |
| `audit.push` | Optional local commit and authorized push settings. |

## Installed Runtime

Every install or update copies the shared runtime into the target project:

```text
.ai-agent-kit/
  audit/
    audit_runtime.py
    record-event.sh
    record-event.ps1
    finalize-run.sh
    finalize-run.ps1
    config.example.json
    README.md
```

This directory is kit-managed tooling, not audit data. Generated events,
reports, local salts, central clones, and outbox bundles stay under the global
paths configured outside the source project.

## Event Recording

`record-event` accepts one JSON event on stdin or with `--event-file`.

It validates:

- M0A envelope fields are present;
- `schema_version` is `0.1.0`;
- `sequence` is a positive integer;
- `event_type` and `actor_kind` are controlled values;
- payload fields do not contain prompts, responses, command output, file
  contents, exact paths, repository URLs, branch names, issue titles, secrets,
  or similar raw content;
- `runtime_path` is outside the source project.

Accepted events append to:

```text
<runtime_path>/runs/<audit_run_id>/events.ndjson
```

Missing config, disabled config, unsafe payloads, or source-project runtime
paths fail before writing.

## Finalizing A Run

`finalize-run` reads the runtime NDJSON stream and writes the central run folder
under:

```text
<central_repo_path>/agent-audit/runs/YYYY/MM/project-hash/run-id/
```

It emits:

- `README.md`
- `run-summary.json`
- `governance-events.ndjson`
- `token-context.json`
- `agent-invocations.json`
- `friction.json`
- `activity.json`
- `report-quality.json`
- `governance-recommendations.json`
- `pricing-estimate.json`
- `recommendations.md`

The writer refuses to continue unless `central_repo_path` is a git repository
on the configured audit branch. It rejects `master`, `main`, feature branches,
fix branches, and every other branch by requiring an exact match with
`agent-audit-data` unless the config changes the audit branch.

If the central clone is missing, the runtime attempts a non-destructive clone
from the configured official URL and branch. If clone or push fails, it reports
the failure and never falls back to the source project.

## Commit, Push, And Outbox

Commit and push are optional.

- `--commit` or `audit.push.commit: true` creates an audit-specific local
  commit for the generated run folder.
- `--push` or `audit.push.mode: authorized` pushes the configured audit branch.
- If push fails, the finalized sanitized run folder is copied to
  `<runtime_path>/outbox/<audit_run_id>/` so the data is not lost.
- A push failure is reported as a runtime failure with the outbox path.

## Claude Hook Integration

The Claude settings install a best-effort hook script:

```text
.claude/hooks/agent-audit-event.sh
```

The hook is disabled unless the global audit config exists and is enabled. When
enabled, it records only safe metadata:

- provider family;
- hook name;
- high-level tool category;
- anonymized project hash;
- compaction event where Claude exposes it.

It does not store raw prompts, responses, tool inputs, tool outputs, command
output, file paths, file contents, branch names, or issue titles. Hook failures
exit zero so normal Claude behavior is unchanged when audit is disabled or
temporarily unavailable.

## Provider Capability Matrix

| Capability | Claude | Codex | Antigravity | M0D behavior |
|---|---|---|---|---|
| Lifecycle stop event | Available through hooks | Not wired in this milestone | Not wired in this milestone | Claude emits `hook.observed`; others can call `record-event` manually. |
| Tool-use hook | Available through `PostToolUse` | Not wired in this milestone | Not wired in this milestone | Claude emits high-level `tool.observed` categories only. |
| Compact/compress hook | Claude exposes `PreCompact` | Not wired in this milestone | Not wired in this milestone | Claude emits `compact.observed` where available. |
| Exact token usage | Provider-dependent and not captured here | Provider-dependent and not captured here | Provider-dependent and not captured here | `token-context.json` marks usage unavailable unless future integrations provide safe counts. |
| Raw transcript capture | Forbidden | Forbidden | Forbidden | Runtime rejects raw-content fields. |
| Central push | Tool-agnostic | Tool-agnostic | Tool-agnostic | Optional commit/push is handled by the shared runtime. |

This matrix is intentionally conservative. It avoids claiming provider parity
where no installed hook exists yet.

## Issue Coverage

| Issue | Runtime coverage |
|---|---|
| #278 | Global config contract, disabled default, official mode, runtime path, source write policy, anonymization, and push options. |
| #279 | Official central repository mode, branch name, local clone path, and consent-gated config. |
| #280 | Local runtime and `record-event` wrappers. |
| #281 | `finalize-run` report generator and required artifact set. |
| #282 | Audit branch writer safety checks. |
| #283 | Optional local commit and authorized push workflow. |
| #284 | Local outbox fallback when push fails. |
| #285 | Install-time opt-in audit setup support. |
| #286 | First Claude hook integration for safe lifecycle/tool/compact events. |
| #288 | Provider capability matrix and limitations. |

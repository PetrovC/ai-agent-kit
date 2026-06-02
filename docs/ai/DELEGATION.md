# Cross-Tool Delegation Adapter

A narrow, **opt-in** adapter that lets an orchestrator (Claude) hand a single
scoped task to **another provider's CLI** and pick the model strength from the
task type and risk. This is the narrow adapter [ADR-018](./DECISIONS.md#adr-018-advanced-orchestration-stays-outside-the-core)
and [ADR-020](./DECISIONS.md#adr-020-a-narrow-opt-in-cross-tool-delegation-adapter)
explicitly leave room for — **not** a cross-tool orchestration platform.

Status: **Codex and Antigravity providers shipped.**

## What it is (and is not)

- **Is**: a single synchronous shell-out to a provider CLI, with model routing,
  brief/summary sanitization, audit-event emission, and fail-open behavior.
- **Is not**: a long-running broker, a queue, a daemon, or an always-on
  dependency. There is no background process and nothing is enabled by default.

The orchestrator stays the **verifier**: the adapter only runs the provider and
records lifecycle events. The mandatory `report.evaluated` checkpoint (see
[SUBAGENT_GOVERNANCE.md](./SUBAGENT_GOVERNANCE.md)) still applies before the
orchestrator trusts a delegated result.

## Usage

```bash
# POSIX
.ai-agent-kit/delegate/delegate.sh \
  --provider codex \
  --task-type security_review --risk high \
  --brief-file ./brief.txt \
  --run-id "$AAK_AUDIT_RUN_ID"
```

```powershell
# Windows
.ai-agent-kit\delegate\delegate.ps1 `
  -Provider codex `
  -TaskType security_review -Risk high `
  -BriefFile .\brief.txt `
  -RunId $env:AAK_AUDIT_RUN_ID
```

| Argument | Meaning |
|---|---|
| `--provider` | `codex` \| `antigravity`. |
| `--task-type` | Drives model routing (e.g. `security_review`, `formatting`, `other`). |
| `--risk` | `low` \| `medium` \| `high` \| `critical`. High/critical force the deepest tier. |
| `--brief-file` | Path to a **sanitized** brief. Never pass secrets; never inline a brief on the command line. |
| `--run-id` | Links emitted events to the audit run (or set `AAK_AUDIT_RUN_ID`). |
| `--invocation-id` | Optional id correlating `agent.selected`/`invoked`/`completed`. |
| `--timeout` | Provider CLI timeout in seconds (default 600). |

The (sanitized) provider answer is printed to **stdout** for the orchestrator to
read and verify. Audit events carry only numeric/enum metrics, never the answer.

## Model routing

The task type and risk map to a **routing depth**, and each depth maps to a
provider-specific model/effort. See [MODEL_ROUTING.md](./MODEL_ROUTING.md).

| Depth | When | Codex (`gpt-5.5`) effort | Antigravity model hint |
|---|---|---|---|
| `deep` | security/architecture/review/investigation tasks, or `high`/`critical` risk | `model_reasoning_effort=high` | `gemini-3.1-pro` |
| `standard` | everyday implementation | `model_reasoning_effort=medium` | `gemini-3-flash` |
| `readonly` | mechanical / exploration / lookup | `model_reasoning_effort=low` | `gemini-3-flash` |

## Verified provider invocations

**Codex** (non-interactive) — verified against
`developers.openai.com/codex/noninteractive` and `/config-reference`:

```
codex exec -m gpt-5.5 -c model_reasoning_effort=<low|medium|high> \
  -s read-only --json "<sanitized brief>"
```

- `-s read-only` sandboxes the delegated run.
- `--json` yields JSON-Lines output the adapter parses into a summary.

**Antigravity** (headless) — verified against the installed CLI (`agy --help`, v1.0.3):

```
agy -p "<sanitized brief>" --sandbox --dangerously-skip-permissions
```

- `-p` (`--print`) runs a single prompt non-interactively and prints the response
  as **plain text** (there is no `--output-format` flag).
- `--sandbox` restricts terminal access; `--dangerously-skip-permissions`
  auto-approves tool prompts for unattended use.
- Antigravity has no per-call model flag, so the adapter passes a non-secret
  model **hint** via the environment (`ANTIGRAVITY_MODEL` by default,
  configurable via `AAK_DELEGATE_AGY_MODEL_ENV`) rather than invent a `--model`
  flag. The model strength is still recorded in the audit `model_tier`. Binding
  that hint to the actual per-call model is the one part to confirm end-to-end in
  your environment.

## Privacy and safety

- The brief is **privacy-scanned before** it reaches the provider CLI; if it
  carries path/URL/secret-like content the delegation is **skipped** and nothing
  is sent. Sanitization reuses the audit runtime's `privacy_scan` so the rules
  never drift from the audit boundary.
- The returned summary is **privacy-scanned before** it is printed or recorded;
  unsafe content is redacted.
- Each provider CLI needs its **own credentials in the environment**. The adapter
  never reads, logs, or forwards them.

## Audit events

Around each delegation the adapter emits, with a `provider` field, into the same
run stream the lifecycle hooks use (so cross-tool hand-offs flow into the #330
rollup and #331 findings):

- `agent.selected` — `provider`, `model_tier`, `task_type`, `risk_level`.
- `agent.invoked` — `provider`.
- `agent.completed` — `provider`, `status` (`success`/`error`), numeric
  `result_summary` (`summary_chars`, `summary_redacted`).

## Fail-open

Delegation is optional, so a failure never changes the orchestrator's default
behavior:

- a privacy rejection skips the call and returns 0;
- a missing or failing provider CLI records an `error` completion and returns 0;
- an audit-emission failure is warned about and swallowed.

## Rollback

Every piece is opt-in. Remove `.ai-agent-kit/delegate/` (or simply never call
it) to revert; no default behavior depends on it.

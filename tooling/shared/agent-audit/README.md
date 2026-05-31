# Agent Audit Runtime

This directory is installed as `.ai-agent-kit/audit/` in projects that use any
ai-agent-kit tool. It contains the local runtime scripts for the opt-in,
anonymized audit pipeline.

The scripts do not store audit config, runtime events, generated reports, hash
salts, or outbox bundles inside the source project. Those paths must come from
the global config at `~/.ai-agent-kit/config.json` or an explicit `--config`.

## Commands

Record one sanitized event:

```bash
.ai-agent-kit/audit/record-event.sh --source-root . < event.json
```

Emit one governance event (builds a well-formed event from arguments and
records it; used by the active governance loop):

```bash
AAK_AUDIT_RUN_ID=run_20260528_120000_example \
  .ai-agent-kit/audit/emit-event.sh --source-root . \
  --type agent.invoked --actor subagent --invocation-id inv_1 \
  --payload '{"agent_category":"security","model_tier":"review"}'
```

Finalize one run:

```bash
.ai-agent-kit/audit/finalize-run.sh --source-root . --run-id run_20260528_120000_example
```

PowerShell wrappers are also installed:

```powershell
.\.ai-agent-kit\audit\record-event.ps1 -SourceRoot . -EventFile event.json
.\.ai-agent-kit\audit\emit-event.ps1 -SourceRoot . -Type run.started -Actor system -RunId run_20260528_120000_example
.\.ai-agent-kit\audit\finalize-run.ps1 -SourceRoot . -RunId run_20260528_120000_example
```

The active governance loop that drives `emit-event` (and its mandatory
report-evaluation checkpoint) is documented in `docs/ai/SUBAGENT_GOVERNANCE.md`.

## Safety Contract

- Audit is disabled unless the global config explicitly sets
  `audit.enabled` to `true`.
- Runtime and central repository paths must be outside the source project.
- Finalized reports are written only to the configured central audit clone on
  the `agent-audit-data` branch.
- `master`, `main`, feature, fix, or other code branches are rejected because
  the runtime requires the current branch to match the configured audit branch.
- Push is optional. If an authorized push fails after finalization, the
  sanitized run folder is copied to the local outbox under the runtime path.
- Payloads containing prompts, responses, command output, file contents, exact
  paths, repository URLs, branch names, issue titles, credentials, or similar
  raw content are rejected before write.

See `config.example.json` for the global configuration contract.

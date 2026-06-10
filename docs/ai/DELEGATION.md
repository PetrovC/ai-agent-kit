# Cross-Tool Delegation Adapter

A narrow, **opt-in** adapter that lets an orchestrator (Claude) hand a single
scoped task to **another provider's CLI** and pick the model strength from the
task type and risk. This is the narrow adapter [ADR-018](./DECISIONS.md#adr-018-advanced-orchestration-stays-outside-the-core)
and [ADR-020](./DECISIONS.md#adr-020-a-narrow-opt-in-cross-tool-delegation-adapter)
explicitly leave room for — **not** a cross-tool orchestration platform.

Status: **Claude, Codex, and Antigravity providers shipped. Delegation is symmetrical.**

## Symmetry model

Any of the three supported agents can delegate to either of the other two:

```text
Claude Code  ──►  Codex CLI
             ──►  Antigravity

Codex CLI    ──►  Claude Code
             ──►  Antigravity

Antigravity  ──►  Claude Code
             ──►  Codex CLI
```

Provider-specific behavior lives in thin adapter functions
(`build_claude_argv`, `build_codex_argv`, `build_antigravity_argv`) inside the
adapter. Shared policy (routing depth, privacy scan, fail-open contract) is
never duplicated. See `AGENTS.md` and `AGY.md` for per-agent delegation guides.

## What it is (and is not)

- **Is**: a single synchronous shell-out to a provider CLI, with model routing,
  brief/summary sanitization, and fail-open behavior.
- **Is not**: a long-running broker, a queue, a daemon, or an always-on
  dependency. There is no background process and nothing is enabled by default.

The orchestrator stays the **verifier**. The mandatory `report.evaluated` checkpoint (see
[SUBAGENT_GOVERNANCE.md](./SUBAGENT_GOVERNANCE.md)) still applies before the
orchestrator trusts a delegated result.

## Usage

```bash
# POSIX
.ai-agent-kit/delegate/delegate.sh \
  --provider codex \
  --task-type security_review --risk high \
  --brief-file ./brief.txt
```

```powershell
# Windows
.ai-agent-kit\delegate\delegate.ps1 `
  -Provider codex `
  -TaskType security_review -Risk high `
  -BriefFile .\brief.txt
```

| Argument | Meaning |
|---|---|
| `--provider` | `codex` \| `antigravity`. |
| `--task-type` | Drives model routing (e.g. `security_review`, `formatting`, `other`). |
| `--risk` | `low` \| `medium` \| `high` \| `critical`. High/critical force the deepest tier. |
| `--brief-file` | Path to a **sanitized** brief. Never pass secrets; never inline a brief on the command line. |
| `--run-id` | Retained for backward compatibility (the audit subsystem has been removed). |
| `--invocation-id` | Retained for backward compatibility (the audit subsystem has been removed). |
| `--timeout` | Provider CLI timeout in seconds (default 600). |

The (sanitized) provider answer is printed to **stdout** for the orchestrator to
read and verify.

## Model routing

The task type and risk map to a **routing depth**, and each depth maps to a
provider-specific model/effort. See [MODEL_ROUTING.md](./MODEL_ROUTING.md).

| Depth | When | Codex (`gpt-5.5`) effort | Antigravity model | Claude model |
|---|---|---|---|---|
| `deep` | security/architecture/review/investigation, or `high`/`critical` risk | `model_reasoning_effort=high` | `claude-opus-4-6` | `claude-opus-4-8` |
| `standard` | everyday implementation | `model_reasoning_effort=medium` | `claude-sonnet-4-6` | `claude-sonnet-4-6` |
| `readonly` | mechanical / exploration / lookup | `model_reasoning_effort=low` | `claude-sonnet-4-6` | `claude-haiku-4-5` |

## Verified provider invocations

**Claude Code** (headless `--print` mode) — verified against
`code.claude.com/docs` (accessed 2026-06-05):

```
claude --print "<sanitized brief>" --model <model> [--dangerously-skip-permissions]
```

- `--print` runs a single prompt non-interactively and prints plain text.
- `--model` sets the model for this invocation.
- `--dangerously-skip-permissions` is added only for implementation tasks
  (`write_mode=True`); read-only delegations omit it to avoid accidental writes.

**Codex** (non-interactive) — verified against
`developers.openai.com/codex/noninteractive` and `/config-reference`:

```
codex exec -m gpt-5.5 -c model_reasoning_effort=<low|medium|high> \
  -s read-only --json "<sanitized brief>"
```

- `-s read-only` sandboxes the delegated run.
- `--json` yields JSON-Lines output the adapter parses into a summary.

**Antigravity** (headless):

```
agy -m <model> -p "<sanitized brief>" --output-format json \
  --sandbox --dangerously-skip-permissions
```

- `-m` selects the model for this invocation; no environment hint is used.
- `-p` (`--print`) runs a single prompt non-interactively.
- `--output-format json` yields structured output the adapter parses into a
  non-empty summary.
- `--sandbox` restricts terminal access; `--dangerously-skip-permissions`
  auto-approves tool prompts for unattended use.
- On quota exhaustion, deep delegation crosses quota pools from
  `claude-opus-4-6` to `gemini-3.1-pro`; standard and readonly delegation also
  fall back to `gemini-3.1-pro`.

## Privacy and safety

- The brief is **privacy-scanned before** it reaches the provider CLI; if it
  carries path/URL/secret-like content the delegation is **skipped** and nothing
  is sent. Sanitization checks for path/URL/secret-like content to avoid leaking
  sensitive information.
- The returned summary is **privacy-scanned before** it is printed;
  unsafe content is redacted.
- Each provider CLI needs its **own credentials in the environment**. The adapter
  never reads, logs, or forwards them.

## Fail-open

Delegation is optional, so a failure never changes the orchestrator's default
behavior:

- a privacy rejection skips the call and returns 0;
- a missing or failing provider CLI is logged/warned about and returns 0.

The adapter always writes exactly one final machine-parseable status line to
**stderr**, while preserving the fail-open exit code:

```text
delegate-status: status=<ok|empty|skipped|error> provider=<p> exit_code=<n> summary_chars=<n> fallback_used=<true|false>
```

- `ok`: the provider exited 0 and the extracted summary is non-empty.
- `empty`: the provider exited 0 but the extracted summary is empty or whitespace.
- `skipped`: the provider exited 127 because its CLI was unavailable or not executable.
- `error`: any other non-zero provider exit, including timeout exit 124.

An orchestrator should parse this line to distinguish a usable result from an
empty, skipped, or failed handoff; it must not use the adapter exit code for
that distinction.

## Rollback

Every piece is opt-in. Remove `.ai-agent-kit/delegate/` (or simply never call
it) to revert; no default behavior depends on it.

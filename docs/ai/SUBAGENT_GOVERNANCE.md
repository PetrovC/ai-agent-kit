# Subagent Governance

Subagents are useful only when they reduce total context cost. They are not a
default replacement for direct reading, deterministic search, or main-agent
judgment.

## Use Subagents When

- The affected area is unknown.
- Output is noisy, such as large test logs.
- The task touches architecture or security.
- Broad search would pollute the main context.
- A second-opinion review is useful.
- Test or log output is too large for the main context.

## Do Not Use Subagents When

- The main agent already deeply inspected the same files.
- The task is a simple one-file change.
- Deterministic search is enough.
- The subagent would produce a vague report.
- The subagent would need a weak model for reasoning-heavy work.

## No Duplicate Reading Rule

- The main agent must not delegate a scope it already deeply inspected.
- The main agent must not read the same broad scope in parallel while a
  subagent investigates.
- The subagent report should identify what the main agent should not re-read.
- If the main agent must re-read everything to trust the report, the delegation
  failed.

## Deterministic Search First

Before launching `codebase-investigator`, prefer deterministic lookup when the
goal is to find exact symbols, usages, configuration keys, endpoints, or
filenames:

- `rg`
- `git grep`
- targeted file search
- direct file listing

Use a subagent after deterministic search when the question is broader than
exact lookup or when the result set needs interpretation.

In this repository, deterministic search is usually enough for script options,
workflow names, route-file references, hook names, and version constants. A
subagent is more useful for cross-provider parity review, security review,
public-release readiness, or noisy CI/test output.

### Scope discipline for search-heavy subagents

When an investigator-style subagent uses Grep / search tools, default to
narrow, predictable output. The kit's expectation:

- **Default output mode** is `files_with_matches`, not `content`. Switch to
  `content` only after you've narrowed the candidate set.
- **Cap `head_limit` at 50** by default. The tool default of 250 lines
  flood s context with marginally relevant hits; tighten before you widen.
- **Prefer `glob` and `type` filters** over scanning the whole tree.
- **One pattern, one purpose.** If the pattern needs `|` with 5 alternatives,
  it usually means the question is too broad — re-narrow before running.
- **Stop reading at the first useful answer.** Subagents are not auditors;
  they answer one question and exit.

The `codebase-investigator` agent prompt restates these rules; this section
is the cross-cutting governance reference.

## Main Agent Responsibility

- Task understanding.
- Final decision.
- Final edits.
- Final PR summary.
- Final verification.
- Deciding whether a subagent report is actionable.

## Subagent Responsibility

- Narrow investigation.
- Focused review.
- Noisy output summarization.
- Risk identification.
- Second opinion on scoped areas.

## Active Governance Loop

The audit answers "did the agents do what they reported?" only if the
governing (high-capability) model emits governance events as it works. This is
the canonical description of that loop and its mandatory checkpoint.

The loop uses the shared `emit-event` helper (`.ai-agent-kit/audit/emit-event.sh`,
or `emit-event.ps1` on Windows). All events in one session share an
`audit_run_id`: export `AAK_AUDIT_RUN_ID` once and the activity hooks, the
emitted governance events, and `finalize-run` all write to the same run folder.

1. **Start and classify.** Emit `run.started`, then `task.classified` with the
   sanitized task type, risk, and complexity.
2. **Select and invoke.** For each subagent, emit `agent.selected` then
   `agent.invoked` with a stable `--invocation-id`, the agent category, and the
   model tier.
3. **Complete.** When the subagent returns, emit `agent.completed` for the same
   invocation id with `status` and a sanitized `result_summary`.
4. **Mandatory checkpoint — verify before trust.** Before accepting any
   subagent report, the architect verifies it against recorded activity (the
   report structure below) and emits `report.evaluated` with the quality
   category. This checkpoint is mandatory: an unevaluated report must not be
   accepted. On a realign decision, also emit `recommendation.created`.
5. **Finish.** Emit `run.completed` with the final status and validation state,
   then run `finalize-run` to aggregate, score, and store the run.

Emission is best-effort and fail-open: the loop calls `emit-event` without
letting a failure change agent behavior, and the audit is never written into
the source project. Events carry sanitized metadata only — never raw prompts,
responses, command output, file contents, exact paths, repository URLs, or
branch names.

```bash
export AAK_AUDIT_RUN_ID="run_claude_20260531_ab12cd34ef567890"
emit-event.sh --type run.started --actor system
emit-event.sh --type task.classified --actor main_agent \
  --payload '{"task_type":"security_review","risk_level":"high"}'
emit-event.sh --type agent.invoked --actor subagent --invocation-id inv_1 \
  --payload '{"agent_category":"security","model_tier":"review"}'
emit-event.sh --type agent.completed --actor subagent --invocation-id inv_1 \
  --payload '{"status":"success"}'
emit-event.sh --type report.evaluated --actor main_agent \
  --payload '{"quality_category":"accepted"}'
emit-event.sh --type run.completed --actor system \
  --payload '{"status":"completed","validation_state":"passed"}'
```

`AGENT_AUDIT_GOVERNANCE.md` defines how the emitted events are scored;
`AGENT_AUDIT_SCHEMA.md` defines each event's payload schema and privacy rules.

## Mandatory Subagent Report Structure

Every useful report should include:

- question answered;
- scope inspected;
- files inspected;
- findings with evidence;
- confidence level;
- what the main agent should read next;
- what the main agent should not re-read;
- risks and unknowns.

## Invalid Report Examples

These are not actionable:

- "The issue probably comes from the cache service."
- "The architecture should probably be reviewed."
- "The tests seem to fail because of a mock."

## If A Report Is Vague

- Do not rely on it.
- Rerun with a stronger model and narrower scope.
- Inspect exact files directly.
- Ask for or create a narrower issue before implementation work.

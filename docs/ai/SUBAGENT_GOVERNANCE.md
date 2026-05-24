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

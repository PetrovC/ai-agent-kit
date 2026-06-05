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

## Governance

Governance is enforced through PR review and CI, not a runtime audit log.

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

## teammateMode — choosing in-process vs tmux

When Claude Code launches a parallel teammate (subagent), the `teammateMode`
setting in `.claude/settings.json` controls how it runs.

```json
{ "teammateMode": "auto" }   // default — Claude decides
{ "teammateMode": "in-process" }
{ "teammateMode": "tmux" }
```

| Mode | Overhead | Isolation | When to use |
|---|---|---|---|
| `auto` | — | — | Default. Let Claude pick based on task size and availability of tmux. |
| `in-process` | Low | Shares process state | Short-lived helpers: quick search, doc lookup, single-file analysis. The subagent shares the parent's environment variables and file handles. Good when you need the result immediately and don't need the subagent to outlive the request. |
| `tmux` | Medium | Independent shell | Long-running parallel work: running tests while writing code, two investigator agents scanning different directories simultaneously. Requires tmux to be available in the environment. Background isolation is stronger — the subagent has its own shell state and cannot accidentally affect the parent's working directory. |

### Guidelines for this kit

- **Prefer `auto`** in all normal usage. It degrades gracefully when tmux is not
  present (CI, Windows without tmux, minimal Docker images).
- **Prefer `in-process`** when the subagent is a quick lookup that will be done
  in seconds and you want the result inline.
- **Prefer `tmux`** only when you explicitly want to watch two agents work
  side-by-side in a terminal, or when OS-level isolation is required (e.g.,
  one agent modifies files while another runs tests that must not see partial edits).
- Set `worktree.bgIsolation: "sandbox"` alongside `tmux` mode to prevent
  parallel agents from overwriting each other's working files. See
  `tooling/claude/CLAUDE.md` for worktree settings.

### Relation to subagent ROI

`teammateMode` affects performance, not the decision to delegate. Whether to
delegate at all is governed by the **Use Subagents When** / **Do Not Use Subagents When**
rules above. `tmux` mode does not justify delegation that would otherwise fail
the no-duplicate-reading or deterministic-search-first rules.


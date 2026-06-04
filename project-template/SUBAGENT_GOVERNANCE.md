# Subagent Governance

> ⚠️ **STOP** — Review and update the subagent routing table below to reflect
> the subagents available in your project.

Subagents are useful only when they reduce total context cost. They are not a
default replacement for direct reading, deterministic search, or main-agent
judgment.

## Subagent Routing

| Situation | Subagent | Role |
|---|---|---|
| Affected area is unclear | `codebase-investigator` | Targeted lookup/search |
| Change touches architecture | `architect` | Architecture review |
| Change touches security-sensitive code | `security-reviewer` | Security audit |
| Test/log output is large | `test-runner` | Run tests and summarize |

## Use Subagents When

- The affected area is unknown.
- Output is noisy, such as large test logs.
- The task touches architecture or security.
- Broad search would pollute the main context.
- A second-opinion review is useful.

## Do Not Use Subagents When

- The main agent already deeply inspected the same files.
- The task is a simple one-file change.
- Deterministic search is enough.
- The subagent would produce a vague report.

## No Duplicate Reading Rule

- The main agent must not delegate a scope it already deeply inspected.
- The main agent must not read the same broad scope in parallel while a subagent investigates.
- The subagent report should identify what the main agent should not re-read.
- If the main agent must re-read everything to trust the report, the delegation failed.

## Deterministic Search First

Before launching an investigator-style subagent, prefer deterministic lookup (e.g. `rg`, `git grep`, targeted file searches, direct file listing) when the goal is to find exact symbols, usages, or filenames. Use a subagent when the query requires interpretation or synthesis of findings.

## Responsibilities

### Main Agent

- Task understanding, final decisions, final edits, PR summaries, and verification.
- Deciding whether a subagent report is actionable and verifying findings.

### Subagent

- Narrow investigation, focused review, noisy output summarization, and risk identification.

## Mandatory Subagent Report Structure

Every useful report should include:
- Question answered
- Scope/files inspected
- Findings with evidence
- Confidence level
- What the main agent should read next
- What the main agent should not re-read
- Risks and unknowns

## If A Report Is Vague

- Do not rely on it.
- Rerun with a stronger model and narrower scope, inspect exact files directly, or ask for a narrower issue.

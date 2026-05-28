# Agent Audit Storage

This document defines the M0B central audit repository storage contract for
anonymized agent audit reports. It builds on
[AGENT_AUDIT_SCHEMA.md](./AGENT_AUDIT_SCHEMA.md), which defines the payload
schemas and privacy contract.

The storage contract defines the central layout and safety rules. M0D adds the
local opt-in runtime in [AGENT_AUDIT_RUNTIME.md](./AGENT_AUDIT_RUNTIME.md);
ingestion jobs and dashboard generation remain out of scope.

## Storage Goals

The central audit repository must:

- store many anonymized projects and many runs per project;
- keep live audit data separate from source code changes;
- avoid one pull request per agent session;
- be script-friendly for future writers and indexes;
- remain human-readable enough for maintainers to inspect fixtures and policy;
- preserve the M0A privacy rule that central artifacts contain metadata only.

## Branch Strategy

Audit data uses a dedicated branch named `agent-audit-data`.

| Branch | Purpose | Merge policy |
|---|---|---|
| `master` | Code, docs, schemas, policy, and anonymized fixtures. | Normal issue-first PR workflow. |
| `agent-audit-data` | Append-only anonymized audit run data and generated indexes. | Updated directly by the future audit writer; not merged into `master` per run. |

Rules for writers:

- refuse to write audit run data to `master`, `main`, `dev`, release branches,
  or any protected code branch;
- refuse to push if the current branch is not `agent-audit-data` unless running
  in an explicit local fixture mode;
- never mix code, schema, or policy edits with generated audit run data;
- append new run folders instead of rewriting historical run folders;
- update generated indexes only on `agent-audit-data`;
- keep branch operations non-destructive: no force push, no branch deletion, and
  no history rewrite.

CI expectations:

- PR CI remains authoritative for `master` changes.
- The `agent-audit-data` branch should avoid heavy build/test workflows.
- Future lightweight checks may parse JSON, NDJSON, and index files on the
  audit branch.
- A failing audit-data parse check should block only audit ingestion, not source
  code development.

## Central Layout

The central repository stores audit data under `agent-audit/`.

```text
agent-audit/
  README.md
  policy/
    README.md
  indexes/
    README.md
    years/
      YYYY.json
    months/
      YYYY-MM.json
    projects/
      project-hash.json
  runs/
    YYYY/
      MM/
        project-hash/
          run-id/
            README.md
            run-summary.json
            governance-events.ndjson
            token-context.json
            agent-invocations.json
            friction.json
            activity.json
            report-quality.json
            governance-recommendations.json
            pricing-estimate.json
            recommendations.md
```

`master` may contain anonymized fixtures that use this layout. Real generated
run data belongs on `agent-audit-data`.

## Run Folder Naming

Run folders use:

```text
runs/YYYY/MM/project-hash/run-id/
```

| Segment | Rule |
|---|---|
| `YYYY` | UTC year from the run completion timestamp. |
| `MM` | UTC two-digit month from the run completion timestamp. |
| `project-hash` | Stable anonymous project id such as `hmac_sha256_4f7b7b4e2c2a`; no raw project name. |
| `run-id` | Opaque run id such as `run_20260528_120000_7f4c9a1d`; no branch, issue title, or repository name. |

Folder names must not include source repository names, organizations, product
names, branch names, issue titles, user names, local machine names, or exact
paths.

## Required Run Artifacts

| Artifact | Required | Notes |
|---|---:|---|
| `run-summary.json` | Yes | Top-level machine-readable summary; links to other files by relative file name. |
| `README.md` | Yes | Sanitized human-readable report for fixture inspection and manual audits. |

The summary must be enough for indexes and dashboards to list the run even when
optional artifacts are absent.

## Optional Run Artifacts

| Artifact | Purpose |
|---|---|
| `governance-events.ndjson` | Append-only timeline events. |
| `token-context.json` | Token and context usage. Canonical M0A name; older issue text may call this token usage. |
| `agent-invocations.json` | Main-agent and subagent invocation records. |
| `friction.json` | Retry, blocker, escalation, rework, and stop-reason metadata. |
| `activity.json` | Tool and file activity counters. |
| `pricing-estimate.json` | Optional approximate cost estimate with staleness metadata. |
| `report-quality.json` | Structured evaluation of report quality and validation confidence. |
| `governance-recommendations.json` | Machine-readable governance recommendations for human review. |
| `recommendations.md` | Sanitized human-readable companion to the machine-readable recommendations. |

`token-context.json` is the canonical filename because it covers both token
usage and context pressure. Readers may treat legacy `token-usage.json` as an
alias if encountered, but future writers should emit only `token-context.json`.

## Index Layout

Indexes are generated convenience files. They must contain only data already
safe to store in run artifacts.

| Path | Purpose |
|---|---|
| `indexes/years/YYYY.json` | One year of run-summary pointers and aggregate counters. |
| `indexes/months/YYYY-MM.json` | One month of run-summary pointers and aggregate counters. |
| `indexes/projects/project-hash.json` | Runs for one anonymized project hash. |

Index records should include:

- `schema_version`;
- index period or project hash;
- generated timestamp;
- run count;
- aggregate task type, technical scope, status, and token estimate buckets;
- relative pointers to `run-summary.json` files.

Index records must not copy raw report text, recommendations, command output,
file names, file paths, prompts, responses, or branch names.

## Policy Folder

`agent-audit/policy/` stores central storage policy notes for future writers and
reviewers. It may include:

- privacy rules derived from M0A;
- branch safety rules;
- retention and pruning policy;
- index generation policy;
- fixture authoring guidance.

Policy changes go through normal PRs on `master`. Generated run data and
generated indexes do not.

## External Project Ingestion

Audit data produced while working in an external source project must not be
written into that source project.

Expected flow:

1. The agent runs in an external project.
2. Runtime audit metadata is buffered in a local runtime folder outside the
   source repository.
3. The runtime folder keeps any local-only mapping files and hash salts outside
   source control.
4. The final anonymized report is written to the central audit repository under
   `agent-audit/runs/YYYY/MM/project-hash/run-id/`.
5. The writer switches to or targets `agent-audit-data` before committing audit
   run data.
6. Generated indexes are updated on `agent-audit-data`.

Source project write policy:

- never write central audit reports into external source repositories;
- never add source-project `.gitignore` entries for central audit data;
- never commit local hash salts or project mapping files;
- never copy prompts, responses, command output, file contents, or exact paths
  from the source project into the central repository.

## Official Central Repository Mode

In official mode, the central target is this repository and the data branch is
`agent-audit-data`.

Minimum writer checks:

- repository remote matches an approved central audit repository;
- current or target branch is `agent-audit-data`;
- working tree has no source-code edits mixed with audit output;
- run folder does not already exist;
- required artifacts parse successfully;
- artifact references stay inside the run folder;
- payloads pass the M0A privacy checks available to the writer.

If the writer cannot push:

- keep the sanitized run folder in the local runtime area or a local clone of
  the central repository;
- print a concise instruction that an authorized maintainer can push later;
- do not fall back to writing into the external source project;
- do not open a normal source-code PR for every audit run.

## Contributor Consent

Central audit ingestion is opt-in.

Contributor-facing wording may say:

> This project can contribute anonymized agent audit metadata to a central
> ai-agent-kit audit repository. The report stores technical counters,
> timings, task classifications, and estimates only. It does not store prompts,
> responses, command output, file contents, exact paths, repository URLs, branch
> names, credentials, or business data. You can disable audit contribution
> without changing normal agent behavior.

Consent requirements:

- default to no central push unless the project or contributor explicitly opts
  in;
- make the central target visible before first push;
- keep local-only salt and mapping files local;
- allow contributors to inspect the sanitized run folder before publishing;
- fail closed when anonymization cannot be proven.

## Fixture Expectations

An anonymized fixture should:

- live under the same `runs/YYYY/MM/project-hash/run-id/` layout;
- use obvious fake hashes such as `hmac_sha256_example_project`;
- include main session, at least one subagent, one retry, one escalation, token
  estimates, report quality, and recommendations;
- parse as valid JSON or NDJSON where applicable;
- avoid all forbidden M0A data, even in Markdown examples.

See [agent-audit/](../../agent-audit/) for the repository fixture.

## Issue Coverage

| Issue | Covered by |
|---|---|
| [#270](https://github.com/PetrovC/ai-agent-kit/issues/270) | Central `agent-audit/` layout, run folder naming, required/optional files, indexes, and policy folder. |
| [#271](https://github.com/PetrovC/ai-agent-kit/issues/271) | `agent-audit-data` branch strategy, separation from code changes, writer branch safety, and CI expectations. |
| [#272](https://github.com/PetrovC/ai-agent-kit/issues/272) | External project ingestion flow, source project write policy, runtime folder, central target, unauthorized push fallback, and opt-in consent. |
| [#273](https://github.com/PetrovC/ai-agent-kit/issues/273) | Fixture expectations and the anonymized example run folder. |

# Audit Report — ai-agent-kit

**Date:** 2026-05-29 · **Commit:** `1d5a97e` · **Method:** tested — the audit
runtime was executed end-to-end, every hook copy was grepped, and provider model
claims were checked against live docs. **Tooling note:** the audit host had
`python3` / `jq` / `git` / `node` but no `pwsh` / `bats`, so the PowerShell and
BATS suites were not run here.

This is the single canonical audit. It replaces six earlier review documents
(`GAP_ANALYSIS`, `TEST_STRATEGY_REVIEW`, `AGENT_GOVERNANCE_REVIEW`,
`DOCS_ALIGNMENT_REVIEW`, `IMPLEMENTATION_PLAN`, `DOGFOOD_AUDIT`) and the
`BACKLOG` mirror. **GitHub issues are the canonical backlog — see [#308](https://github.com/PetrovC/ai-agent-kit/issues/308).**

## How to read this

- Findings are tagged `[WORKS]` / `[BROKEN]` / `[MISSING]` / `[DRIFT]` and link
  the issue that tracks the fix.
- Detail and acceptance criteria live in the issues, not here, to keep this file
  under the 200-line model-read budget.

## Agent-audit system

Spans the local runtime (`.ai-agent-kit/audit/`), the central store contract
(`agent-audit/`, branch `agent-audit-data`), and per-provider event hooks.

- `[WORKS]` **Anonymization.** `privacy_scan` rejects forbidden keys, absolute
  paths, repo URLs, and secret patterns. Tested: an `sk-…` value and a
  `file_path` key were both rejected at record time (`audit_runtime.py:164-201`).
- `[WORKS]` **Git-save strategy.** Real code, not just docs: clone the central
  repo, refuse any branch except `agent-audit-data`, write an append-only run
  folder, optional commit/push, local outbox fallback (`audit_runtime.py:255-523`).
  The contract in `AGENT_AUDIT_STORAGE.md` matches the implementation.
- `[BROKEN]` **Finalized artifacts are empty.** `build_artifacts` counts events
  but discards their payloads: `agent-invocations.json` and
  `governance-recommendations.json` stay `[]` even when events carry data
  (tested). Commit also fails under enforced signing (no `--no-gpg-sign`). → #309
- `[MISSING]` **Governance scoring.** `AGENT_AUDIT_GOVERNANCE.md` (473 lines)
  specifies quality / noise / model-fit scoring; none is implemented.
  `report-quality.json` merely echoes the payload. → #310
- `[MISSING]` **Governance events are never emitted.** Hooks emit only
  `tool/hook/compact.observed`; `run.*`, `agent.*`, `task.classified`,
  `model.decision`, `recommendation.created` have no producer. → #311
- `[BROKEN]` **Two of three agents degrade.** Codex/Antigravity hooks read
  non-existent `codex_*` / `agy_*` env vars and fall back to `pwd`; only Claude's
  `CLAUDE_PROJECT_DIR` is real. → #304
- `[BROKEN]` **Debuggability.** Every audit hook is `set +e` with output sent to
  `/dev/null` and `exit 0` on failure — a black box. → #305

### Architecture challenge

The audit is a passive, write-only telemetry sink. The intended model is an
**active governance loop**: a high-capability model architects, invokes subagent
models, verifies their reports against recorded activity, and realigns on the
audit at a mandatory checkpoint. That loop has no emitter, no verification step,
and no enforcement point today. #309 + #310 + #311 together close it.

## Hooks & guards

- `[BROKEN]` Antigravity `pre-bash-guard` separator `case` dropped the
  `&&` form (duplicated `&&`), weakening compound-command segmentation
  versus Claude/Codex. → #303
- `[DRIFT]` Hook event coverage: Claude 6, Codex 5, Antigravity 3. → #178
  (titled "gemini"; it is an Antigravity task).

## Tests & CI

- `[MISSING]` No single required gate — branch protection must name all 9
  workflows individually; renaming one silently drops enforcement. → #300
- `[MISSING]` No master "run everything" entrypoint (bats + pester + validate).
- `[WEAK]` Audit-runtime coverage is thin relative to its importance; harden it
  alongside #309 / #310.
- `[DRIFT]` Bash/PowerShell suites can drift — parity tracked in #147; router
  parity in #148.

## Provider model routing — verified against live docs (May 2026)

- `[DRIFT]` Claude: routing pins `claude-opus-4-7`; **Opus 4.8
  (`claude-opus-4-8`) is now the most capable**
  ([source](https://platform.claude.com/docs/en/about-claude/models/overview)). → #314
- `[DRIFT]` Antigravity: per-subagent `gemini-3.1-pro` / `gemini-3-flash` and a
  "future `gemini-3.5-flash`" do not match Antigravity's documented fixed picker
  (Gemini 3 Pro/Flash, Claude Sonnet 4.6 ±Thinking, Claude Opus 4.6 Thinking,
  GPT-OSS-120B) — needs verification
  ([source](https://antigravity.google/docs/models)). → #314
- Codex: the `gpt-5.5` claim needs a docs re-check. → #314

## Model-read file budget (≤ 200 lines)

- `[DRIFT]` 21 files exceed 200 lines, including all three routers,
  `AGENT_AUDIT_SCHEMA.md` (643), `AGENT_AUDIT_GOVERNANCE.md` (473), and 11
  skills. Skills → #158; routers + audit docs → #315.

## Workflow & governance rules

- `[WORKS]` Issue-first, one-concern, dedicated-branch are already mandated
  (`CONTRIBUTING.md`, `WORKFLOW.md`, `github-workflow` skill).
- `[MISSING]` The agent branch pattern `agent/<agent>/<model>/<type>/<area>`,
  create-issue-if-none + milestone link, master preflight, and English-only are
  not encoded. → #312. (Git refs allow dots — `opus-4.8` is valid; avoid `()` and
  other shell-hostile characters.)

## Install / update

- `[WORKS]` install/update/uninstall deploy all three providers; `validate.*`
  enforces dogfood drift, router budgets, the model whitelist, and
  CHANGELOG/VERSION invariants.
- `[MISSING]` No audit record of what install/update changed; failures are
  opaque. → #313 (with #305).

## Docs hygiene

- `[DRIFT → fixed here]` `docs/ai/` carried eight overlapping review/backlog docs
  (~1,150 lines), one partly in French, duplicating the issue tracker. This PR
  consolidates them into this file and removes the rest; the backlog lives in
  GitHub issues.

## Verified vs untested

| Area | Status | Evidence |
|---|---|---|
| Anonymization rejects secrets/paths | Verified | runtime negative tests |
| finalize-run writes run folder | Verified | sandbox run; 11 artifacts written |
| Artifacts capture event content | Failed | invocations/recommendations empty |
| Commit under signing | Failed | signing server returned 400 |
| #304 env-var drift | Verified | grep of 6 hook copies |
| #303 separator drift | Verified | grep of 3 guard copies |
| Opus 4.8 is current top model | Verified | Anthropic docs |
| PowerShell / BATS suites | Untested here | no `pwsh` / `bats` on host |
| Live hook execution per provider | Untested | needs real agent sessions |

## Backlog index

Tracking epic: **#308**. New: #309 #310 #311 #312 #313 #314 #315.
Existing in scope: #304 #303 #305 #300 #158 #197 #148 #178 #179 #186 #147.

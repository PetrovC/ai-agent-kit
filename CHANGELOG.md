# Changelog

## [1.19.35] - 2026-05-23

### Fixed — Windows install: ExecutionPolicy guidance + bash-resolution warning + hook CI check (closes #41, closes #42)

Two related Windows-platform fragilities in the kit's runtime.

- **README documents the Windows ExecutionPolicy workaround
  (closes #41).** A default Windows install ships with
  `ExecutionPolicy = Restricted`, which rejects direct `.\scripts\install.ps1`
  invocation with a non-actionable French/English error message. The
  README's quick-start now includes a "Windows notes" subsection with
  the exact bypass form (`powershell.exe -NoProfile -ExecutionPolicy
  Bypass -File .\scripts\install.ps1 …`) applied to every lifecycle
  script, plus a link to Microsoft's `about_Execution_Policies`
  documentation and a note about `Set-ExecutionPolicy RemoteSigned
  -Scope CurrentUser` as the persistent relaxed setting.

- **Hook commands now warn at install time when `bash` is the WSL
  stub (closes #42).** The kit's Claude / Codex hooks invoke `bash
  "${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-bash-guard.sh"`. On Windows
  the name `bash` can resolve to:
  - `C:\Program Files\Git\bin\bash.exe` — Git Bash, ships
    `cat`/`grep`/`sed`/`jq`/`python3`-style utilities the hooks need.
    Works.
  - `C:\Windows\System32\bash.exe` — the WSL launcher. Without an
    installed WSL distro it exits non-zero on every hook invocation
    and the `PreToolUse` guard silently never runs, losing the only
    mechanical block on destructive shell commands when the user
    runs Claude `--dangerously-skip-permissions` or Codex
    `approval_policy=never`.

  `scripts/install.ps1` now detects this at install time: it probes
  `Get-Command bash`, warns loudly if the resolved path is
  `…\System32\bash.exe` (or if `bash` is missing entirely), and tells
  the user exactly how to fix `PATH`. The README's "Windows notes"
  subsection documents the same prerequisite with verification
  commands (`where bash; bash --version`).

  Regression coverage on `windows-latest` exercises the exact
  installed hook command form (`bash
  "${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-bash-guard.sh"`) against a
  benign JSON payload and asserts the hook returns 0 or 2 (both are
  "ran"; anything else means `bash` resolution is broken). This is
  the missing CI gap the issue called for — the existing PSScriptAnalyzer
  + parse jobs validated the .ps1 sources but never invoked the hook
  through `bash` on Windows.

---

## [1.19.34] - 2026-05-23

### Fixed — stack-agnostic prompts + Codex notify clarification (closes #46, closes #73)

Two related defects in the kit's copy-paste templates: the prompts /
issue templates hardcoded `.NET` / `npm` build/test commands instead of
referencing `docs/ai/COMMANDS.md`, and the Codex project config showed a
`notify = […]` example that Codex silently ignores at project scope.

- **Prompts + issue templates are now stack-agnostic (closes #73).**
  `prompts/bug-fix.md` and `prompts/daily-ticket.md` previously told the
  agent to "Run `dotnet test` (or `npm test`)" and "Use the `dotnet`
  and `testing` skills". The kit advertises `skills/` as
  tool-agnostic, so a user pasting these prompts inside a Python / Go
  / Rust project handed the agent an explicit stack bias and wasted
  the first build/test cycle on a non-existent `dotnet` binary. The
  prompts now read "Run the project's test command (see
  `docs/ai/COMMANDS.md`)" and tell the agent to pick the skill that
  matches the files it touches. The three `.github/ISSUE_TEMPLATE/*.md`
  validation blocks ship a placeholder pointing at
  `docs/ai/COMMANDS.md` instead of `dotnet test` / `npm test`. The
  `dependency-update.md`, `tech-debt.md`, and `security-audit.md`
  prompts already list ALL stacks as explicit menus and are kept
  as-is.

- **Codex `notify` example clarified (closes #46).**
  `tooling/codex/config.toml` shipped a commented `notify = ["bash",
  ".codex/hooks/notify-done.sh"]` line as a "project-local
  alternative" to the `notify-done.sh` hook. Per the
  [Codex config reference](https://developers.openai.com/codex/config-reference),
  `notify` is a machine-local key — Codex reads it ONLY from
  `~/.codex/config.toml`, never from a project-scoped
  `.codex/config.toml`. Uncommenting the example did nothing. The
  example is removed and replaced with a note: project-level
  completion notification stays in the `notify-done.sh` hook (already
  shipped via `.codex/hooks.json`); machine-level `notify` belongs in
  `~/.codex/config.toml`.

Regression coverage in `.github/workflows/pr-docs.yml`
`lint-workflow-semantics` adds two static checks: #13 blocks any
hardcoded `dotnet test|build|run|format` or `npm test|run` in
non-exempt prompts and issue templates; #14 blocks any commented or
uncommented `notify = [...]` assignment from re-entering
`tooling/codex/config.toml`.

---

## [1.19.33] - 2026-05-23

### Fixed — PowerShell lifecycle paths: literal handling + accurate display (closes #74, closes #89)

Two related path-correctness bugs in the PowerShell lifecycle scripts.
Both made Windows users hit problems on legitimate project paths that
Bash users never saw.

- **Lifecycle scripts now use `-LiteralPath` for every `$Target`-derived
  file operation (closes #89).** PowerShell's bare `-Path` parameter
  treats `[`, `]`, `*`, and `?` as wildcards. A project installed at
  `C:\work\[acme]\app` failed `Test-Path` even though the directory
  existed, because the bracketed name was interpreted as a character
  class. The sweep covers `install.ps1`, `update.ps1`, `uninstall.ps1`,
  `validate.ps1`, and `new-skill.ps1` — every `Test-Path`, `Copy-Item`,
  `Remove-Item`, `Get-ChildItem`, `Get-Content`, and `Select-String`
  call on a path derived from `$Target` (or the kit source) now uses
  `-LiteralPath`. Closes the cross-platform reliability gap with the
  Bash side, which already treats paths literally when quoted.

- **`install.ps1` / `update.ps1` print accurate relative paths under
  `-Target .` (closes #74).** The display helper used
  `$dst.Replace($Target, "")` to build the printed relative path. When
  `$Target` was `.` (a common shorthand for the current dir),
  `Replace(".", "")` stripped *every* dot from `$dst` — including the
  leading dot of `.codex/`, `.claude/`, `.gemini/` directories and
  every file-extension dot. The change report (and especially the
  `-DryRun` preview) showed paths like `codex/configtoml` instead of
  `.codex/config.toml`, making users believe the script was about to
  touch wildly wrong paths. The helpers now use a true prefix-strip
  (`StartsWith` + `Substring`) so only the literal `$Target` prefix is
  removed.

Regression coverage in `.github/workflows/pr-scripts-powershell.yml`
adds two Windows-runner steps:
- *install/update/uninstall.ps1 handle paths with wildcard chars*: runs
  the full lifecycle against `lit-[acme]-<guid>` and asserts each
  stage exits 0, the expected files land, the update is a no-op
  immediately after install, and uninstall removes the kit cleanly.
- *install.ps1 with `-Target .` prints accurate relative paths*: runs
  `install.ps1 -Target .` from a sandbox CWD and asserts the printed
  output contains real dot-prefixed paths like `.claude/settings.json`
  and `.mcp.example.jsonc`, and never contains the corrupted forms
  `codex/configtoml`, `claude/settingsjson`, or `mcpexamplejsonc`.

---

## [1.19.32] - 2026-05-23

### Fixed — `update` accuracy: loud failure on missing kit source, honest preservation message (closes #58, closes #68)

Two related accuracy bugs in the install + update messaging contract:

- **`update.{sh,ps1}` no longer silently no-ops on a missing required
  source (closes #68).** `compare_and_update` / `Compare-And-Update`
  used to `[[ -f "$src" ]] || return 0` — so a packaging accident
  (CLAUDE.md / settings.json / AGENTS.md missing from the kit checkout)
  produced `Everything is up to date.` while leaving the target out of
  sync with the kit. The helper now treats a missing source as a fatal
  release-safety error and exits with a precise `Error: required kit
  source missing: <path>` message naming the file. Directories iterated
  via `update_dir` / `Update-Directory` keep their existing optional
  semantics (`[[ -d "$src_dir" ]] || return 0`).

- **Install message no longer claims update preserves local edits
  (closes #58).** The post-install hint read `To pull in kit updates
  without overwriting your local edits:`. That promise is false:
  `update` refreshes managed kit files (CLAUDE.md, AGENTS.md,
  GEMINI.md, skills/, hooks/, settings.json, …) when they differ from
  the kit source. The new wording reads `To refresh kit-managed files
  while preserving docs/ai/ and .mcp.json:` followed by a Note
  explaining that managed-file edits WILL be overwritten and only
  `docs/ai/` + `.mcp.json` are project-owned. Both `install.sh` and
  `install.ps1` print the same wording.

Regression coverage in `.github/workflows/pr-scripts-shell.yml` adds
two e2e steps: one asserts the new install message both contains the
accurate framing and no longer contains the misleading "without
overwriting" phrase; the other stands up a sandbox kit checkout,
deletes `tooling/claude/CLAUDE.md`, and verifies `update.sh` fails with
the explicit "required kit source missing" message and a non-zero exit
(no `Everything is up to date` masking).

---

## [1.19.31] - 2026-05-23

### Fixed — Gemini tooling: current model ID, Native Agent Skills documentation, Extension-mode caveat (closes #43, closes #45, closes #75)

Three related defects in the kit's Gemini surface:

- **Model name updated to a real Gemini 3 model (closes #43).** Every
  Gemini surface referenced `gemini-3.1-pro`, which doesn't exist in
  Google's official model catalog. Per the
  [Gemini API models page](https://ai.google.dev/gemini-api/docs/models),
  Gemini 3 Pro Preview is `gemini-3-pro-preview`. Updated in all eight
  references: `tooling/gemini/settings.json`, every Gemini subagent
  frontmatter (`agents/*.md`), `tooling/gemini/GEMINI.md`'s `--model`
  hint, and the README capability table.

- **GEMINI.md + README now describe Native Agent Skills (closes #45).**
  Previously the docs claimed Gemini skills load by "explicit
  `ReadFile`". Gemini CLI now natively discovers skills under
  `.gemini/skills/<name>/SKILL.md` (the layout the kit already
  installs) and activates them by `description:` frontmatter. The
  documentation now describes that path as the primary mechanism, with
  the routing table in `GEMINI.md` framed as kit policy for
  deterministic activation (so the choice doesn't drift with
  description-matching heuristics). `/skills` and `gemini skills list`
  are documented as the verification commands.

- **README spells out the Extension-mode caveat (closes #75).** When
  the kit is distributed via `gemini extensions install`, only the
  files Gemini natively loads from the extension folder (`commands/`,
  `agents/`, the `contextFileName`) reach the user's project. The
  routing table inside the installed `GEMINI.md` still references
  project-relative paths like `.gemini/skills/python/SKILL.md`, but
  the extension installer doesn't copy the kit's `.gemini/skills/`
  into the user's project — those skill files live under
  `~/.gemini/extensions/ai-agent-kit/skills/` and the relative
  references fail to resolve. The README now warns about this and
  documents the two viable workarounds (run the install script in
  parallel, or fork the extension and inline the skills you actually
  use into the shipped `GEMINI.md`).

Regression coverage in `.github/workflows/pr-docs.yml`
`lint-workflow-semantics` adds check #11: every Gemini-model
declaration across `tooling/gemini/settings.json`, every
`tooling/gemini/agents/*.md` frontmatter, `tooling/gemini/GEMINI.md`'s
`--model` hint, and the README capability table must agree on one
canonical model name — silent drift between any two surfaces fails CI.

---

## [1.19.30] - 2026-05-23

### Fixed — supply-chain accuracy: pinned MCP examples, deterministic YAML lint, honest action-pin claim (closes #65, closes #91, closes #93)

Three related supply-chain hygiene gaps in the kit's CI and copy-paste
templates:

- **`pr-docs.yml` YAML lint no longer depends on an unpinned `yq`
  (closes #91).** `lint-yaml` installed `yq` with `sudo snap install yq`
  on every run, picking up whatever the Snap channel served. A future
  `yq` release could change parsing semantics, exit codes, or expression
  syntax and break (or silently relax) the lint without any repository
  change. The lint now uses Python + PyYAML — the same parser the rest
  of `pr-docs.yml` already relies on — so the YAML check is
  deterministic and has zero external installs. The two existing
  contracts are preserved: every `*.yml` / `*.yaml` file must parse,
  and every workflow under `prompts/github-actions/` and
  `.github/workflows/` must declare `on:` and `jobs:` (with the YAML 1.1
  `on→True` quirk handled).

- **MCP `npx -y` examples are no longer unpinned (closes #93).**
  `tooling/claude/.mcp.example.jsonc`, `tooling/codex/config.toml`, and
  `skills/ai-dev/SKILL.md` shipped `npx -y @modelcontextprotocol/server-*`
  examples with no version pin. Pasted as-is, every Claude Code or
  Codex startup would install whatever the npm registry served — a
  future package release would auto-run with the configured GitHub PAT,
  filesystem path, or Postgres connection string. Every example now
  uses `@<x.y.z>` placeholder syntax (`@modelcontextprotocol/server-github@<x.y.z>`)
  and a clearly-labeled supply-chain note. A new
  `lint-workflow-semantics` static check (#10) blocks any future MCP
  example from going un-pinned.

- **The README no longer claims actions are "already pinned" (closes #65).**
  The supply-chain note said `The GitHub Actions themselves are already
  pinned (@v1 / @v0).` Major-version tags are mutable refs — the action
  owner can move them — and GitHub's own
  [hardening guide](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
  recommends full commit-SHA pins for jobs with write scopes. The README
  now describes the templates as "lightly pinned for maintainability"
  via `@vN` tags, points at the hardening guide, and explains how to
  swap tags for SHAs when the project's threat model demands it.

Regression coverage in `.github/workflows/pr-docs.yml`
`lint-workflow-semantics` adds check #10: the three files that ship MCP
`@modelcontextprotocol/server-*` examples must follow each package name
with either `@<…>` placeholder syntax or an actual `@N.N.N` version
pin, never unversioned.

---

## [1.19.29] - 2026-05-23

### Fixed — Gemini workflow routing is now disjoint and context-aware (closes #82, closes #83)

Two related defects in the Gemini workflow templates:

- **Trigger phrases no longer overlap (closes #82).**
  `gemini-pr-review.yml` gated on `contains(github.event.comment.body,
  '@gemini')`, which silently matched `@gemini-cli` too. A single
  `@gemini-cli /review` comment fired both `gemini-pr-review.yml` and
  `gemini-dispatch.yml`, producing two reviews and burning twice the
  API budget. The pr-review gate now also requires
  `!contains(github.event.comment.body, '@gemini-cli')`, so `@gemini
  review` continues to fire pr-review while `@gemini-cli /review`
  routes through dispatch only — matching what the README already
  advertises.

- **Dispatch validates route ↔ context before paying for a Gemini call
  (closes #83).** `gemini-dispatch.yml` listens to both
  `issue_comment` and `pull_request_review_comment`, but never
  checked that `/review` was actually invoked from a PR or `/triage`
  from an issue — Gemini interpreted the routing rules at
  prompt-evaluation time, so a `/review` typed on an issue produced
  empty / misleading "review" output, and `/triage` on a PR posted
  issue-triage text to a PR. A new `Validate route + context` step
  derives the route from the comment body, checks
  `IS_PR_CONTEXT` (true for `pull_request_review_comment`, or
  `issue_comment` with `github.event.issue.pull_request != null`),
  posts a friendly correction comment, and fails the job before the
  Gemini step on mismatch.

Regression coverage in `.github/workflows/pr-docs.yml`
`lint-workflow-semantics` adds two static checks:
`gemini-pr-review.yml` must include the `!contains(..., '@gemini-cli')`
clause, and `gemini-dispatch.yml` must contain the `IS_PR_CONTEXT` /
`/review` / `/triage` markers that prove the route-validation step is
in place.

---

## [1.19.28] - 2026-05-23

### Fixed — lifecycle metadata stays in sync with the installed tool set across partial commands (closes #40, closes #71)

Two related state-correctness bugs in the install / update / uninstall
lifecycle:

- **`install` overwrote `.kit-manifest` on a partial run (closes #71).**
  `install.sh` / `install.ps1` wrote the manifest with a plain `>`
  redirect, so a partial reinstall (`--tools gemini` on top of a
  codex+claude+gemini install) silently dropped every codex and claude
  entry. Later updates couldn't prune those tools' de-shipped files
  because the manifest had "forgotten" them. The write now merges the
  new entries with the manifest entries of tools NOT in this run
  (`MANIFEST_KEEP_FROM_OLD`), mirroring `update.sh`'s `KEEP_FROM_OLD`
  semantics.

- **`.kit-version` no longer drifts from the actual installed tool set
  (closes #40).** All three lifecycle scripts treated their `--tools`
  argument as if it were the installed set, not the SCOPE of the
  current run:
  - `install` now UNIONs the new `--tools` with whatever is already in
    `.kit-version`, in canonical `codex,claude,gemini` order. Adding a
    tool on top of an existing install no longer rewrites the file as
    "tools: <new tool only>".
  - `update` now stamps the file with the existing installed tool set
    (`$INSTALLED_TOOLS`), not the current `--tools`. A partial update
    refreshes only the selected tool's files without shrinking the
    recorded installed set.
  - `uninstall` now REWRITES the file with `<installed> minus
    <removed>` and filters the manifest the same way. A subsequent
    default update no longer thinks the removed tool is still
    installed (which would silently reinstall its files).

Regression coverage in `.github/workflows/pr-scripts-shell.yml` adds
two e2e steps that exercise both bugs end-to-end: a partial install
preserves the other tools' manifest entries and grows `.kit-version`
to the union; a partial update keeps the installed set unchanged; a
partial uninstall rewrites the installed set, filters the manifest,
and makes a subsequent default update a no-op (no silent reinstall of
the just-removed tool).

---

## [1.19.27] - 2026-05-23

### Fixed — `ai-fallback-dispatch` enforces its PR completion contract and runs its documented scheduled retry (closes #47, closes #55)

Two related defects in
`prompts/github-actions/ai-fallback-dispatch.yml` are addressed in one
place. Both touch the same workflow template and both affect the
completion contract documented at the top of the file
(`DONE == non-draft PR on ai/issue-<N> with body containing
'Closes #<N>'`).

- **Gate enforces the documented contract (closes #55).** All four
  `gh pr list` gate queries previously requested only `url,isDraft,state`
  and filtered on `isDraft==false AND (OPEN OR MERGED)`. They never
  checked the body, so a non-draft PR without the `Closes #<N>`
  keyword (e.g., pushed early by mistake, or pointed at a different
  issue) silently short-circuited the chain and the workflow announced
  completion. The gate now pulls `body` too and filters with
  `(.body // "") | contains("Closes #" + $n)`, matching the documented
  contract byte-for-byte. The branch + issue number now flow into the
  gates via `env:` instead of raw `${{ }}` interpolation, mirroring the
  RAW_ISSUE pattern in the setup step.
- **Scheduled retry now actually runs (closes #47).** The previous
  commented-out `# schedule:` block was unreachable in two ways: the
  job `if:` excluded `github.event_name == 'schedule'`, and scheduled
  events don't carry `github.event.issue.number` /
  `github.event.inputs.issue_number`, so `RAW_ISSUE` would be empty.
  A new `discover` job runs only on `schedule`, lists open `ai-fallback`
  issues whose branch has no contract-compliant PR yet, and dispatches
  the existing `dispatch` job once per issue via `gh workflow run`.
  The retry is idempotent (the gate is a no-op once the PR lands) and
  stops naturally when the label is removed.

Regression coverage in `.github/workflows/pr-docs.yml`
(`lint-workflow-semantics`) adds two static checks: every
gate-style `gh pr list` block in `ai-fallback-dispatch.yml` must pull
`body` AND filter on `Closes #` (catches #55 regressions), and the file
must declare both a `schedule:` cron trigger AND a job gated on
`github.event_name == 'schedule'` (catches #47 regressions).

---

## [1.19.26] - 2026-05-21

### Fixed — `new-skill` scaffolding integrity (closes #48, closes #69, closes #85, closes #96)

Four related boundary problems in `scripts/new-skill.sh` /
`scripts/new-skill.ps1` are addressed in one place. All four touched
the same file pair and all four affected the skill-scaffold contract:

- **Slug validation tightened (closes #96).** The previous
  `^[a-z][a-z0-9-]*$` regex also accepted `foo-`, `foo--bar`, and
  Windows reserved device names (`con`, `prn`, `aux`, `nul`, `com1`-`9`,
  `lpt1`-`9`). Both scripts now require lowercase alphanumeric segments
  joined by single hyphens and explicitly reject reserved device names,
  so the same slug works on every target filesystem.
- **PowerShell interpolation bug (closes #69).** The AGENTS.md routing
  row used the form `` "| ... | ``$`$Name`` |" `` which double-escaped
  the `$` and wrote `` `$$Name` `` literally into AGENTS.md instead of
  interpolating the skill slug. The row is now built by string
  concatenation, producing the same byte-for-byte output as the Bash
  side: `` `| ... | \`$<name>\` |` ``.
- **Partial routing reported (closes #85).** Previously the helpers
  printed a single per-file warning when an anchor was missing, then
  unconditionally printed `Routing: TODO row added to CLAUDE.md,
  AGENTS.md, GEMINI.md` and exited 0. Both scripts now track per-file
  insertion results, surface them in the final report, print a
  WARNING block when any anchor was missing, and exit non-zero so CI /
  release scripts cannot treat a partial scaffold as a successful one.
- **Atomic prerequisite check on Windows Git Bash (closes #48).**
  `new-skill.sh` used `python3` directly. On Windows Git Bash that name
  can resolve to the Microsoft Store launcher stub which exits non-zero
  and leaves `skills/<name>/SKILL.md` created but no routing rows
  inserted. The script now probes `python3`, `python`, and `py -3`
  *before* creating any file, exits with an actionable message if none
  works, and uses the resolved interpreter for the rest of the run.

Regression coverage in `.github/workflows/pr-scripts-shell.yml` adds:
- A `$$<name>` corruption guard on the existing scaffold step.
- A `new-skill.sh rejects malformed and Windows-reserved slugs` step
  exercising the full reject list.
- A `new-skill.sh reports partial routing accurately and exits
  non-zero` step that mutates one anchor in `CLAUDE.md`, runs the
  scaffold, and asserts both the per-file summary and the non-zero
  exit.

`.github/workflows/pr-scripts-powershell.yml` adds an
`install/update/uninstall.ps1 interpolates $Name correctly and rejects
malformed slugs` step that runs `new-skill.ps1`, asserts the AGENTS.md
row contains a single literal `$<slug>` (no `$$`), and verifies the same
malformed-slug reject list.

---

## [1.19.25] - 2026-05-21

### Fixed — `validate` requires every shipped docs/ai template and flags non-comment placeholders (closes #52, closes #95)

`scripts/validate.sh` and `scripts/validate.ps1` previously hard-coded
four required files (`PROJECT.md`, `ARCHITECTURE.md`, `COMMANDS.md`,
`TESTING.md`) and only flagged `STOP` notices plus HTML-comment
placeholders. Three shipped templates (`DECISIONS.md`, `GLOSSARY.md`,
`ROADMAP.md`) were only checked when already present, and a user could
remove the STOP notices and HTML comments while leaving visible
non-comment placeholders — table rows like `| | |`, `TBD` cells,
list items that are just `...`, and `Name: ...` / `### Flow N: ...`
patterns — and still get `All checks passed.`

Both validators now agree with the shipped template set and with the
shapes those templates actually use:

- The required list grew from 4 to all 7 templates shipped by
  `project-template/`: `PROJECT.md`, `ARCHITECTURE.md`, `COMMANDS.md`,
  `DECISIONS.md`, `GLOSSARY.md`, `ROADMAP.md`, `TESTING.md`. Removing
  any of them from `docs/ai/` now fails validation (closes #52).
- A new "non-comment placeholders" check scans each template,
  skipping fenced code blocks and HTML comments, for four high-precision
  patterns:
  - empty table rows (`| | |`, `| | | |`, …)
  - `TBD` cells (`| TBD | …`)
  - pure-dots list items (`- ...`, `* ...`, `1. ...`, `- [ ] ...`,
    `- [x] ...`)
  - placeholder key/value lines (`### Flow 1: ...`, `**Name**: ...`,
    `Goal: ...`)
  These shapes ship in the unfilled templates and never appear in
  `examples/filled-project/docs/ai/`, so they are reliable "still
  unfilled" signals (closes #95).

Regression coverage in `.github/workflows/pr-scripts-shell.yml` exercises
the `validate-example` job against three scenarios: the filled example
passes; a fresh install lists every required template, reports the
non-comment placeholders, and exits non-zero; and removing any of the
newly-required templates (`DECISIONS.md`, `GLOSSARY.md`, `ROADMAP.md`)
fails validation with a `MISSING` warning.

---

## [1.19.24] - 2026-05-21

### Fixed — bash arg parsers reject missing values and normalize `--tools` (closes #54, closes #84)

Every Bash lifecycle script reads `$2` directly for value-bearing flags
under `set -u`. Two related boundary problems:

- `./install.sh --target` (no value) tripped `set -u` with a noisy
  `unbound variable` shell error instead of a clear usage message, and
  `./install.sh --target --tools codex` silently bound `TARGET=--tools`
  before failing later with a confusing downstream error (closes #84).
- `--tools "Codex, Claude"` worked on `install.ps1` (which trims and
  lowercases each entry) but was rejected by the Bash scripts as
  `unknown tool 'Claude'`. The two entry points required different
  grammars for the same flag (closes #54).

Both are addressed in one place — the arg-parsing block at the top of
each Bash script (`install.sh`, `update.sh`, `uninstall.sh`,
`validate.sh`, `new-skill.sh`):

- A shared `require_value` guard validates that `$2` is present and is
  not another `--flag` before the assignment. Missing values now print
  `Error: --<opt> requires a value` (or `requires a value, got '--X'`
  when a flag was passed instead) and exit 1. Empty strings are still
  accepted on flags that intentionally allow them (`new-skill.sh
  --description ""` still falls back to the default text).
- A shared `normalize_tools` helper splits `--tools` on commas, trims
  whitespace, lowercases each token, and drops empties. The resulting
  `TOOL_LIST` array drives all downstream checks, and the canonical
  comma-joined form is written back to `$TOOLS` so the post-install
  header, the `.kit-version` stamp, and any future re-read see the same
  string regardless of how the user typed it.
- An empty `--tools` value (`--tools ""` or `--tools " , , "`) is now
  rejected with `Error: --tools list is empty` instead of being passed
  through as zero installable tools.

Regression coverage in `.github/workflows/pr-scripts-shell.yml` exercises
every scripts × failure-mode combination (missing value, accidental
flag-as-value, empty list) and verifies mixed-case grammar (`Codex,
Claude, GEMINI`) is accepted by `install.sh`, `update.sh`, and
`uninstall.sh`, and that the `.kit-version` stamp is written in
canonical lowercase form.

---

## [1.19.23] - 2026-05-21

### Fixed — tighten `.gitignore` hints (closes #56, closes #60, closes #64)

`install.sh` / `install.ps1` post-install `.gitignore` guidance now
matches the runtime / secret hygiene the kit actually requires:

- Add `!.env.example` and `!.env.*.example` to the recommended entries.
  The previously-suggested `.env.*` pattern silently ignored example
  files even though `env-safety.md` and the README both tell users to
  version them; without the whitelist exceptions, agents and new
  developers lose the documented `${ENV_VAR}` contract (closes #56).
- Add `.claude/session-log/` so the PreCompact snapshots written by
  `session-summary.sh` are not staged for commit by default. Those
  snapshots include `git status`, changed-file lists, and recent commit
  messages — runtime hook output, not project source (closes #60).
- When `.gitignore` is missing, print the full recommended set as a
  bootstrap recipe instead of silently skipping the hint. New projects
  were the most exposed case — exactly the ones that previously got no
  guidance at all (closes #64).
- The post-install "next steps" message now lists the local/runtime
  files explicitly (`.claude/settings.local.json`,
  `.claude/session-log/`, `CLAUDE.local.md`) instead of mentioning only
  `.claude/settings.local.json` plus a vague "and secrets".

`tooling/claude/rules/env-safety.md` and `skills/github-workflow/SKILL.md`
were also updated to spell out that the `!.env.example` /
`!.env.*.example` whitelist entries must follow `.env.*`, so the
versioned rules and the install-time hints agree on one snippet.

Regression coverage in `.github/workflows/pr-scripts-shell.yml` verifies:
the missing-`.gitignore` banner is emitted with every recommended entry;
an old short list triggers suggestions for the new entries; a complete
`.gitignore` is silent; and the recommended snippet is honoured by real
`git check-ignore` semantics — `.env` and `.env.production` ignored,
`.env.example` and `.env.production.example` versioned.

---

## [1.19.22] - 2026-05-21

### Fixed — preserve project-owned `.mcp.json` across install, update, and uninstall (closes #59)

`.mcp.json` is the file where users configure their Claude Code MCP
servers (GitHub token, filesystem paths, Postgres connection strings,
etc.). Previously every `install` rerun and every `update` overwrote it
with the kit's empty `{"mcpServers":{}}` template, silently wiping the
project's MCP configuration. `uninstall` likewise removed it, even
though its content was authored by the project rather than the kit.

`.mcp.json` is now treated as project-owned after install — the same
policy as `docs/ai/`:

- `install.sh` / `install.ps1` bootstrap an empty `.mcp.json` only when
  the file is missing, and report `[skip] .mcp.json` on reruns. It is no
  longer added to `.kit-manifest`.
- `update.sh` / `update.ps1` no longer compare or copy `.mcp.json`. They
  still refresh `.mcp.example.jsonc`, the kit's versioned reference.
- `uninstall.sh` / `uninstall.ps1` no longer remove `.mcp.json` (neither
  the manifest-based path nor the manifest-less fallback list it).
- `owning_tool` / `Get-OwningTool` no longer map `.mcp.json` to the
  `claude` scope, so an old manifest entry left over from prior installs
  is silently dropped on the next update and is also ignored by
  uninstall.

Regression coverage in `.github/workflows/pr-scripts-shell.yml` and
`.github/workflows/pr-scripts-powershell.yml` configures a real MCP
server block, then verifies the file's content hash survives an install
rerun, an update, and an uninstall, while `.mcp.example.jsonc` is still
refreshed on update and removed on uninstall.

---

## [1.19.21] - 2026-05-21

### Fixed — uninstall preserves user files inside managed tool directories (closes #51)

`uninstall.sh` and `uninstall.ps1` no longer `rm -rf` whole kit directories
such as `.claude/agents/`, `.claude/commands/`, `.claude/hooks/`,
`.claude/rules/`, `.claude/skills/`, `.codex/hooks/`, `.agents/skills/`,
`.gemini/commands/`, or `.gemini/skills/`. They now read `.kit-manifest`,
filter entries by the tool owning each path, and remove only those exact
paths. Empty parent dirs under `.agents/`, `.claude/`, `.codex/`, `.gemini/`
are pruned afterwards, so a fully-uninstalled tool still leaves no empty
shell behind.

User-added files inside any managed directory — custom agents, custom
hooks, custom skills, custom commands, and the documented
`.claude/settings.local.json` — now survive uninstall.

When `.kit-manifest` is missing (very old installs), the scripts
reconstruct the kit's installed file list from the running kit sources
and remove only those exact paths; anything else inside managed dirs is
preserved. A clear warning is printed in this fallback mode.

Regression coverage in `.github/workflows/pr-scripts-shell.yml` exercises
both the manifest-based path (kit files removed, user files kept across
all four managed tool roots) and the legacy fallback path.

---

## [Unreleased]

### Changed — CI workflows split by scope

`.github/workflows/ci.yml` (single 1091-line file, 19 jobs, triggered on
both `push` and `pull_request`) replaced with six scoped Pull Request
workflows. No job or step was dropped; behaviour is unchanged.

- `.github/workflows/pr-scripts-shell.yml` — `validate-example`,
  `smoke-install`, `lint-shell`, `e2e-lifecycle`.
- `.github/workflows/pr-scripts-powershell.yml` — `smoke-install-windows`.
- `.github/workflows/pr-hooks.yml` — `hooks-behavior` (hook exec +
  pre-bash-guard matrix + non-guard hooks matrix) and `lint-codex-hooks`.
- `.github/workflows/pr-docs.yml` — `lint-skills`, `lint-yaml`,
  `routing-consistency`, `lint-workflow-semantics`.
- `.github/workflows/pr-tooling.yml` — `lint-claude` (rules + settings +
  agents + commands + .mcp.json + webfetch), `lint-codex` (approval +
  toml + web_search + skills + no-legacy-agents), `lint-gemini`
  (subagents + commands + extension).
- `.github/workflows/pr-versioning.yml` — `no-install-output-tracked`,
  `lint-plugin-manifest`.

All six use `on: pull_request` (types `opened`, `synchronize`,
`reopened`, `ready_for_review`) — no `push`, no `pull_request_target`.
`permissions: contents: read` and PR-scoped concurrency
(`cancel-in-progress: true`) applied uniformly.

---

## [1.19.20] - 2026-05-20

### Fixed - gate legacy Codex agent cleanup on manifest ownership (closes #88)

`update.sh` and `update.ps1` no longer delete `.codex/agents/*.toml`
legacy files only because their names match old ai-agent-kit agent names.
The existing manifest GC still prunes those files when `.kit-manifest`
proves they were kit-owned leftovers, but project-owned files with the
same names are preserved and reported as skipped with unknown ownership.

Regression coverage now checks both Bash and PowerShell update paths:
unknown legacy Codex agent files survive update, while manifest-owned
legacy files are pruned.

---

## [1.19.19] - 2026-05-20

### Security - tighten pre-bash-guard destructive-command approvals (closes #63, closes #78)

Two `pre-bash-guard.sh` checks were still too broad in opposite ways:

- `rm -rf /tmp/cache /` and similar multi-operand commands were allowed
  because the presence of a temp path short-circuited the rest of the rm
  checks. The guard now scans rm operands one by one: `/tmp/...` and
  `/var/tmp/...` remain allowed only when that specific operand has no
  parent traversal, while any sibling root/home/parent/cwd/glob/variable
  operand still blocks.
- `APPROVED_DESTRUCTIVE` was accepted as a magic token anywhere in the
  shell command. The guard now requires `-- APPROVED_DESTRUCTIVE` as a SQL
  line comment after the `DROP TABLE` / `DROP DATABASE` / `DROP SCHEMA`
  statement.

Regression coverage in `.github/workflows/pr-hooks.yml` now covers the
approved SQL comment path, echo/env/string false approvals, temp-path
multi-operand rm commands, `/tmp/..` traversal, and multi-local-directory
cleanup.

---

## [1.19.18] - 2026-05-20

### Fixed — pre-bash-guard failed open when the parser chain returned empty (closes #53)

The README claimed the `jq → python3 → sed` fallback chain "never fails
open." It almost didn't — but if all three parsers returned empty
(unknown input schema, missing `tool_input.command` field, malformed
JSON, future schema change), `$CMD` stayed empty, every `grep` check
no-op'd, and the script exited 0 — i.e. the guard silently authorized
the call. A `PreToolUse(Bash)` hook must refuse what it cannot inspect.

- **`tooling/claude/hooks/pre-bash-guard.sh`** and
  **`tooling/codex/hooks/pre-bash-guard.sh`**: after the parser chain,
  add an explicit `[ -z "${CMD:-}" ]` check that blocks with a clear
  message ("could not extract the Bash command from its input ...
  refusing fail-open"). Valid inputs keep behaving identically.
- **`.github/workflows/ci.yml`**: 6 new matrix cases — empty stdin,
  empty JSON `{}`, missing `tool_input`, missing `command` field,
  empty command string, and malformed JSON each block with rc 2.
- **`README.md`**: hook table note now reflects the explicit
  fail-closed behavior instead of the previous aspirational
  "never fails open."

---

## [1.19.17] - 2026-05-20

### Fixed — pre-bash-guard let `git push <remote> :<ref>` delete remote refs (closes #62)

The README documents that `pre-bash-guard.sh` blocks ref deletion via
`git push`. The push regex covers `--delete` / `-d`, `+refspec`, and
`--mirror`, but **not** the empty-source colon refspec form
(`git push origin :main`, `git push origin :refs/heads/release`,
`git push origin :v1.0.0`). That form has no `--delete` / `-d` / `+`,
so it passed the guard while still destroying the remote pointer —
fail-open on an operation the README claims is protected.

- **`tooling/claude/hooks/pre-bash-guard.sh`** and
  **`tooling/codex/hooks/pre-bash-guard.sh`**: add a second `git push`
  check matching a whitespace-delimited token that *starts* with `:`
  (the deletion form). `main:dev` (rename push) and `HEAD:main` keep a
  non-space leading character, so they do not match. Reuses the shared
  `GIT_PREFIX` so `git -C repo push origin :main` is covered too.
- **`.github/workflows/ci.yml`**: 7 new matrix cases — 5 deletion
  shapes block (`:main`, `:refs/heads/release`, `:v1.0.0`, with `-C`,
  with a leading flag) and 2 legitimate src:dst pushes stay allowed.

---

## [1.19.16] - 2026-05-20

### Fixed — PowerShell lifecycle scripts accepted a file (or, for `update.ps1`, anything) as `-Target` (closes #67)

`install.sh` / `update.sh` refused any `$TARGET` that was not an
existing directory (`[[ ! -d ]]`). The PowerShell siblings diverged:

- `scripts/install.ps1` and `scripts/uninstall.ps1` used bare
  `Test-Path $Target`, which is true for an existing **file** too —
  so passing `README.md` (typo, wrong arg) cleared the check and the
  subsequent `Join-Path` / `Copy-Item` produced bogus
  `README.md\AGENTS.md` destinations.
- `scripts/update.ps1` had **no** `$Target` validation at all —
  `Compare-And-Update` would then begin materializing a pseudo-install
  via `New-Item -ItemType Directory` under whatever path was supplied.

This is a cross-platform parity gap on the platform where the `.ps1`
scripts are the primary entry point. CI Bash matrices never exercised
it, so a green CI masked dangerous Windows UX.

- **`scripts/install.ps1`**, **`scripts/update.ps1`**, and
  **`scripts/uninstall.ps1`**: validate `$Target` with
  `Test-Path -LiteralPath $Target -PathType Container` before any
  I/O. `-LiteralPath` avoids surprises with `[`/`]` / wildcard chars
  in real Windows paths; `-PathType Container` rejects files. The
  failure message matches the Bash side verbatim
  (`"Target directory does not exist: $Target"`, exit 1).
- **`.github/workflows/ci.yml`**: new `smoke-install-windows` step
  runs the 3 PS scripts × 2 invalid inputs (missing path, file path)
  and asserts each errors with the documented message — six
  regression assertions on the platform where the bug lived.

---

## [1.19.15] - 2026-05-20

### Fixed — pre-bash-guard bypassed by Git global options (closes #66)

`git -C <dir>`, `git -c <key=val>`, `git --git-dir=<path>`, and
`git --work-tree=<path>` are standard Git syntax that automation
snippets and agents naturally emit. The existing per-subcommand
patterns required `git` to be **immediately** followed by the
subcommand, so `git -C repo push --force`, `git --git-dir=.git push
--mirror`, `git -c protocol.version=2 push --delete`, and the same
shape for `branch`/`reset`/`update-ref` all bypassed the guard — even
though the bare `git push --force` form was blocked.

- **`tooling/claude/hooks/pre-bash-guard.sh`** and
  **`tooling/codex/hooks/pre-bash-guard.sh`**: introduce a shared
  `GIT_PREFIX` regex that matches `git` plus zero or more global
  options before the subcommand (`-C dir`, `-c key=val`, `--git-dir=`/
  `--git-dir `, `--work-tree=`/`--work-tree `). Reuse the prefix in
  the push / branch / update-ref / reset / switch / clean checks.
- **`.github/workflows/ci.yml`**: 7 new matrix cases (`-C push
  --force`, `-C push --delete`, `--git-dir push --mirror`, `-c push
  --delete`, `-C reset --hard`, `-C branch -D`, and a passthrough for
  `git -C repo status`).
- **`README.md`**: hook coverage tables note that global options
  (`git -C`, `--git-dir`, …) before the destructive subcommand are
  covered.

---


## [1.19.14] - 2026-05-20

### Fixed — pre-bash-guard missed split / bundled `git branch` force-delete (closes #79)

The guard regex only matched `git branch -D` and the fixed long forms
`--delete --force` / `--force --delete`. Git accepts any combination
of `-d`/`--delete` with `-f`/`--force` (split as `-d -f`, `-f -d`,
`--delete -f`, `-d --force`, or bundled as `-df` / `-fd`) and treats
them as force-delete — same destructive intent as `-D`, but the
guard let them through.

- **`tooling/claude/hooks/pre-bash-guard.sh`** and
  **`tooling/codex/hooks/pre-bash-guard.sh`**: replace the single
  regex with a paired check — detect `git branch`, then require both
  a delete-intent flag (`-d` short-block or `--delete`) and a
  force-intent flag (`-f` short-block or `--force`). Bundled short
  flags (`-df`, `-fd`) are covered via `-[a-z]*d[a-z]*` /
  `-[a-z]*f[a-z]*`. Plain `-d`, plain `-f`, `-m`, and branches whose
  name contains `-D` stay allowed.
- **`.github/workflows/ci.yml`**: 8 new matrix cases.

---

## [1.19.13] - 2026-05-20

### Fixed — pre-bash-guard ignored destructive `git switch` variants (closes #87)

`Bash(git switch:*)` was in the Claude allow list and neither hook
inspected the command. That left `--discard-changes`, `--force` /
`-f`, and `-C` / `--force-create` (which throw away local mods or
reset a branch pointer) silently allowed even though comparable
`git checkout` / `git reset` forms are blocked.

- **`tooling/claude/hooks/pre-bash-guard.sh`** and
  **`tooling/codex/hooks/pre-bash-guard.sh`**: block `git switch`
  with `--discard-changes`, `--force`, `-f`, `-C`, or
  `--force-create`. Plain `git switch <branch>`, `git switch -c <new>`,
  `git switch -`, and `git switch --detach` stay allowed.
- **`tooling/claude/settings.json`**: add explicit deny entries for
  the destructive variants alongside the broad `Bash(git switch:*)`
  allow.
- **`.github/workflows/ci.yml`**: 7 new matrix cases.
- **`README.md`**: hook coverage tables now mention destructive
  `git switch`.

---

## [1.19.12] - 2026-05-20

### Fixed — pre-bash-guard never inspected `git clean` (closes #97)

`git clean -f` (and the combined / split forms `-fd`, `-fdx`,
`-ffdx`, `-d -f`, `--force`) deletes untracked files irrecoverably.
The shared guard had no `git clean` check at all; only the Claude
`settings.json` denied the single exact shape `git clean -fd:*`,
leaving Codex unprotected and most flag permutations uncovered.

- **`tooling/claude/hooks/pre-bash-guard.sh`** and
  **`tooling/codex/hooks/pre-bash-guard.sh`**: add a regex that
  matches any short-flag block containing `f` (covers `-f`, `-fd`,
  `-df`, `-fdx`, `-ffdx`...) or the long `--force`. `git clean -n` /
  `--dry-run` (no force flag) stays allowed as a safe preview.
- **`tooling/claude/settings.json`**: expand the deny list from a
  single `git clean -fd:*` entry to cover the common destructive
  forms (`-f`, `-fd`, `-fdx`, `-df`, `--force`).
- **`.github/workflows/ci.yml`**: 7 new matrix cases (forceful
  variants blocked, `-n` / `--dry-run` allowed).
- **`README.md`**: hook coverage tables now mention destructive
  `git clean` alongside the other Git destructive families.

---

## [1.19.11] - 2026-05-20

### Fixed — pre-bash-guard let `--force-with-lease` get blocked (closes #72)

The `git push` regex anchored `-f` with `([[:space:]]|$)` but left
`--force` as a bare substring. That substring also matches inside
`--force-with-lease`, so the very flag the block message recommends
("Use --force-with-lease only after explicit approval") was itself
denied by the same guard — with no override path.

- **`tooling/claude/hooks/pre-bash-guard.sh`** and
  **`tooling/codex/hooks/pre-bash-guard.sh`**: anchor `--force` with
  `([[:space:]]|$)` so only the exact `--force` flag matches.
  `--force-with-lease` now passes through the hook and is left to the
  agent's native approval mechanism (per the message's own contract).
- **`.github/workflows/ci.yml`**: matrix flipped from `expect 2
  "force-with-lease"` to `expect 0 "force-with-lease"`; the
  `--force` / `-f` / `+refspec` / `--mirror` / `--delete` cases stay
  blocked.

---

## [1.19.10] - 2026-05-20

### Fixed — consolidation sweep (closes the v1.19 audit series)

Doc-staleness and one local-tool quirk that accumulated across the
v1.19.0–v1.19.9 series and never made it into a sibling file. Pure
docs/text + one `.ps1` ASCII-ification; no behaviour change.

- **`tooling/codex/AGENTS.md` — guard table row** mirrored README's
  v1.19.0 expansion: now lists the post-Pass 0 / `pre-bash-guard.sh`
  coverage (`+refspec`, `--mirror`, `--delete`/`-d`, `git branch -D`,
  `update-ref -d`, `reset --hard/--keep`, `rm -rf` on cwd/glob/variable,
  `${IFS}` obfuscation, SQL `DROP`) and the **best-effort, not a sandbox**
  framing.
- **`tooling/codex/AGENTS.md` — parser description.** Was still
  "probed jq → python3 → sed chain". Pass 0 (v1.19.0) collapsed the
  parser to a single invocation per backend (empty-output fallthrough
  to the next on a missing/broken interpreter). Wording aligned with
  the README fix.
- **`tooling/codex/AGENTS.md` — `[shell_environment_policy]` scrub
  list.** Was the pre-Pass 0 set (`*_SECRET`/`*_TOKEN`/`*_KEY`/
  `*_PASSWORD`/`OPENAI_*`/`ANTHROPIC_*`/`AWS_*`/`GCP_*`). v1.19.0 added
  `GOOGLE_*` and the connection-string class (`*_URL`/`*_URI`/`*_DSN`,
  which `DATABASE_URL`-style values matched none of) to `config.toml`;
  AGENTS.md still described the old list.
- **`scripts/new-skill.ps1` — ASCII-only.** The file used UTF-8 box-
  drawing separators (`──`) and an em-dash. Windows PowerShell **5.1**'s
  `Parser::ParseFile` defaults to ANSI on a UTF-8-no-BOM file and would
  fail to parse the script, so a 5.1 user running `new-skill.ps1`
  directly hit a parse error (CI uses `pwsh` PS 7+, so this never broke
  CI — local-only quirk flagged at the end of Pass 7). All separators
  replaced with ASCII `--` / `-`. Verified `new-skill.ps1` now parses
  cleanly under Windows PowerShell 5.1 with zero non-ASCII bytes left.

### v1.19.x — series summary

This is the closing pass of a 10-pass audit-driven series:

| Version | Pass | Subject |
|---|---|---|
| 1.18.1 | precursor | guard `-f`/rm-rf false-positives + portable DROP + `update.sh chmod` |
| 1.19.0 | full audit batch | gemini-issue-triage CRITICAL, guard hardening, secret scrub, npm/dotnet narrowing, `gemini` toml paths, `new-skill.ps1` CRLF/BOM, perf double-spawn collapse, ci concurrency, +`lint-shell` + `e2e-lifecycle` |
| 1.19.1 | Pass 1 (H3) | `GEMINI.md` Safety section — Gemini has 0 hooks |
| 1.19.2 | Pass 2 (M3) | discoverability of not-installed artifacts (`gemini-extension.json`, `global-config-template.toml`) |
| 1.19.3 | Pass 3 (MEDIUM-2) | manifest-diff GC in `update.sh` + `install.sh` writes `.kit-manifest` |
| 1.19.4 | Pass 4 | pin `gemini_cli_version: 0.42.0` (supply-chain) |
| 1.19.5 | Pass 5 | move commit rules into routers; drop the never-loading `commit-style.md` rule (GC of Pass 3 prunes it from existing installs) |
| 1.19.6 | Pass 6 | Gemini security-reviewer parity — add `list_directory` |
| 1.19.7 | Pass 7 | bash↔ps1 parity sweep — `.ps1` manifest GC + version-drift guard (5 → 4 sources enforced) |
| 1.19.8 | Pass 8 | `format-on-save` parser fallback + `dotnet` walk-up + java/kotlin |
| 1.19.9 | Pass 9 | non-guard hooks: kill the cross-language interpolation footgun in `notify-done`; CI behavioural coverage for the 3 non-guard hooks |
| 1.19.10 | Pass 10 | this consolidation |

---

## [1.19.9] - 2026-05-20

### Fixed — non-guard hooks: hardening + first behavioural CI coverage

Three improvements to the hooks the previous audit flagged as
unguarded: `notify-done.sh` (Claude + Codex), `session-summary.sh`,
plus the CI coverage gap for *every* hook that wasn't `pre-bash-guard`.

- **`notify-done.sh` (both): kill the cross-language interpolation
  footgun.** The macOS (`osascript`) and Windows (`powershell.exe`)
  branches built script source in another language and interpolated
  `$MSG` into the string body. MSG is hardcoded today, but the moment
  anyone wires turn/file data into it, an attacker controlling that
  data could break out of the quoting and run arbitrary AppleScript /
  PowerShell under the user's account. Restructured so `MSG`/`TITLE`
  are passed **only via the process environment** — never inlined into
  a command-string source — and each backend reads them from there
  (`system attribute "MSG"` for AppleScript, `$env:MSG` for
  PowerShell). Stays safe even if MSG becomes dynamic. Added `|| true`
  on each branch so a failed delivery never makes the hook rc≠0 (CI on
  headless ubuntu now exercises this).
- **`session-summary.sh`: anchor on `$CLAUDE_PROJECT_DIR`.** Was
  writing `.claude/session-log/` relative to the caller's cwd — not
  guaranteed to be the project root and could drop the log under an
  arbitrary directory. Now `cd`s to `$CLAUDE_PROJECT_DIR` (Claude Code
  sets it), or `$PWD` as fallback, and bails silently if the directory
  doesn't exist.
- **CI: first behavioural coverage for the non-guard hooks.** The
  `pre-bash-guard` matrix was the only behavioural test in the kit
  (the prior audit explicitly flagged this gap). A new step in
  `lint-rules` pins minimal invariants — every non-guard hook must
  stay rc=0 on the realistic inputs it receives, even with no
  formatters / no display / no git state:
  - `format-on-save` (Claude): valid JSON with missing file, empty
    stdin, malformed JSON, missing `file_path` key
  - `format-on-save` (Codex): clean repo (no modified files)
  - `notify-done` (both): headless invocation
  - `session-summary` (Claude): no git state, asserts the snapshot
    file was actually written under `$CLAUDE_PROJECT_DIR/.claude/
    session-log/`

Locally verified 8/8 PASS on this matrix.

---

## [1.19.8] - 2026-05-20

### Fixed — format-on-save robustness (audit MEDIUM-3, MEDIUM-4, LOW-3)

Three related defects in `tooling/{claude,codex}/hooks/format-on-save.sh`:

- **MEDIUM-3 (Claude only): single-parser JSON extraction.** The hook
  parsed Claude's hook stdin with `python3` only — the same Windows
  App-Execution-Alias stub the guard documents at length would yield
  empty stdout and the hook would silently skip every file write.
  Now uses the **same `jq → python3 → sed` fallback chain as the
  guard** (with the Pass 0 empty-output-fallthrough design — no
  per-parser probe). A broken interpreter falls through to the next;
  sed is dependency-free and always runs as the last resort. (The
  Codex hook enumerates git-modified files instead of parsing the
  hook payload, so this didn't apply there.)
- **MEDIUM-4 (both hooks): `dotnet format --include` semantics.**
  `dotnet format` needs to find a project/solution — `--include` only
  *filters* within one. The hook was running it with whatever cwd
  Claude/Codex invoked it from, so any C# file outside that cwd's
  project silently failed (masked by `2>/dev/null`). The formatter
  effectively never ran. Now both hooks walk up from the changed file
  to the nearest enclosing `.sln`/`.csproj` via a new
  `find_dotnet_project` helper, then `dotnet format <project> --include
  <file>`. If no enclosing project is found, the case is skipped
  silently — that's a legit case (file isn't in a .NET project).
- **LOW-3 (both hooks): no Java/Kotlin formatter despite a
  `java-kotlin` skill.** Added `java) google-java-format -i` and
  `kt|kts) ktlint -F`. Both gated on `command -v` like every other
  formatter; if the tool isn't installed, the case is a no-op.

Locally verified: `bash -n` clean on both hooks; the Claude hook stays
`rc=0` on valid JSON, empty input, malformed JSON, and a missing file
path (no crashes under `set -euo pipefail`); `find_dotnet_project`
walks up to the right project for a nested `.cs` file and returns
nothing (handled cleanly) when there is no enclosing project.

---

## [1.19.7] - 2026-05-20

### Fixed — bash ↔ PowerShell parity sweep (the rest of audit MEDIUM-2)

Pass 3 added the manifest-diff GC + `.kit-manifest` to the bash scripts
only. Pass 7 brings the PowerShell trio to functional parity and fixes
a silent version drift discovered while doing so.

**Silent drift — caught and guarded.** `install.ps1` and `update.ps1`
held `$KitVersion = "1.18.0"` across every release since v1.18 (Windows
users running them stamped a stale version into `.kit-version`). The
`lint-plugin-manifest` CI job only inspected `install.sh`'s
`KIT_VERSION`, so the drift was invisible. Fixed and the CI check is
now extended to enforce `$KitVersion` in both `.ps1` scripts **and**
`KIT_VERSION` in `update.sh` all match `install.sh`'s `KIT_VERSION` —
this class of drift can't recur silently.

**Manifest GC parity.**
- `install.ps1` now writes `.kit-manifest` (every kit artifact, filtered
  by `Get-OwningTool` so `docs/ai/` and any non-kit path is never in it).
- `update.ps1` mirrors `update.sh`: tracks `$Managed` + `$KeepFromOld`,
  diffs against the old manifest, and prunes paths no longer shipped
  (scoped to `-Tools`, never `docs/ai/` or user files, first-run is
  baseline-only, `-DryRun` reports without deleting).
- `uninstall.ps1` removes `.kit-manifest` alongside `.kit-version` (only
  when all installed tools are being removed); header docstring updated.
- Manifest is written in **UTF-8 without BOM** with **forward-slashed**
  paths (new `Write-Utf8NoBom` helper) so a Windows install + Git-Bash
  update on the same project read the same file.

**`update.ps1` speed-up.** Replaced `Get-FileHash` MD5 on every src+dst
pair with a length+byte-stream early-exit `Compare-Files` — the
`cmp -s` equivalent. Same correctness, no hashing of whole files when
they obviously differ.

**CI guards.**
- `lint-plugin-manifest`: enforce `install.ps1` / `update.ps1`
  `$KitVersion` and `update.sh` `KIT_VERSION` all == `install.sh`.
- `smoke-install-windows`: assert `install.ps1` wrote `.kit-manifest`,
  with no BOM, no backslash paths, and a plausible entry count.

---

## [1.19.6] - 2026-05-20

### Fixed — Gemini security-reviewer was missing list_directory

Cross-tool parity check on the 5 subagents found one real asymmetry
(the audit's broader claim that Gemini's security-reviewer "could not
Bash" was incorrect — it has `run_shell_command`). The four other
Gemini agents (architect, code-reviewer, codebase-investigator,
test-runner) carry `list_directory` as the kit's chosen Glob-
equivalent; `security-reviewer` did not — yet finding entry points,
`.env` files, and config surfaces is exactly the kind of file
discovery a security review needs.

- `tooling/gemini/agents/security-reviewer.md`: added `list_directory`
  to the `tools:` list. The agent now matches Claude's
  `Read, Glob, Grep, Bash` grant — Gemini equivalent
  `read_file, list_directory, search_file_content, run_shell_command`.

Subagent tool-grant matrix verified across the 5 agents × 3 tools
(`architect`, `code-reviewer`, `codebase-investigator`,
`security-reviewer`, `test-runner` — Claude / Codex prose / Gemini).
All five are now at functional parity on Claude ↔ Gemini.

---

## [1.19.5] - 2026-05-20

### Fixed — commit-style rule never actually triggered (audit)

`tooling/claude/rules/commit-style.md` was path-scoped to
`.github/**`/`.gitignore`/`.gitattributes`. Commit-message conventions
apply to every commit, but Claude only auto-loads a rule when an opened
file matches its `paths:` — so a normal code change (`src/app.ts`)
never loaded the rule. The convention was effectively unenforced at
the exact moment it matters most. Architecturally a commit-policy rule
is **not** path-scoped, so the file was a design mis-fit there.

- `tooling/claude/rules/commit-style.md` **removed**. Existing installs
  will have it pruned automatically by `update.sh` on the next run (the
  manifest-diff GC from v1.19.3 was built for exactly this case).
- The commit rules now live directly in `CLAUDE.md`, `AGENTS.md`, and
  `GEMINI.md` under `## Git rules` — Conventional Commits format with
  types list, ≤72-char imperative subject, breaking-change footer, one
  concern per commit, never-commit list. These routers are loaded every
  session, so the rules apply to every commit, not only when editing
  files under `.github/`.
- README "Rules" mention drops `commit-style.md` (3 rules left:
  `test-naming`, `migration-safety`, `env-safety` — all genuinely
  path-scoped) and points at the routers for commit policy.
- CI `smoke-install` file lists (bash + windows) updated to match the
  3-rule reality. `lint-rules` already only checks that present rules
  declare `paths:`, so it stays green.

---

## [1.19.4] - 2026-05-19

### Security — pin `gemini_cli_version` in the workflow templates (audit MEDIUM)

All five Gemini workflow templates used `gemini_cli_version: "latest"`.
The `run-gemini-cli` action installs that CLI and runs it with the
job's scope (up to `contents: write` + `pull-requests: write` in
`ai-fallback-dispatch.yml`), so an unpinned `latest` would auto-execute
any future — possibly compromised or regressed — release. The action
itself was already pinned (`@v0`); the CLI it downloads was not.

- `ai-fallback-dispatch.yml`, `gemini-assistant.yml`,
  `gemini-dispatch.yml`, `gemini-issue-triage.yml`,
  `gemini-pr-review.yml`: `gemini_cli_version` pinned to `0.42.0`
  (current npm `latest` of `@google/gemini-cli`, looked up at the npm
  registry — not guessed), each with a comment explaining the
  supply-chain rationale and a link to the release notes for deliberate
  bumps.
- README "GitHub Actions templates": note that the templates pin the
  CLI version on purpose and how to bump it.

No behaviour change for users on 0.42.0; older/newer pins are a
one-line, reviewed edit.

---

## [1.19.3] - 2026-05-19

### Added — manifest-diff garbage collection in `update.sh` (audit MEDIUM-2)

Before, `update.sh` only had a hardcoded cleanup for one legacy case
(`.codex/agents/*.toml`). If a later kit version renamed or removed any
managed file, `update` added the new one but left the old one behind
forever — installed `.claude/` etc. drifted silently from the source.

- `install.sh` now writes `.kit-manifest` (every kit-managed path; tool
  files only — `docs/ai/` is excluded via `owning_tool`).
- `update.sh` diffs the newly-shipped set against the old manifest and
  **prunes** anything no longer shipped. Safety constraints:
  - only paths under a known kit root are ever considered (`docs/ai/`,
    `.kit-version`, `.kit-manifest`, user files can never match);
  - first run with no manifest prunes nothing — it only writes the
    baseline, so the GC is inert until there is something to diff;
  - a partial `--tools` run never prunes another tool's files and
    preserves that tool's manifest entries for a later full run;
  - `--dry-run` reports `PRUNED …` without deleting.
- `install.sh`'s `copy_dir` switched from `find | while` (a pipe
  subshell that lost array state — the prior audit's MEDIUM-1) to
  process substitution, so `MANAGED` accumulates reliably and the
  manifest is complete.
- `uninstall.sh` removes `.kit-manifest` with `.kit-version` (only when
  all tools are removed); header docstring updated.
- CI `e2e-lifecycle` gains a GC test: a de-shipped file is pruned while
  a user file, `docs/ai/`, and another tool's files survive (incl. the
  partial-`--tools` safety case).

PowerShell parity (`update.ps1` GC, `install.ps1` manifest) is
intentionally deferred to the bash↔ps1 parity pass — bash-only is not a
regression (no manifest ⇒ no prune ⇒ prior behaviour) and is documented.

---

## [1.19.2] - 2026-05-19

### Documentation — discoverability of not-installed artifacts (audit M3)

Audit M3 flagged that `tooling/gemini/gemini-extension.json` and
`tooling/codex/global-config-template.toml` are maintained (the former's
version is CI-pinned to `KIT_VERSION`) but never touched by
install/update/uninstall. Investigation: **not a bug** — both are
intentionally not-installed (one is a per-user `~/.codex/config.toml`
template, the other a Gemini-extension distribution scaffold). The real
gap was zero discoverability. Fixed with docs only:

- `tooling/codex/AGENTS.md` — new "Personal config (`~/.codex/config.toml`)"
  section with the `cp tooling/codex/global-config-template.toml
  ~/.codex/config.toml` step and the closest-wins note.
- `README.md` — new "Optional artifacts (not auto-installed, by design)"
  table under Quick start, documenting both files, their purpose, and how
  to use them; states accurately that only `gemini-extension.json`'s
  version is CI-pinned.

No script/behaviour change.

---

## [1.19.1] - 2026-05-19

### Fixed — Gemini safety-parity disclosure (audit H3)

Claude and Codex ship the `pre-bash-guard` PreToolUse hook; Gemini CLI
has no hook system, so on Gemini the kit's destructive-command guard
does not exist — yet `GEMINI.md` never said so while `AGENTS.md` has a
full Lifecycle-hooks section. A user trusting "write once, deploy on 3
tools" would assume equal protection, and `--approval-mode yolo` removes
the only safety layer with nothing behind it.

- `tooling/gemini/GEMINI.md` — new "Safety model — read this" section
  (after the approval-mode docs): no hook layer here; approval mode is
  the sole runtime boundary; `yolo` is materially riskier than Claude
  `--dangerously-skip-permissions` / Codex `approval_policy=never`
  (those keep the guard/deny-list as a second layer); Git/Security rules
  are self-enforced; the real net is review + CI.

Docs-only, one file.

---

## [1.19.0] - 2026-05-19

Hardening pass from a 10-angle audit (docs-vs-reality, security, scripts,
workflows, cross-tool parity, structure, CI coverage, performance),
cross-verified. Documented here retroactively — the work shipped via PR
review without a CHANGELOG entry; this records the *what* and *why*.

### Security — GitHub Actions workflow templates

- **`gemini-issue-triage.yml` (was the worst sink).** `issues: opened`
  is openable by *any* external user; the issue title/body was
  interpolated raw into the Gemini prompt with `issues: write` and no
  data-fence and no author gate. Now the issue is captured via
  `env:` + `gh --jq` to a file and fenced as untrusted DATA — the same
  model `ai-fallback-dispatch.yml` already used. CI's semantics linter
  was blind to it (it only audited comment-triggered workflows); a new
  check now fails any workflow that splices `github.event.*.(title|body)`
  into a `prompt:` block.
- **`gemini-assistant.yml` / `gemini-dispatch.yml`** — comment body now
  `env:`-captured and DATA-fenced instead of inlined into the prompt.
- **`ai-fallback-dispatch.yml`** — the free-text
  `workflow_dispatch.inputs.issue_number` was interpolated into a `run:`
  shell (script-injection sink, insider-only but real). Now passed via
  `env:` and validated `^[0-9]+$` before use.

### Security — pre-bash-guard (Claude + Codex)

- Force-push detection widened beyond `-f/--force`: now also blocks the
  `+refspec` force form, `--mirror`, and `--delete`/`-d`.
- Blocks `git branch -D`, `git update-ref -d`, and `git reset --keep`
  (in addition to `--hard`).
- Blocks `rm -rf` with a variable / command-substituted operand
  (`$VAR`, `"$(...)"`, `` `...` ``) and the `${IFS}` word-split
  obfuscation.
- Added an explicit **SCOPE/LIMITS** header: this is a best-effort
  denylist, not a sandbox — encoded/obfuscated payloads still pass, so
  the tool's own sandbox/approval mode remains the real boundary. Honest
  framing over a false sense of safety.

### Security — permission & secret posture

- **Behaviour change:** `tooling/claude/settings.json` narrowed
  `Bash(npm:*)` / `Bash(dotnet:*)` to safe subcommands
  (`npm install|ci|run|test|audit`, `dotnet build|test|restore|format|run`).
  `npm publish`, `npm token`, `dotnet nuget push` now prompt instead of
  auto-approving. Revert per project if you relied on the broad grant.
- Secret scrub widened in `tooling/codex/config.toml` and
  `tooling/gemini/settings.json`: added `*_URL` / `*_URI` / `*_DSN`
  (DATABASE_URL-class connection strings carry `user:pass@host` and
  matched none of the old patterns) and `AWS_*` / `GCP_*` / `GOOGLE_*`
  to Gemini (it was strictly weaker than Codex).

### Fixed

- **5 Gemini command `.toml` files** (`code-review`, `dependency-update`,
  `on-call`, `performance-audit`, `security-audit`) told the agent to
  `Read skills/<n>/SKILL.md` — a path that does not exist in an installed
  project (skills land in `.gemini/skills/`). A broken reference in
  *every* Gemini install; now `.gemini/skills/<n>/SKILL.md`.
- **`new-skill.ps1`** silently skipped all three routing-table inserts on
  a Windows (CRLF) checkout: the anchors used bare `\n` but
  `Get-Content -Raw` returns `\r\n`, so `IndexOf` never matched. It also
  wrote a UTF-8 BOM via `Set-Content -Encoding utf8`. Now CRLF-agnostic
  and writes UTF-8 *without* BOM (LF), matching `new-skill.sh`.

### Performance

- `pre-bash-guard` ran the JSON parser **twice** per Bash call (a probe
  then the real parse) for jq and python — ~60–160 ms of avoidable
  latency on *every* command when jq was absent. Collapsed to one spawn
  per parser; correctness is preserved by the empty-output fallthrough
  (a broken/missing parser yields nothing on stdout and we move on).
- `ci.yml` gained a `concurrency` group with `cancel-in-progress`
  (rapid pushes were stacking full ~18-job matrices); push branch filter
  widened to `chore/**` and `claude/**`.
- `install.sh`/`update.sh` use `chmod ... {} +` (batched, not one fork
  per file); `update.sh` uses `cmp -s` instead of hashing both whole
  files with md5 (early-exit on first differing byte; the
  `md5sum`/`md5 -q` portability helper is gone).

### CI (locks the above against regression)

- pre-bash-guard behavioural matrix extended with every new block/allow
  case (refspec, mirror, delete, branch -D, update-ref, reset --keep,
  `$VAR`/`$(...)`/`$IFS` targets, plus the safe cases that must still
  pass).
- New `lint-shell` job: `bash -n` + `shellcheck` on every script and hook
  (previously a syntax error in a hook only failed in the user's repo).
- New `e2e-lifecycle` job: real (non-dry-run) install → update no-op →
  uninstall (clean, `docs/ai/` preserved) → `new-skill` scaffolds a
  routable, CI-valid skill. Previously only `--dry-run` was exercised and
  `new-skill` was entirely untested.
- `routing-consistency`: reverse check (a router row pointing at a
  deleted skill now fails), Gemini-commands path check, 5-subagent name
  parity across the 3 tools, and `CHANGELOG`-top == `KIT_VERSION` +
  documented "30 skills" count pin.
- `smoke-install-windows` asserts every `.ps1` parses.

### Docs

- README hook tables, the parser-chain description (no longer "probed";
  it's a fallthrough chain now), and the update-mechanism wording
  ("MD5-diff" → "content-diff") corrected to match the shipped behaviour.
- `uninstall.sh` header now lists everything it actually removes
  (`.mcp.json`, Codex config/hooks, commands, rules, `.kit-version`),
  not a stale subset.

---

## [1.18.1] - 2026-05-19

### Fixed — pre-bash-guard false-positive and missed cases

Documented retroactively (shipped via PR #35).

- **False positive:** `git push.*(--force|-f)` blocked any branch name
  containing the substring `-f` (e.g. `git push origin feature-foo`,
  `my-feature`). Now matches a real `-f`/`--force` *flag* only;
  `-f`/`--force`/`--force-with-lease` still blocked.
- **Missed game-over cases:** the guard only blocked `rm -rf` targets
  starting with `/ ~ ..`, so `rm -rf .`, `rm -rf ./`, `rm -rf *` passed;
  the shape detector was also lowercase-only (`-Rf` slipped) and missed
  long `--recursive --force`. All now blocked while `./build`,
  `node_modules`, `/tmp/*` stay allowed.
- **Portability:** the SQL-DROP guard used `\s` (a GNU extension) — on
  BSD/macOS grep it failed open. Now `[[:space:]]`, consistent with the
  rest of the hook.
- **`update.sh`** now `chmod +x` the installed hooks (mirrors
  `install.sh`) so a hook added in a later version isn't left
  non-executable on the update path (a silently dead PreToolUse guard).
- CI hook matrix extended with the regression cases that previously
  slipped.

---

## [1.18.0] - 2026-05-17

### Added

- **`prompts/github-actions/ai-fallback-dispatch.yml`** — sequential
  Claude→Codex→Gemini orchestrator for auto-implementing a labeled issue.
  Robustness comes from a git-observable completion gate (a non-draft PR on
  `ai/issue-<N>` with `Closes #<N>`), not exit codes: all three providers
  share one branch so a later one resumes partial work, the chain only
  advances when a provider did not finish, and re-runs are idempotent. Honest
  limit documented: it cannot guarantee one uninterrupted run, only that the
  issue keeps getting picked up until a PR lands; "first available provider"
  is approximated by sequential fallback + an optional capped scheduled retry.
  README GitHub Actions table + caveat note updated.

---

## [1.17.0] - 2026-05-16

### Changed — all agents now run on the top model (reverses v1.13 tiering)

User feedback: down-tiered `codebase-investigator` and `test-runner`
(`claude-haiku-4-5` / `gemini-2.5-flash`) produced reports that weren't
consistently actionable. **Report quality wins over token cost.**

All five agents now run on the most capable model, uniform tier, no
exceptions:

- Claude: `codebase-investigator` + `test-runner` `claude-haiku-4-5` →
  `claude-opus-4-7` (the other three were already `opus-4-7`).
- Gemini: `codebase-investigator` + `test-runner` `gemini-2.5-flash` →
  `gemini-3.1-pro` (the other three were already `gemini-3.1-pro`).
- Codex: unchanged — its skill spec has no per-skill model; all run on the
  session model (already uniform).

Token efficiency still comes from **lazy-loaded skills** and **short
routers**, not from down-tiering agents. The README documents how to set
`claude-haiku-4-5` / `gemini-2.5-flash` back on the read-only agents per
project for anyone who prefers the cost trade-off. `maxTurns` / `max_turns`
per-agent budgets are unchanged.

---

## [1.16.9] - 2026-05-16

### Fixed (README — user-reported)

- **`+ Gemini` rendered as a stray bullet.** The "all three tools"
  sentence wrapped as `(Codex + Claude\n+ Gemini)`; the line starting with
  `+ ` was parsed by Markdown as a list item, so Gemini appeared as a
  detached bullet and looked excluded from the install. Rewritten to
  "(Codex, Claude and Gemini)" with no line-start `+`.
- **Install examples omitted Gemini.** Under a heading that says "all 3
  tools", the commands were `-Tools codex,claude` / `--tools codex,claude`
  (Gemini missing). Corrected to `codex,claude,gemini`, with a note that
  omitting the flag yields the same all-three default.

Verified by **executing the documented command**: `install.sh --target …
--tools codex,claude,gemini` → 156 files, `CLAUDE.md`+`AGENTS.md`+`GEMINI.md`
present, Gemini fully installed (settings + 11 commands + 5 agents + 30
skills). Default install (no `--tools`) also lays down all three
(`TOOLS="codex,claude,gemini"`). No other line-start-`+` bullet drift in the
README.

---

## [1.16.8] - 2026-05-16

Holistic confirmation pass (language coverage, agent parity, token efficiency,
best-practice enforcement, doc freshness). The kit is sound; two stale README
claims fixed.

### Verified sound (no change)

- **Language coverage:** 30 skills span every major backend (dotnet,
  java-kotlin, python, node, go, rust), frontend (angular, vue, svelte,
  react), mobile (rn, flutter), data, infra, and cross-cutting concern —
  **all 30 routed in CLAUDE.md, AGENTS.md and GEMINI.md** (parity verified).
- **Agent parity:** the same 5 agents exist in all 3 tools with the same
  roles. Model tiering is consistent: high-stakes (`architect`,
  `security-reviewer`, `code-reviewer`) → top model (Claude `opus-4-7` /
  Gemini `3.1-pro`); routine (`codebase-investigator`, `test-runner`) → cheap
  model (Claude `haiku-4-5` / Gemini `2.5-flash`).
- **Token efficiency:** short routers (~216-241 lines), lazy-loaded skills
  (only the relevant ~250-line skill loads, never all 30), cheap models on the
  high-frequency agents. Not a token sink by design.
- **Best practices:** every one of the 30 skills carries a CI-enforced "Final
  response requirements" section; path-scoped rules + the destructive-command
  guard apply on every tool.

### Fixed (README drift)

- Model-strategy table listed `code-reviewer` on `claude-sonnet-4-6`; the
  actual `tooling/claude/agents/code-reviewer.md` pins `claude-opus-4-7`.
  Table corrected.
- Removed the stale **"Codex effort"** column: since the v1.14 migration of
  Codex agents to the official `SKILL.md` spec (`name`+`description` only),
  Codex skills do **not** pin a per-skill model/effort — they run on the
  session model. Replaced with an explicit note so the doc matches reality.

---

## [1.16.7] - 2026-05-16

Production-readiness pass: every install/update/uninstall path executed
end-to-end (bash **and** PowerShell), every config re-verified against the
live docs, and the private-repo plugin path fixed.

### Fixed

- **Plugin marketplace now works on a PRIVATE repo.** The plugin `source`
  was `{ "source": "github", "repo": "PetrovC/ai-agent-kit" }` — a
  self-reference that makes Claude Code do a **second** fetch of the repo
  just for the plugin. On a private repo the marketplace clone is
  authenticated (user's git creds) but that second `github` fetch can fail.
  Per the docs, a plugin in the **same repo** as its marketplace must use a
  relative path. Changed to `"source": "./"` (resolved from the
  already-cloned, authenticated marketplace root — no second fetch). Verified
  the kit's plugin root (repo root: `.claude-plugin/` + `skills/`) matches
  this form.
- `lint-plugin-manifest` now **rejects** a `{source:github, repo:<own repo>}`
  self-reference so this can't regress, and `README.md` documents the
  private-repo behaviour (anyone running `/plugin marketplace add` needs read
  access; no second fetch).

### Verified (no change needed)

- **Functional:** `install` / `update` (idempotent + legacy
  `.codex/agents` migration) / `uninstall` (only `docs/ai/` preserved, by
  design) — all green on **bash** and **PowerShell**. 156 files install
  cleanly; all JSON/TOML parse; hook scripts executable.
- **Config conformance:** Claude (settings `$schema`, subagent comma-string
  `tools`, rules `paths:`), Codex (`hooks.json` git-root form, `web_search`
  values, config keys), Gemini (settings keys, `.gemini/skills/` routing,
  subagent frontmatter, `.geminiignore`) — all match the current official
  docs. No version drift across the 6 version-bearing files. No stale
  model/tool references.

---

## [1.16.6] - 2026-05-16

Full Codex-surface audit against the live docs (`openai/codex` config
reference + hooks + skills, `openai/codex-action`). **Codex was in excellent
shape** — verified conformant, one comment bug fixed.

### Verified conformant (no change)

- `hooks.json`: events, `matcher` (`Bash`, `apply_patch`), `type: command`,
  `statusMessage`, exit 0/2 — all correct. The official Bash-hook example uses
  the exact `$(git rev-parse --show-toplevel)` command form the kit ships.
- `codex-pr-review.yml`: `openai-api-key`, `sandbox: read-only`,
  `safety-strategy: read-only`, `final-message` posting, author gate,
  event-name split — all valid against the current codex-action inputs.
- `config.toml`: `approval_policy` / `sandbox_mode` / `project_doc_max_bytes`
  / `[sandbox_workspace_write]` / `[shell_environment_policy]` / `[history]`
  / `[mcp_servers]` / `notify` — all keys & values match the config reference.
- `.agents/skills/<name>/SKILL.md` with `name`+`description` — correct.

### Fixed

- **`config.toml` `web_search` comment documented the invalid value
  `enabled`.** The real values are `disabled | cached | live` (or a
  `[web_search]` table). The active setting (`web_search = "cached"`) was
  always valid, but a user copying the comment's `enabled` would have broken
  their config. Comment corrected to `live` + note about the table form.
  (This was flagged by an earlier third-party analysis and deferred as
  "cosmetic"; the doc cross-check confirms it was a real misdocumentation.)

### Added

- CI guard in `lint-codex-approval-policy`: fails if `config.toml` ever again
  documents `enabled` as a `web_search` value.

---

## [1.16.5] - 2026-05-16

Hardening so the kit can never commit its own install output ("dogfood
pollution").

**Audit result first:** the repo is **clean** — it tracks only kit *source*
(`tooling/`, `skills/`, `scripts/`, `prompts/`, `.claude-plugin/`,
`project-template/`, `examples/`). No root `AGENTS.md`/`CLAUDE.md`/`GEMINI.md`,
no `.codex/`/`.gemini/`/`.agents/`, no `.mcp.json`/`.kit-version`, no
`.claude/` runtime dir is committed. Verified with `git ls-tree`.

But `.gitignore` only guarded `.claude/`, so a stray `install --target .`
(dogfooding) or an agent writing root files could slip install output into a
commit.

### Changed

- **`.gitignore` hardened**: root-anchored ignores for every install-output
  artifact (`/AGENTS.md`, `/CLAUDE.md`, `/GEMINI.md`, `/.geminiignore`,
  `/.mcp.json`, `/.mcp.example.jsonc`, `/.kit-version`, `/.codex/`,
  `/.gemini/`, `/.agents/`, `/docs/ai/`, `CLAUDE.local.md`). Patterns are
  **root-anchored on purpose** so the tracked sources under `tooling/`
  (e.g. `tooling/codex/AGENTS.md`) and `examples/filled-project/docs/ai/` are
  **never** ignored — verified: no currently-tracked file becomes ignored.

### Added

- CI job **`no-install-output-tracked`**: fails if any install-output
  artifact is tracked at the repo root. `.gitignore` prevents accidental
  `git add`; this enforces it so the invariant can't silently regress.

---

## [1.16.4] - 2026-05-16

Full Claude-surface audit against the live official docs (settings, skills,
subagents, memory/rules, plugins). **Most of the Claude config was already
correct** — verified, not assumed:

- `.claude/rules/*.md` with `paths:` YAML frontmatter — matches the official
  path-specific rules spec exactly. ✓
- `skills/*/SKILL.md` `paths:` / `allowed-tools:` — valid skill frontmatter. ✓
- `model: claude-sonnet-4-6`, hook `async: true`, `${CLAUDE_PROJECT_DIR}` hook
  paths, slash-command `description`/`argument-hint`/`$ARGUMENTS` — all valid. ✓
- `plugin.json` / `marketplace.json` — already conformant (v1.16.1). ✓

### Fixed

- **`settings.json` `outputStyle: "default"` removed.** `"default"` is not a
  documented output-style value (the absence of the key already yields default
  behaviour). It was redundant at best, ignored/invalid at worst.
- **`settings.json` now declares `$schema`** (`https://json.schemastore.org/claude-code-settings.json`),
  the officially recommended key — enables editor autocomplete + inline
  validation.
- **Subagent `tools:` / `disallowedTools:` converted from YAML list to the
  documented comma-separated string form** (`tools: Read, Glob, Grep`). The
  official subagent-file frontmatter spec documents the string form; the YAML
  list was non-canonical. The redundant `disallowedTools:` was dropped on the
  read-only agents — an explicit `tools:` allowlist already excludes everything
  else, and the docs describe allowlist *or* denylist, not both.

### CI

`lint-rules` gained two checks: `settings.json` must declare the official
`$schema` and must not set `outputStyle:"default"`; subagent files must use the
comma-string `tools:` form (no YAML list).

---

## [1.16.3] - 2026-05-15

Acted on a third-party audit. **Every claim was re-verified against the live
official docs first** — 2 of its "priority" claims were factually wrong and
applying them would have broken correct, doc-verified config. Only the 3 valid
findings were fixed.

### Fixed (verified valid)

- **Gemini skill paths were broken after install.** `GEMINI.md`'s routing
  table pointed the agent at `skills/<name>/SKILL.md`, but the installer
  copies skills to `.gemini/skills/`. In an installed project the agent could
  not find any skill. All 30 routing rows + the inline reference now use
  `.gemini/skills/<name>/SKILL.md`. `new-skill.sh`/`.ps1` updated to emit the
  correct path; the `routing-consistency` CI job now *requires* the
  `.gemini/skills/` prefix so this can't regress.
- **`on-failure` approval policy is deprecated** (official: use `on-request`
  or `never`; valid set is now `untrusted | on-request | never` + a `granular`
  table). Updated `AGENTS.md` (example + values list), `config.toml` comment,
  `global-config-template.toml` comment, and tightened the
  `lint-codex-approval-policy` CI job to *reject* `on-failure`.
- **Claude hooks now use `${CLAUDE_PROJECT_DIR}`** instead of bare relative
  `bash .claude/hooks/X.sh`, per the Claude hooks docs — robust when Claude is
  launched from a subdirectory (symmetric with the Codex git-root fix shipped
  in v1.16.2).

### Rejected (audit claims that were wrong — verified against official docs)

- *"Codex subagents must be `.codex/agents/*.toml`; stop deleting that dir."*
  **False.** The official Codex skills doc confirms skills live in
  `.agents/skills/<name>/SKILL.md` (markdown + `name`/`description`
  frontmatter) — exactly what the kit ships since v1.14.0. `.codex/agents/`
  is a dead pre-1.14 location the Rust CLI never reads; `update` correctly
  removes it. No change (applying this would have re-introduced dead config).
- *"Gemini `settings.json` keys are obsolete (use `general.defaultApprovalMode`,
  `tools.allowedTools`, `security.toolSandboxing`…)."* **False.** The official
  configuration doc confirms the kit's keys (`general.checkpointing`,
  `tools.sandbox/core/allowed/exclude`) are the real ones; the suggested keys
  do not exist. No change.
- *"AGENTS.md wrongly says hooks can come from `config.toml`."* **False.** The
  Codex config reference explicitly supports inline `[hooks]` in `config.toml`
  with the same schema as `hooks.json`. No change.

Several other audit items (`safety-strategy: "block"`, codex hook relative
paths, README hook contradiction, `attribution` booleans) were already fixed in
v1.16.2 — the audit ran on an older master.

---

## [1.16.2] - 2026-05-15

Acted on a third-party audit focused on GitHub Actions workflows + Codex hooks
(the kit's weakest area — the workflow templates had never been validated as
actually-runnable). All findings verified against the official docs first.

### Fixed — workflows

- **`codex-pr-review.yml`**: `safety-strategy: "block"` was invalid. The
  codex-action accepts only `drop-sudo | unprivileged-user | read-only |
  unsafe`. Set to `read-only`. (Self-introduced in v1.13.1 from an inaccurate
  doc read — a fair catch.)
- **`codex-pr-review.yml`**: it ran Codex but never surfaced the result. Added
  an `actions/github-script` step that posts `steps.codex.outputs.final-message`
  as a PR comment (the documented pattern; codex-action does not auto-comment).
- **`codex-pr-review.yml` + `gemini-pr-review.yml`**: the `if:` gated on
  `github.event.issue.pull_request`, which doesn't exist on
  `pull_request_review_comment` events — that trigger never fired. Split the
  condition by `github.event_name`.
- **All comment-triggered workflows** (codex/gemini pr-review, gemini dispatch
  + assistant, claude-code): added an `author_association ∈ {OWNER, MEMBER,
  COLLABORATOR}` gate. Previously any commenter could invoke the agent (cost +
  prompt-injection abuse vector).
- **All Gemini workflows**: WIF auth was a hard step while comments said
  `GEMINI_API_KEY` was an option — contradictory. Reworked to API-key as the
  one-secret default, WIF as a clearly-commented opt-in block (id-token,
  auth step, `use_vertex_ai`).

### Fixed — Codex hooks

- **`hooks.json`**: commands were bare relative paths (`.codex/hooks/...`).
  Per the Codex docs, repo-local hooks must resolve from the git root (hooks
  run with the session cwd, so a subdir start broke them). Now
  `bash -c 'exec "$(git rev-parse --show-toplevel)/.codex/hooks/..."'`.
  Verified working from a subdirectory.
- **`hooks.json` matcher**: PostToolUse used Claude-style `Edit|Write|Patch`;
  Codex's edit tool is `apply_patch`. Corrected.
- **`format-on-save.sh`**: it parsed `tool_input.file_path`, but Codex's
  `apply_patch` reports `tool_input.command` — the formatter was a silent
  no-op. Reworked to be payload-agnostic: formats files git reports as
  uncommitted (idempotent, robust).

### Fixed — config / docs

- **`tooling/claude/settings.json`**: `attribution.commit/pr` were booleans;
  the Claude schema defines them as **strings** (attribution text, or `""` to
  hide). Removed the block entirely — the default already includes attribution,
  which is the kit's intent. No behaviour change.
- **`README.md`**: removed the "Codex and Gemini have no equivalent hook
  system" line that contradicted the dedicated Hooks section (Codex has had
  hooks since v1.15.0). Section now states Claude + Codex parity.
- **`AGENTS.md`**: `--model o4-mini` example → `gpt-5.5` (matches the rest of
  the kit since v1.14.1).

### Added — CI

Two jobs that catch these classes of error going forward:
- `lint-workflow-semantics`: valid `safety-strategy`, no
  `issue.pull_request` misuse on review-comment triggers, codex review posts
  `final-message`, comment-triggered workflows filter `author_association`.
- `lint-codex-hooks`: hook commands resolve from git root (no bare relative),
  and README stays coherent on Codex hook support.

`lint-plugin-manifest` also now version-checks `gemini-extension.json` and the
marketplace `source` form (carried from v1.16.1).

---

## [1.16.1] - 2026-05-15

Content-coherence audit (file contents vs official schemas, field by field).
Most config was already correct; this fixes one real bug and several drifts.

### Fixed

#### 🔴 marketplace.json `source: "."` was not a valid form

The plugin marketplace spec requires a relative `source` to **start with `./`**
and resolve to a sub-directory, or be a `{source: github|url|...}` object.
`"."` is neither — `/plugin install ai-agent-kit@ai-agent-kit` would fail to
resolve the plugin. Changed to the documented GitHub source form:
`{ "source": "github", "repo": "PetrovC/ai-agent-kit" }` (works for both
git-added and URL-added marketplaces). **The v1.16.0 plugin did not install;
this fixes it.**

#### 🟠 gemini-extension.json version drift

Was pinned at `1.15.0` while the kit was `1.16.0` (no CI guard, unlike
plugin.json). Bumped to match and `lint-plugin-manifest` now enforces
`gemini-extension.json` version == `KIT_VERSION` too, plus validates the
marketplace `source` is a documented form.

#### 🟠 Gemini high-stakes agents were silently downgraded

`architect` / `code-reviewer` / `security-reviewer` were pinned to
`gemini-2.5-pro` — an **older** model than the v1.14.1 session default, the
inverse of the original "use the most capable model" intent. Re-pinned to
**`gemini-3.1-pro`** (the current GA id; the `-preview` suffix is also dropped
from the `settings.json` default and the `GEMINI.md` example so every reference
is consistent). The cheap `gemini-2.5-flash` agents (`codebase-investigator`,
`test-runner`) are intentionally left as-is: the pin is a deliberate cost
choice and no Gemini-3 flash CLI model id is confirmed (not guessing one in).

#### 🟡 Wrong Gemini tool names in agent frontmatter

Agents referenced `grep_search` and `run_terminal_command`, which are not real
Gemini CLI tools — the actual names are `search_file_content` and
`run_shell_command`. A misnamed tool is silently not pre-authorized (no hard
failure) but it defeated the intended allow-list. Corrected across all agents;
`GEMINI.md` `--model` example and the README model table updated to match.

#### 🟡 Stray `mcpServers: {}` in Claude settings.json

Claude's canonical MCP location is `.mcp.json`; a raw `mcpServers` map is not a
documented `settings.json` key (it was empty, zero effect). Removed.

---

## [1.16.0] - 2026-05-15

### Added

#### Claude plugin marketplace (opt-in, skills-only) — backlog item delivered

The deferred "packaging" backlog item, done the non-invasive way. The kit is now
also a Claude plugin marketplace:

```
/plugin marketplace add PetrovC/ai-agent-kit
/plugin install ai-agent-kit@ai-agent-kit
```

- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` at repo root.
- The plugin ships the **30 skills** with **zero duplication**: the repo's
  existing `skills/<name>/SKILL.md` layout already matches the plugin spec
  exactly, so `source: "."` works as-is. No skill is copied or restructured —
  "one skill written once" is preserved.
- Skills install namespaced (`/ai-agent-kit:dotnet`, …); `paths:` auto-loading
  still works.

This is **additive and opt-in**. The install script remains the canonical path
and is unchanged:

- Codex has **no** marketplace/plugin mechanism — it reads `.agents/skills/`,
  `AGENTS.md`, `.codex/config.toml`, `.codex/hooks.json` from the repo, so files
  must be physically placed there. Only the script does that.
- The plugin does not ship commands/hooks/Codex/Gemini config or scaffold
  `docs/ai/` (those aren't a single-tool skills concern). The script does.

So: plugin = the skills slice for single-tool Claude users; script = full
multi-tool bootstrap + project-doc scaffolding. They solve different layers and
coexist.

### CI

`lint-plugin-manifest` — validates both manifests are valid JSON with required
fields, and enforces that `plugin.json` `version` matches `KIT_VERSION` so
marketplace users and script users never drift apart.

### Still deferred

LSP servers and background monitors (plugin-only extras) remain backlog — not
needed for the skills-distribution use case.

---

## [1.15.0] - 2026-05-15

Final of the v1.15.0 capability-parity series (rc1 → rc3 → this). The fourth
audit found the kit was *correct* but had **capability asymmetry** across the
three tools; this series closed it:

- **rc1** — Codex lifecycle hooks (the hardened guard now protects Codex too)
- **rc2** — Codex MCP / `shell_environment_policy` / `history` in config.toml
- **rc3** — Gemini custom commands (11 `.toml`) + extension scaffold
- **this** — Gemini GitHub Action: Dispatch + Assistant workflows, new inputs

### Added

#### Gemini Action: Dispatch + Assistant workflows

The `run-gemini-cli` action documents four workflow templates; the kit shipped
two (PR Review, Issue Triage). Added the other two:

- `prompts/github-actions/gemini-dispatch.yml` — central router: `@gemini-cli
  /review` → review, `/triage` → triage, free text → assistant.
- `prompts/github-actions/gemini-assistant.yml` — standalone conversational
  Q&A agent on `@gemini-cli` mentions.

#### Newer `run-gemini-cli` inputs documented

All four Gemini workflows now reference the newer optional inputs as commented
hints: `gemini_debug` (verbose logging), `upload_artifacts` (run logs as a
workflow artifact), `use_pnpm` (install the CLI via pnpm).

### Net result

All three tools now have parity on: hooks, slash commands, MCP config, and
GitHub Action workflow coverage. Deferred to a separate future PR (unchanged):
Claude plugin packaging + `marketplace.json`, LSP servers, background monitors.

---

## [1.15.0-rc3] - 2026-05-15

Part 3 of the v1.15.0 series. Stacked on rc2. Closes the Gemini command gap.

### Added

#### Gemini custom commands (parity with Claude slash commands)

The eleven workflow prompts existed as Claude slash commands since v1.14.0 but
had no Gemini equivalent (deferred then — the TOML schema was undocumented; it
is now). Ships `tooling/gemini/commands/*.toml`:

- Same eleven workflows (bug-fix, code-review, daily-ticket, dependency-update,
  feature-planning, on-call, performance-audit, refactor, run-tests,
  security-audit, tech-debt).
- Each has `description` + `prompt`, using Gemini's `{{args}}` placeholder
  (the Gemini analog of Claude's `$ARGUMENTS`).
- Installed into `<project>/.gemini/commands/`; handled by
  install/update/uninstall (sh + ps1).

#### `gemini-extension.json` scaffold

A minimal extension manifest (`tooling/gemini/gemini-extension.json`, name +
version + `contextFileName`) is provided as a **reference scaffold** for teams
that want to package and distribute the kit via `gemini extensions install`.
Not installed by default — the kit's primary path stays project-level
(consistent with deferring Claude plugin packaging to a separate future PR).

### Docs + CI

- `GEMINI.md` gains a "Slash commands" section + extension note.
- `README.md` structure updated.
- CI: every `tooling/gemini/commands/*.toml` must declare `prompt` + `description`
  and parse with `tomllib`; `gemini-extension.json` must be valid JSON with
  name + version; smoke-install verifies representative command files.

---

## [1.15.0-rc2] - 2026-05-15

Part 2 of the v1.15.0 series (capability parity). Stacked on rc1.

### Added

#### Codex `config.toml`: MCP servers, env policy, history

The kit documented MCP for Claude (`.mcp.json`) and Gemini (`settings.json`)
but **not Codex**, even though Codex supports `[mcp_servers.<name>]`. Also added
the security/ops sections Codex offers that the kit ignored:

- **`[shell_environment_policy]`** — `inherit = "all"` with an `exclude` list
  (`*_SECRET`/`*_TOKEN`/`*_KEY`/`*_PASSWORD`/`OPENAI_*`/`ANTHROPIC_*`/`AWS_*`/`GCP_*`).
  Keeps secrets out of subprocess env — the Codex equivalent of Gemini's
  `advanced.excludedEnvVars`. Previously Codex subprocesses inherited every var.
- **`[history]`** — `persistence = "save-all"`, `max_bytes = 10 MiB` so a long
  session can't fill the disk. Documented `persistence = "none"` for sensitive repos.
- **`[mcp_servers.*]`** — commented stdio + HTTP examples (GitHub, filesystem,
  Linear), mirroring the `.mcp.example.jsonc` pattern.
- **`notify`** — commented; the kit prefers the `Stop` hook, but the config.toml
  form is documented as the alternative.

`AGENTS.md` gains a "Project config" section. CI: new `Codex .toml files must
parse` step (Python `tomllib` on the Ubuntu runner) guards the config against
syntax regressions.

---

## [1.15.0-rc1] - 2026-05-15

Fourth audit pass. The kit was *correct* after 1.14.1; this series closes
**capability asymmetry** between the three tools (Claude had hooks/commands/MCP;
Codex and Gemini lagged). This RC is part 1 of the v1.15.0 series.

### Added

#### Codex lifecycle hooks (parity with Claude)

Codex supports `hooks.json` with the same event model as Claude
(`PreToolUse`/`PostToolUse`/`Stop`, stdin JSON, exit 2 = block). The kit shipped
four Claude hooks but **zero** for Codex — the hardened `rm -rf` / force-push /
`DROP` guard only protected Claude sessions.

Now ships `tooling/codex/hooks.json` + `tooling/codex/hooks/`:

| Event | Hook | Notes |
|---|---|---|
| `PreToolUse` (Bash) | `pre-bash-guard.sh` | Same hardened guard as Claude (probed jq→python3→sed parse, no fail-open) |
| `PostToolUse` (Edit/Write/Patch) | `format-on-save.sh` | Robust file_path parse (same Windows-stub-safe approach) |
| `Stop` | `notify-done.sh` | Desktop notification |

Codex has no `PreCompact` event, so the Claude `session-summary` hook has no
Codex equivalent (documented in `AGENTS.md`).

- `install` / `update` / `uninstall` (sh + ps1) handle `.codex/hooks.json` and
  `.codex/hooks/`, scripts marked executable.
- `AGENTS.md` gains a "Lifecycle hooks" section.
- CI: smoke-install verifies the Codex hook files; the behavioral guard matrix
  now runs against **both** the Claude and Codex guards (10 cases each);
  executable check covers `tooling/codex/hooks/*.sh`.

---

## [1.14.1] - 2026-05-15

Follow-up from a second independent audit. Three of the four "priority" items it
raised were already fixed in 1.13.1 (Codex/Gemini Action inputs, Codex
`auto-approve`). These six were genuinely missed and are fixed here.

### Fixed

#### `.mcp.json` was JSONC — Claude Code requires strict JSON

`tooling/claude/.mcp.json` shipped with `//` comments and commented-out example
servers. Claude Code rejects comments in `.mcp.json`, so the file could fail to
load. Now:

- `.mcp.json` is strict, empty: `{"mcpServers":{}}`.
- A new `.mcp.example.jsonc` carries the commented GitHub/filesystem/Postgres/
  Notion/Linear reference blocks. Installed alongside `.mcp.json`.
- New CI job `lint-mcp-json-strict` fails if `.mcp.json` ever regains comments.

#### `pre-bash-guard.sh` silently allowed everything without a working parser

The hook extracted the command via `python3`. On Windows the App-Execution-Alias
stub resolves on PATH, prints "Python was not found", and **exits 0** — so
`command -v` and exit-code checks both pass while the command string comes back
empty and every destructive-command guard is skipped silently.

Now each parser (`jq`, then `python3`) is *probed* with a known input and only
used if it returns the expected value; a dependency-free `sed` extraction is the
always-available final fallback. Also fixed a pre-existing bug: the `rm -rf`
guard used a PCRE negative lookahead `(?!...)` that `grep -E` does not support,
so `rm -rf /etc` was never blocked. Rewritten to block absolute / home /
parent-traversal targets while allowing temp and local relative paths. New CI
job runs an 10-case behavioral matrix against the hook.

#### `git checkout:*` permission was too broad

`Bash(git checkout:*)` allowed `git checkout -- file` and `git checkout .`,
which overwrite uncommitted work without confirmation. Replaced the broad allow
with `Bash(git checkout -b:*)` + `Bash(git switch:*)` (safe branch operations),
and added `git checkout -- ` / `git checkout .` to the deny list.

#### README MCP section was out of date

It claimed Codex does not support MCP and Gemini's support was "emerging". Both
now have documented MCP config (`[mcp_servers.*]` in Codex `config.toml`,
`mcpServers` in Gemini `settings.json`). Section rewritten with the correct
per-tool config locations and the strict-JSON caveat.

### Changed

#### Default models refreshed

- Codex `global-config-template.toml`: `o4-mini` → `gpt-5.5` (fallback `gpt-5.4`).
- Gemini `settings.json`: `gemini-2.5-pro` → `gemini-3.1-pro-preview`.

The intentionally task-tuned per-agent models from 1.13.0 are **not** touched —
re-tuning agents against the new defaults is tracked as a separate follow-up so
the "one concern per PR" rule holds.

---

## [1.14.0] - 2026-05-15

### Added

#### Claude slash commands — eleven workflow prompts available as `/<name>`

The eleven prompts under `prompts/` (bug-fix, code-review, daily-ticket, dependency-update,
feature-planning, on-call, performance-audit, refactor, run-tests, security-audit, tech-debt)
are now installed as Claude Code slash commands at `.claude/commands/<name>.md`.

Each command:
- Has a `description:` and (where applicable) `argument-hint:` frontmatter so it shows up
  correctly in the `/` autocomplete menu.
- Uses `$ARGUMENTS` (or `$ARGUMENTS[N]` for positional) instead of `[BRACKETED]` placeholders,
  so users can type `/bug-fix 1234` directly.

Per the official upstream docs, custom commands and skills are unified in Claude Code:
`.claude/commands/<name>.md` is equivalent to `.claude/skills/<name>/SKILL.md`. The kit uses
the simpler `commands/` form to avoid collisions with the 29 tool-agnostic skills that already
land in `.claude/skills/` after install.

Codex and Gemini do not have an equivalent native slash-command system (Gemini's custom
commands TOML format is still incomplete in the public docs), so the canonical `prompts/`
files stay as the reference source for those tools.

### Changed

#### `claude-code.yml` workflow — document Bedrock / Vertex AI auth alternatives

The template now points to `claude-code-action`'s `docs/cloud-providers.md` and includes
commented-out lines for the most common optional inputs (`trigger_phrase`, `allowed_tools`).

#### `CLAUDE.md` — new "Slash commands" and "MCP servers" sections

Inline reference for the eleven commands and a pointer to `.mcp.json` for MCP server config.

### CI

`lint-claude-commands` — every `tooling/claude/commands/*.md` must declare a `description:`
frontmatter line. Smoke install now verifies three representative command files and two
codex skill files are laid down by the installer.

---

## [1.14.0-rc1] - 2026-05-15

### BREAKING — Codex subagents migrated from `.toml` to official `SKILL.md` format

The Rust Codex CLI does not read `.codex/agents/*.toml`. The five subagents we shipped there
(architect, code-reviewer, codebase-investigator, security-reviewer, test-runner) lived in a
directory Codex never opened — they were effectively dead config.

The official Codex spec puts skills under `.agents/skills/<name>/SKILL.md` with markdown +
`name`/`description` frontmatter and invokes them via `/skills` or `$name`. The kit now
ships them as proper skills:

- Source moved from `tooling/codex/agents/<name>.toml` → `tooling/codex/skills/<name>/SKILL.md`.
- Install target moved from `<project>/.codex/agents/` → `<project>/.agents/skills/`.
- Per-skill `model` and `model_reasoning_effort` are dropped (not in the official spec — Codex uses the session model).

**Migration:** `update.sh` / `update.ps1` automatically delete the five legacy
`.codex/agents/*.toml` files (and the directory if empty) on first run after upgrading.
Users running a custom subagent in `.codex/agents/` are preserved.

### Changed

#### Gemini `settings.json` aligned with official schema

Five keys we shipped don't exist in the Gemini CLI settings schema and were silently ignored:

- `general.defaultApprovalMode` — approval mode is a CLI flag (`--approval-mode`), not a settings key.
- `tools.sandboxNetworkAccess` — not in the schema.
- `tools.discovery.command/callCommand` — the official keys are flat: `tools.discoveryCommand` and `tools.callCommand`. We don't actually need either, so the section is removed.
- `skills.enabled` — Gemini has no native "skills" concept (the kit's tool-agnostic skills are just files Gemini reads).
- `security.environmentVariableRedaction.*` — replaced by the official `advanced.excludedEnvVars` flat list.

The redaction list (`*_SECRET`, `*_TOKEN`, `*_KEY`, `*_PASSWORD`, `OPENAI_*`, `ANTHROPIC_*`)
is preserved under the correct key.

#### Claude `settings.json`: deprecated `includeCoAuthoredBy` → `attribution`

The official settings schema marks `includeCoAuthoredBy` as deprecated. Replaced with:
```json
"attribution": { "commit": true, "pr": true }
```
Co-authoring is still enabled for both commits and PRs.

#### Documentation: Gemini subagents are now native

`GEMINI.md` previously routed to `@codebase-investigator`-style mentions as a convention.
Since April 2026 the Gemini CLI supports `@name` subagents natively (`.gemini/agents/*.md` with `name`/`description` frontmatter — which is already how this kit ships them). The doc now states this explicitly and links to the upstream subagent guide.

#### Documentation: Codex AGENTS.md cascade

`AGENTS.md` now documents the three-level cascade Codex applies:
1. `~/.codex/AGENTS.override.md` then `~/.codex/AGENTS.md` (global).
2. `AGENTS.override.md` / `AGENTS.md` from the git root down to the working directory.
3. Files closer to cwd take precedence; total content capped at `project_doc_max_bytes` (32 KiB).

### Added

#### CI: three new lint jobs

- `lint-codex-approval-policy` — fails if any `approval_policy = "..."` in `tooling/codex/*.toml` is not one of `untrusted | on-failure | on-request | never`.
- `lint-codex-skills` — every `tooling/codex/skills/*/SKILL.md` must have `name:` and `description:` frontmatter; fails if `tooling/codex/agents/` (legacy) still exists.
- `lint-gemini-subagents` — every `tooling/gemini/agents/*.md` must have `name:` and `description:` frontmatter.

---

## [1.13.1] - 2026-05-15

### Fixed

#### GitHub Actions workflow templates — invalid inputs

Three of the four templates in `prompts/github-actions/` passed inputs that don't exist in
the current upstream actions, so they would fail at workflow startup.

| File | Wrong input | Correct input |
|---|---|---|
| `codex-pr-review.yml` | `api_key:` | `openai-api-key:` |
| `codex-pr-review.yml` | `approval_policy: "never"` | removed (use `sandbox: "read-only"` + `safety-strategy: "block"`) |
| `codex-pr-review.yml` | `model: "gpt-5.5"` | commented out (non-existent model; let action default decide) |
| `gemini-pr-review.yml` | `flags: "--approval-mode yolo"` | removed (the action runs non-interactively; approval-mode CLI flag is irrelevant) |
| `gemini-pr-review.yml` | `version:` | `gemini_cli_version:` |
| `gemini-issue-triage.yml` | same as above | same fixes |

#### Codex `approval_policy` — invalid values documented

`AGENTS.md`, `tooling/codex/config.toml`, and `tooling/codex/global-config-template.toml`
documented `auto-approve` and `suggest` as valid values. The Rust Codex CLI accepts only
`untrusted` | `on-failure` | `on-request` | `never`. Comments and the CLI usage example
have been corrected. Runtime values (`"on-request"`) were already valid — no behavior change.

---

## [1.13.0] - 2026-05-15

### Changed

#### Agent model tuning — task-appropriate cost across all 15 agent files

Each of the 5 shipped agents (×3 tools = 15 files) had its model and effort level audited against its actual workload. The two most-frequently-spawned agents (`codebase-investigator`, `test-runner`) handle grep / read / shell-exec work that doesn't require deep reasoning — using a small model saves roughly an order of magnitude per invocation. The two highest-stakes agents (`architect`, `security-reviewer`) were upgraded to the most capable tier because the cost of a wrong call there is much higher than the call itself.

| Agent | Tool | Before | After | Why |
|---|---|---|---|---|
| `architect` | Claude | `claude-sonnet-4-6` | **`claude-opus-4-7`** | High-stakes, infrequent — pay for depth |
| `architect` | Gemini | `inherit` | **`gemini-2.5-pro`** | Explicit to avoid silent downgrade if user sets `gemini-2.5-flash` as default |
| `security-reviewer` | Claude | `claude-sonnet-4-6` | **`claude-opus-4-7`** | Wrong call = exploitable vulnerability shipped |
| `security-reviewer` | Gemini | `inherit` | **`gemini-2.5-pro`** | Same reason as Claude |
| `code-reviewer` | Gemini | `inherit` + `max_turns: 25` | **`gemini-2.5-pro`** + `max_turns: 20` | Explicit model; normalize to Claude's `maxTurns: 20` |
| `codebase-investigator` | Claude | `claude-sonnet-4-6` | **`claude-haiku-4-5`** | Only does `Read` / `Glob` / `Grep` — Sonnet was overkill |
| `codebase-investigator` | Gemini | `inherit` + `max_turns: 20` | **`gemini-2.5-flash`** + `max_turns: 15` | Same — search task, cheap model |
| `test-runner` | Claude | `claude-haiku-4-5-20251001` | **`claude-haiku-4-5`** | Drop date suffix → auto-rolls to latest patch |
| `test-runner` | Gemini | `inherit` | **`gemini-2.5-flash`** | Shell exec + summarize, cheap is fine |
| `test-runner` | Codex | `model_reasoning_effort: medium` | **`low`** | No reasoning needed — just run + summarize |

`maxTurns` / `max_turns` normalized across the three tools per agent (was diverging up to 25 in Gemini vs 15-20 elsewhere).

### Added

#### Model selection strategy section in README

New section under "Subagents / Agents" documents the cost rationale: cheap models for frequent / simple tasks, capable models for rare / high-stakes tasks. Includes a per-agent table showing the chosen model on each of the three tools. Projects can override per-agent by editing the `model:` line in the agent file.

### Changed (version)

- `KIT_VERSION` bumped to `1.13.0` in all four scripts.

---

## [1.12.0] - 2026-05-15

### Added

#### Three new CI jobs (`lint-yaml`, `routing-consistency`, `verify-webfetch-domains`)

Closes **C1** from the original kit audit.

| Job | What it validates |
|---|---|
| `lint-yaml` | Every `*.yml` / `*.yaml` file in the repo parses with `yq`. GitHub Actions templates in `prompts/github-actions/` and `.github/workflows/` must declare both `on` and `jobs` keys. |
| `routing-consistency` | Every skill directory under `skills/` must have a row in **all three** routing tables: `tooling/claude/CLAUDE.md` (`` `<skill>` skill ``), `tooling/codex/AGENTS.md` (`` `$<skill>` ``), and `tooling/gemini/GEMINI.md` (`skills/<skill>/SKILL.md`). Catches drift when a new skill is added but routing tables are not updated. |
| `verify-webfetch-domains` | Each `WebFetch(domain:...)` entry in `tooling/claude/settings.json` must be a plain hostname — no wildcards (`*`, `*.example.com`), no schemes (`http://`, `https://`), valid DNS character set. |

These jobs run on every push and pull request, alongside the existing `lint-skills` and `lint-rules` checks.

### Changed

#### `tooling/gemini/settings.json` — enabled checkpointing, added tool discovery placeholder

Closes **C3** from the original kit audit.

- `general.checkpointing.enabled` flipped from `false` to **`true`** — Gemini CLI now writes session checkpoints by default, allowing resume after an error or long pause (`gemini --checkpointing` is the runtime flag, see GEMINI.md).
- New `tools.discovery` block with `command` / `callCommand` placeholders for projects that expose custom tools via Gemini's tool discovery mechanism. Set to `null` by default — projects fill these to register external tools at startup.

#### `tooling/claude/settings.json` — project-level defaults

Closes **B3** from the original kit audit.

Four top-level fields added so installed projects ship with safe, explicit defaults:

| Field | Value | Why |
|---|---|---|
| `model` | `"claude-sonnet-4-6"` | Pins the default model for the project. Override per-session with `claude --model ...`. |
| `outputStyle` | `"default"` | Explicit baseline — projects can switch to `"concise"` for less verbose output. |
| `includeCoAuthoredBy` | `true` | Ensures Claude-assisted commits carry a `Co-Authored-By: Claude` trailer for attribution. |
| `cleanupPeriodDays` | `30` | Bounded retention for Claude Code's local logs and session data. |

### Changed (version)

- `KIT_VERSION` bumped to `1.12.0` in all four scripts.

---

## [1.11.0] - 2026-05-15

### Changed

#### `README.md` — major documentation pass

The README was restructured to explain **what each component is, which AI tool uses it, and why it's useful**. A new "How each feature maps to each tool" section was added covering:

- **Skills** — how they load differently per tool: Claude Code auto-loads via `paths:` frontmatter, Codex activates via `$skill-name`, Gemini reads via explicit file path
- **Hooks** — Claude Code only (lifecycle events, exit code 2 = block); explanation of why Codex/Gemini use approval modes instead
- **Rules** — Claude Code only (path-triggered auto-load); explanation of how they differ from skills
- **MCP servers** — Claude Code full support, Gemini emerging, Codex not supported; link to MCP spec
- **Subagents** — format and invocation per tool (`.md` / `.toml` / `.md`, different invocation syntax)

A new **"Official resources"** table near the top links all 7 official tool repositories and documentation sites:

| Resource | URL |
|---|---|
| Claude Code source | [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code) |
| All Anthropic repos | [github.com/orgs/anthropics/repositories](https://github.com/orgs/anthropics/repositories) |
| Codex CLI source | [github.com/openai/codex](https://github.com/openai/codex) |
| Codex GitHub Action | [github.com/openai/codex-action](https://github.com/openai/codex-action) |
| Gemini CLI source | [github.com/google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli) |
| Gemini CLI docs | [google-gemini.github.io/gemini-cli/docs](https://google-gemini.github.io/gemini-cli/docs) |
| Gemini GitHub Action | [github.com/google-github-actions/run-gemini-cli](https://github.com/google-github-actions/run-gemini-cli) |

#### `tooling/claude/CLAUDE.md` — added "How to run Claude Code" section

Added a missing `## How to run Claude Code` section (equivalent to what GEMINI.md already had) covering:
- `claude` (interactive) vs `claude --dangerously-skip-permissions` (CI/autonomous)
- `--model`, `--continue`, `--print` flags
- How Claude Code loads this file at startup and lazy-loads rules and skills
- Link to [github.com/anthropics/claude-code](https://github.com/anthropics/claude-code)

#### `tooling/codex/AGENTS.md` — added "How to run Codex CLI" section

Added a new `## How to run Codex CLI` section covering:
- `--approval-policy` modes (default `on-request`, `auto-approve`, `never`)
- `--profile` switching (readonly, standard, deep, review)
- `--model`, `--no-project-doc` flags
- How Codex reads this file and `.codex/config.toml`
- Links to [github.com/openai/codex](https://github.com/openai/codex) and the GitHub Action

#### `tooling/gemini/GEMINI.md` — expanded "How to run" section

Extended the existing section with:
- `--checkpointing` flag (resume after error or long pause)
- `--debug` flag (verbose tool call output)
- `--model` override flag
- How Gemini loads skills via explicit file reads
- Reference links (source, docs, GitHub Action)

### Changed (version)

- `KIT_VERSION` bumped to `1.11.0` in all four scripts.

---

## [1.10.0] - 2026-05-14

### Changed

#### `code-review` skill — major expansion (114 → 240 lines)

New sections added to cover everything that matters in a real PR review:

| Section | What it covers |
|---|---|
| **PR size guidance** | >400 LOC = request a split; how to handle large/generated PRs |
| **Async and concurrency checklist** | Missing awaits, fire-and-forget, race conditions, deadlocks, thread-safety, CancellationToken propagation, listener cleanup |
| **Data and schema changes** | Reversibility, backward-compatibility, NOT NULL migration safety, CONCURRENT indexes, two-step renames, volume timing |
| **Dependency changes** | License check, maintainability signals, version pinning, bundle size impact, duplication |
| **Performance flags** | O(n²) loops, N+1 queries, missing pagination, missing cache, synchronous I/O on hot path |
| **Review comment quality** | File:line format, why-it-matters + suggestion template, tone rules (suggest vs demand, no negative attribution) |

Priority order expanded to 9 levels (added data safety and dependency changes).
Final response format adds one-line merge verdict: "Ready to merge", "Needs changes (N blockers)", "Needs discussion".

#### `vue` skill — major expansion (114 → 270 lines)

Replaced bullet lists with full working code examples throughout:

| Section | What was added |
|---|---|
| **`<script setup>` full pattern** | `defineProps<T>()`, `defineEmits<T>()`, `defineModel()` (Vue 3.4+), `computed()`, `watch()` in one coherent example |
| **Composables** | `useLeaveBalance` with async fetch, `error`/`loading`/`balance` refs, timer cleanup in `onUnmounted()`, `MaybeRef<T>` usage |
| **Pinia composition stores** | `defineStore` factory style, typed state/getters/actions, `storeToRefs()` usage in components |
| **Vue Router 4** | Typed `RouteRecordRaw`, lazy-loaded routes, `router.beforeEach` auth guard, `useRouter()`/`useRoute()`, params as props |
| **Provide / Inject (typed)** | `InjectionKey<T>` pattern for type-safe injection |
| **Performance patterns** | `shallowRef`, `markRaw`, `v-memo`, `defineAsyncComponent`, warning on reactive large arrays |
| **Nuxt 3 / SSR** | `useFetch`/`useAsyncData`, `<ClientOnly>`, `useState`, browser-only code guards |
| **Anti-patterns table** | 7 common mistakes with concrete fixes |
| **Paths extended** | Added `**/nuxt.config.*` |

#### `angular` skill — major expansion (124 → 290 lines)

Rewritten for Angular 17+ with full code examples:

| Section | What was added |
|---|---|
| **Standalone component pattern** | `standalone: true`, `ChangeDetectionStrategy.OnPush`, `inject()`, complete `input()`/`output()`/`model()` signal APIs |
| **Signals** | `signal()`, `computed()`, `effect()` with cleanup; signals vs RxJS decision table |
| **RxJS interop** | `toSignal()` (auto-unsubscribes) and `toObservable()` with usage examples |
| **New control flow** | `@if`/`@else if`/`@else`, `@for` with required `track`, `@empty`, `@switch` — replacing `*ngIf`/`*ngFor` |
| **Deferrable views** | `@defer` with `on viewport`, `@loading`/`@placeholder`/`@error` blocks, when to use |
| **Functional interceptors** | `HttpInterceptorFn`, `provideHttpClient(withInterceptors([...]))`, no class-based interceptors |
| **Functional routing** | `loadComponent`, `CanActivateFn`, `ResolveFn`, `inject()` in guards/resolvers |
| **Typed reactive forms** | `FormControl<Date \| null>`, `FormGroup<{...}>` for compile-time checked access |
| **Testing with signal inputs** | `fixture.componentRef.setInput()` for signal-based `input()` props |
| **Anti-patterns table** | 8 patterns to reject with fixes |

### Changed (version)

- `KIT_VERSION` bumped to `1.10.0` in all four scripts.

---

## [1.9.0] - 2026-05-14

### Changed

#### `architecture` skill — major rewrite (126 → 260 lines)

Replaced thin bullet-list with concrete, runnable TypeScript examples throughout:

| Section | What was added |
|---|---|
| **Layer boundaries** | Non-negotiable dependency rules (Domain → no deps, Application → Domain only, Infrastructure → ports, Interfaces → Application only) with a common-violations checklist |
| **When to use each pattern** | Decision table: layered / CQRS / domain events / event sourcing / microservice / modular monolith with default recommendation |
| **DDD — Entities vs Value Objects** | `Order` aggregate with two invariant checks (`PENDING` guard, max 20 items), domain event collection; `Money` value object (immutable, `Object.freeze`, currency equality) |
| **Aggregate rules** | One repository per root, consistency boundary, cross-aggregate via events or app services, keep aggregates small |
| **Domain events** | Dispatch pattern: raise in aggregate → save → publish → clear events |
| **CQRS** | Full TypeScript write-side (`ShipOrderCommand` + `ShipOrderHandler`) and read-side (`GetOrderDashboardHandler` with direct SQL, no domain objects) |
| **Hexagonal / Ports & Adapters** | `OrderRepository` and `EmailService` ports in Application; `PostgresOrderRepository` / `SendGridEmailService` adapters in Infrastructure; `InMemoryOrderRepository` fake for unit tests |
| **Modular monolith** | Directory layout, module communication rules (public interfaces / events only), private DB tables per module |
| **Bounded contexts** | Separate models, explicit DTOs, anti-corruption layers, `docs/ai/ARCHITECTURE.md` |
| **Decision rule for abstractions** | Three triggers (real duplication / meaningful boundary / testability); no speculative abstractions |
| **Verification** | `ARCHITECTURE.md` / `DECISIONS.md` check, cross-layer dependency check, integration test requirement |
| **Final response format** | 8-field structured response (business capability → current state → proposed change → layers → deps → not over-engineered → reversibility → validation) |

#### `ai-dev` skill — three new sections (Extended thinking, `tool_choice` modes, MCP)

| Section | What was added |
|---|---|
| **`tool_choice` modes** | `{"type": "tool", "name": "..."}` for forced structured output, `{"type": "any"}` to require a call, `{"type": "auto"}` (default) — with note that force-tool is more reliable than JSON mode |
| **Extended thinking** | `thinking: {"type": "enabled", "budget_tokens": N}` usage; `ThinkingBlock` vs `TextBlock` in response; rules: budget < max_tokens, don't show thinking to users, cache system prompt separately, include thinking blocks in multi-turn history, not available on Haiku |
| **MCP — Model Context Protocol** | When to use (runtime external tools/data, tool reuse across agents, Claude Code skills); stdio vs HTTP/SSE table; `.mcp.json` config example (filesystem, postgres); full TypeScript MCP server implementation (`ListTools` + `CallTool` handlers with `StdioServerTransport`); four security rules |

### Changed (version)

- `KIT_VERSION` bumped to `1.9.0` in all four scripts.

---

## [1.8.0] - 2026-05-14

### Added

#### New prompt: `performance-audit.md`
Structured 4-step performance investigation: baseline → classify bottleneck (DB / network / app code / frontend / caching) → targeted fixes → re-measure. Enforces "measure first" discipline and requires actual numbers in the report.

### Changed

#### `security` skill — major expansion (142 → 260 lines)

New sections added:

| Section | What it covers |
|---|---|
| OWASP Top 10 quick reference | One-line countermeasure for each of the 10 risks |
| Injection | Parameterized query examples in Python, TypeScript, .NET EF Core, Go, MongoDB |
| XSS | DOMPurify usage, CSP baseline header, `HttpOnly` cookies |
| CSRF | `SameSite=Strict`, CSRF token patterns, framework defaults |
| Authentication | JWT pitfalls (`alg:none`, short expiry, no `localStorage`), bcrypt/Argon2, session fixation, account enumeration |
| Authorization | Fail-closed pattern, ownership check in DB query, audit logging |
| CORS | Allowlist origins, never wildcard for authenticated APIs |
| Rate limiting | Per-user limits, 429 + `Retry-After`, fail-open on limiter errors |
| SSRF | Allowlist + block private IPs + DNS rebinding mitigation |

Verification section extended with `bandit` (Python static analysis) and secret-grep command.

#### `react` skill — Next.js App Router coverage expanded

The `## Next.js (App Router)` section grew from 6 bullets to full coverage:

- **Server vs Client Components**: decision tree (when to add `'use client'`)
- **Server Actions**: form mutation pattern, `useActionState`, input validation
- **Route Handlers**: `GET` / `POST` examples, when to use vs Server Actions
- **Middleware**: auth redirect pattern, `config.matcher`, performance constraints
- **Special files table**: `loading.tsx`, `error.tsx`, `not-found.tsx`, `layout.tsx`, `template.tsx`
- **Environment variables**: `NEXT_PUBLIC_*` vs server-only, `zod`-validated `env.ts` module
- **Image + font optimization**: `next/image` props, `next/font`
- **Auth pattern**: middleware + Server Component + Action layered verification
- **Metadata**: static `export const metadata` vs dynamic `generateMetadata`

### Changed (version)

- `KIT_VERSION` bumped to `1.8.0` in all four scripts.

---

## [1.7.0] - 2026-05-14

### Added

#### 3 new operational prompts

| File | When to use |
|---|---|
| `prompts/on-call.md` | Structured 5-step incident investigation: triage → scope → root cause → mitigate → post-mortem write-up |
| `prompts/dependency-update.md` | Safe single-package upgrade: changelog review → license check → baseline test → update → audit |
| `prompts/tech-debt.md` | Codebase-wide tech debt triage: outdated deps, layer violations, dead code, missing tests, oversized units — sorted by risk × effort |

Prompts are in `prompts/` — not installed into projects. Open in the kit and paste into your agent.

#### Bun and Deno runtime support in `node` skill

`skills/node/SKILL.md` updated:

- **Paths extended**: `**/bun.lockb`, `**/bunfig.toml`, `**/deno.json`, `**/deno.jsonc` — skill now auto-loads for Bun and Deno projects.
- **`allowed-tools` extended**: `Bash(bun:*)`, `Bash(deno:*)`.
- **New `## Bun` section**: drop-in replacement specifics — `bun install --frozen-lockfile`, built-in test runner, native TypeScript execution, `Bun.file()` / `Bun.serve()`, `bunfig.toml`.
- **New `## Deno` section**: Node-compatible Deno 2 — permission flags, `deno.json`, `jsr:@std/*`, `npm:` specifiers, `deno check / lint / fmt / test`.
- Description updated to include Bun, Deno, Elysia, and Hono.

### Changed

#### Version bump
- `KIT_VERSION` bumped to `1.7.0` in all four scripts: `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

---

## [1.6.0] - 2026-05-14

### Added

#### New skill: `graphql`
`skills/graphql/SKILL.md` — dedicated implementation skill for GraphQL APIs.

Covers:
- **Schema design**: type system rules, nullability conventions, custom scalars, input types, mutation payload pattern
- **Operations**: query / mutation / subscription best practices (mutations must return the mutated resource)
- **Resolvers**: thin-dispatcher pattern, context injection, service delegation
- **DataLoader**: N+1 prevention — batching pattern, per-request instantiation, missing-key handling
- **Pagination**: cursor-based (Relay spec) vs offset-based, when to use each
- **Error handling**: union types for domain errors vs bubbling for unexpected errors
- **Auth**: AuthN in HTTP middleware, AuthZ in resolvers or schema directives, field-level access
- **Code generation**: `@graphql-codegen/cli` setup (typed resolvers + client hooks), CI check for stale output
- **Server options**: Apollo Server, GraphQL Yoga, Pothos (Node); Strawberry / Ariadne (Python); gqlgen (Go); Hot Chocolate (.NET); Spring GraphQL / DGS (Java)
- **Testing**: unit (resolver + mocked context), integration (full schema execution), schema snapshot + breaking-change detection with `graphql-inspector`
- **Verification commands** for all stacks

Path-scoped: auto-loaded on `**/*.graphql`, `**/*.gql`, `**/graphql.config.*`, `**/codegen.yml`, `**/codegen.yaml`.

#### Routing — `graphql` added to all three root files
All three routing tables (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) now have a dedicated row for GraphQL:

- `api-design` row: narrowed to REST / OpenAPI contracts — GraphQL implementation removed.
- New `graphql` row: schemas, resolvers, dataloaders, subscriptions, codegen.

`skills/api-design/SKILL.md` description updated to clarify the split.

### Changed

#### Version bump
- `KIT_VERSION` bumped to `1.6.0` in all four scripts: `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

#### README skill table
- `graphql` added to the Cross-cutting row.
- `graphql` added to the `paths:`-carrying skills paragraph.

---

## [1.5.0] - 2026-05-14

### Added

#### Claude Code hooks (4 scripts in `tooling/claude/hooks/`)
Ready-to-use lifecycle hook scripts installed into `.claude/hooks/` by the install/update scripts.

| Script | Event | Mode | Purpose |
|---|---|---|---|
| `format-on-save.sh` | `PostToolUse(Edit\|Write)` | async | Runs the project's formatter (prettier, ruff, gofmt, rustfmt, dotnet format) on every saved file |
| `pre-bash-guard.sh` | `PreToolUse(Bash)` | blocking | Blocks `git push --force`, `git reset --hard`, recursive `rm -rf` outside tmp, SQL `DROP` without an approval marker |
| `notify-done.sh` | `Stop` | async | Desktop notification when Claude finishes (macOS: osascript/terminal-notifier; Linux: notify-send; Windows: PowerShell toast) |
| `session-summary.sh` | `PreCompact` | async | Saves a git status + diff snapshot to `.claude/session-log/` before context compaction |

`settings.json` updated to reference the real scripts (replaces the placeholder `echo` commands).
`install.sh` runs `chmod +x` on all `.sh` hook files after installation.

#### Claude Code rules (4 files in `tooling/claude/rules/`)
Path-scoped lightweight rule files — auto-loaded by Claude Code when a matching file is opened.

| File | Trigger paths | Coverage |
|---|---|---|
| `commit-style.md` | `**/.github/**`, `.gitignore`, `.gitattributes` | Conventional Commits, no force-push, one concern per commit |
| `test-naming.md` | `**/*.test.*`, `**/*.spec.*`, `**/tests/**` | No `.only`, no skip without issue link, deterministic tests |
| `migration-safety.md` | `**/migrations/**`, `**/*.sql`, `**/schema.prisma` | Reversible migrations, CONCURRENT indexes, no one-step column rename |
| `env-safety.md` | `**/.env*`, `**/config/**`, `**/appsettings*.json` | No hardcoded secrets, `.env.example` required, rotate leaked secrets |

#### `.mcp.json` project template (`tooling/claude/.mcp.json`)
Versioned MCP server configuration template installed at the project root (`.mcp.json`).
Includes commented examples for GitHub, filesystem, Postgres, Notion, and Linear servers with `${ENV_VAR}` expansion placeholders.

#### GitHub Actions workflow templates (`prompts/github-actions/`)
Four copy-paste CI workflow files — not installed automatically; copy to `.github/workflows/` in your project.

| File | Action used | Trigger |
|---|---|---|
| `claude-code.yml` | `anthropics/claude-code-action@v1` | `@claude` mention in issues / PRs / reviews |
| `codex-pr-review.yml` | `openai/codex-action@v1` | `@codex` mention in PR comments |
| `gemini-pr-review.yml` | `google-github-actions/run-gemini-cli@v0` | `@gemini review` in PR comments |
| `gemini-issue-triage.yml` | `google-github-actions/run-gemini-cli@v0` | New issue opened |

#### Claude agent `disallowedTools` + `permissionMode` frontmatter
All five Claude subagents now carry explicit safety guards:
- `architect`, `code-reviewer`, `codebase-investigator`: `disallowedTools: [Edit, Write, Bash, NotebookEdit]` — read-only enforcement on top of the existing `tools:` whitelist.
- `security-reviewer`: `disallowedTools: [Edit, Write, NotebookEdit]` — keeps Bash for audit commands, blocks writes.
- `test-runner`: `disallowedTools: [Edit, Write, NotebookEdit]` — can run tests, cannot modify source files.
- All five: `permissionMode: default`.

#### CI: new `lint-rules` job
Checks every file in `tooling/claude/rules/` has a `paths:` frontmatter key, and that every `tooling/claude/hooks/*.sh` has the executable bit set (mode `100755` in git).

#### CI: expanded smoke-test file coverage
Both `smoke-install` (bash) and `smoke-install-windows` (PowerShell) jobs now verify `.mcp.json`, all four hook scripts, and all four rule files are present after install.
Bash job additionally checks that hook scripts are executable after install.

### Fixed

#### `tooling/codex/config.toml` — `approval_policy` regression (introduced in v1.4.0)
- v1.4.0 changed `approval_policy` to `"suggest"` (incorrect — not a valid Rust CLI value).
- Reverted to `"on-request"` (confirmed correct per `global-config-template.toml` and official docs).
- Updated inline comment to show all valid values: `on-request | auto-approve | never`.
- Updated `sandbox_mode` inline comment: `workspace-write | read-only | danger-full-access` (removes the invalid `"none"` value listed in v1.4.0).

#### `tooling/codex/config.toml` — TOML structure: `project_doc_max_bytes` at wrong level
- `project_doc_max_bytes = 32768` was placed after the `[sandbox_workspace_write]` section header, making it a sub-key of that section instead of a root-level config key.
- Moved before the `[sandbox_workspace_write]` header.

#### `tooling/gemini/settings.json` — complete schema rewrite
The previous schema used keys that no longer exist in the current Gemini CLI. Full rewrite to the current schema:

| Old key | New key |
|---|---|
| `autoAccept` | `general.defaultApprovalMode` |
| `sandbox.enabled` | `tools.sandbox` |
| `tools.webSearch` | removed (use `tools.allowed`) |
| `tools.codeExecution` | removed |
| `tools.allowlist` | `tools.allowed` |
| `tools.excludelist` | `tools.exclude` |
| — | `general.checkpointing.enabled` (new) |
| — | `skills.enabled` (new) |
| — | `security.environmentVariableRedaction` (new) |

### Changed

#### Version bump
- `KIT_VERSION` bumped to `1.5.0` in all four scripts: `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

#### Install / update / uninstall scripts — Claude section expanded
- `install.sh` / `install.ps1`: now install `.mcp.json`, `hooks/`, and `rules/`.
- `update.sh` / `update.ps1`: now update `.mcp.json`, `hooks/`, and `rules/` using MD5 diff.
- `uninstall.sh` / `uninstall.ps1`: now remove `.mcp.json`, `.claude/hooks/`, and `.claude/rules/`.

---

## [1.4.0] - 2026-05-14

### Added

#### `paths:` and `allowed-tools:` frontmatter on 17 path-scoped skills (A1 + A2)
All language/framework skills now carry Claude Code native path-routing metadata.
When a file matching the pattern is opened, Claude Code auto-suggests the skill — no
manual routing entry needed in the project's CLAUDE.md.

Skills updated and their trigger patterns:

| Skill | Paths | Tools |
|---|---|---|
| `dotnet` | `**/*.cs`, `**/*.csproj`, `**/*.sln`, `**/global.json` | `dotnet` |
| `java-kotlin` | `**/*.java`, `**/*.kt`, `**/*.kts`, `**/build.gradle*`, `**/pom.xml` | `./gradlew`, `mvn` |
| `python` | `**/*.py`, `**/pyproject.toml`, `**/requirements*.txt` | `python3`, `uv`, `pytest`, `ruff` |
| `node` | `**/package.json`, `**/*.js`, `**/*.mjs`, `**/*.cjs` | `npm`, `pnpm`, `node`, `npx` |
| `go` | `**/*.go`, `**/go.mod` | `go` |
| `rust` | `**/*.rs`, `**/Cargo.toml` | `cargo` |
| `angular` | `**/angular.json`, `**/*.component.ts/html/scss`, `**/*.module.ts` | `ng`, `npm` |
| `vue` | `**/*.vue`, `**/vite.config.*` | `npm`, `pnpm`, `vite`, `vue-tsc` |
| `svelte` | `**/*.svelte`, `**/svelte.config.*` | `npm`, `pnpm`, `vite` |
| `react` | `**/*.jsx`, `**/*.tsx`, `**/next.config.*` | `npm`, `pnpm` |
| `mobile-flutter` | `**/*.dart`, `**/pubspec.yaml` | `flutter`, `dart` |
| `mobile-rn` | `**/app.json`, `**/*.native.ts/tsx`, `**/metro.config.*` | `npm`, `expo` |
| `database` | `**/*.sql`, `**/migrations/**`, `**/schema.prisma` | — |
| `infrastructure` | `**/Dockerfile*`, `**/*.tf`, `**/docker-compose*` | `docker`, `kubectl`, `terraform` |
| `github-workflow` | `**/.github/**` | `git`, `gh` |
| `monorepo` | `**/nx.json`, `**/turbo.json`, `**/pnpm-workspace.yaml` | `npm`, `pnpm` |
| `dependencies` | all manifest files (`package.json`, `*.csproj`, `Cargo.toml`, `go.mod`, `pom.xml`, …) | — |

Cross-cutting skills (`architecture`, `security`, `testing`, `code-review`, `observability`,
`messaging`, `error-handling`, `ai-dev`, `performance`, `accessibility`, `i18n`, `api-design`)
have no paths — they are loaded explicitly via CLAUDE.md routing.

#### `CLAUDE.local.md` support (B2)
- `CLAUDE.md` now documents that developers can create a `CLAUDE.local.md` in the project root
  for personal, gitignored preferences (local paths, aliases, verbosity level).
- `install.ps1` and `install.sh` gitignore hint now includes `CLAUDE.local.md` alongside
  `.claude/settings.local.json`, `.env`, `.env.*`.

#### Gemini CLI approval mode documentation (B4)
- `GEMINI.md` now has a `## How to run` section documenting `--approval-mode default|auto_edit|yolo`
  with a one-line description of each mode.

### Changed

#### `tooling/codex/config.toml` — Rust CLI alignment (B6)
- `approval_policy` renamed from `"on-request"` to `"suggest"` (Rust CLI canonical value).
- Inline comments added for every key documenting all valid values
  (`suggest`, `auto-edit`, `full-auto` for approval; `workspace-write`, `read-only`, `none` for sandbox).
- `web_search` comment documents `cached|enabled|disabled`.

#### Version bump
- `KIT_VERSION` bumped to `1.4.0` in `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

---

## [1.3.0] - 2026-05-14

### Added

#### New skill: `svelte`
- `skills/svelte/SKILL.md` — covers Svelte 5 and SvelteKit.
- Project structure: `src/lib/`, `src/routes/`, `src/lib/server/` layout.
- Reactivity model: compile-time rules, reassignment semantics, `$:` statements.
- Components: TypeScript, prop typing, event forwarding, `onMount` vs init guards.
- Stores: `writable`, `readable`, `derived` — when to use each; placement in `src/lib/stores/`.
- SvelteKit data loading: `+page.server.ts` (server-only) vs `+page.ts` (universal).
- Form actions: progressive-enhancement pattern with `use:enhance`, `fail()`, `redirect()`.
- Testing: Vitest + `@testing-library/svelte` for components; Playwright for E2E.
- Routing added to all three root files (CLAUDE.md, AGENTS.md, GEMINI.md).

#### New skill: `performance`
- `skills/performance/SKILL.md` — cross-stack profiling, benchmarking, and optimization.
- Universal rule: measure first, optimize the bottleneck, re-measure.
- Backend: profiling commands for .NET, Python, Go, Node, Rust; slow-query diagnosis with `EXPLAIN ANALYZE`; N+1 ORM patterns per stack; cache-aside pattern.
- Frontend: Core Web Vitals targets (LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1); bundle analysis; code splitting; virtualization.
- HTTP: compression, cache headers, pagination strategy.
- Benchmarking tools table: k6, wrk, BenchmarkDotNet, criterion, pytest-benchmark, Lighthouse CI.
- "What NOT to do" section covering common premature-optimization traps.
- Routing added to all three root files.

#### GitHub Actions CI (`.github/workflows/ci.yml`)
- `validate-example` job: runs `validate.sh` against `examples/filled-project` on every push/PR.
- `smoke-install` job (Ubuntu): installs the kit into a temp directory, verifies all expected files exist, runs dry-run update and uninstall.
- `smoke-install-windows` job (Windows): same smoke test using `install.ps1`, `update.ps1`, `uninstall.ps1`.
- `lint-skills` job: checks every `skills/*/` directory has a `SKILL.md` and that every skill has a "Final response requirements" section.

### Fixed

#### `validate.ps1` — STOP pattern precision
- Pattern was `"STOP"` (matches any word containing "STOP", e.g., "restart").
- Now aligned with `validate.sh`: uses `"^> .*STOP|⚠️.*STOP"` to match only template STOP notice lines.

#### Tool name validation in all scripts
- `install.ps1`, `install.sh`, `update.ps1`, `update.sh`, `uninstall.ps1`, `uninstall.sh` now reject unknown tool names early with a clear error message.
- Prevents silent no-ops from typos like `--tools cluade` or `--tools Codex`.

#### `README.md` — skill table gaps
- `java-kotlin` (added in v1.2.0) was missing from the Backend languages row.
- `svelte` and `performance` added to their respective rows.

#### `tooling/claude/settings.json` — WebFetch allowlist
- Added Java/Kotlin documentation domains missing after v1.2.0's `java-kotlin` skill: `kotlinlang.org`, `docs.spring.io`, `docs.gradle.org`, `maven.apache.org`, `junit.org`.

### Changed

#### `scripts/new-skill.ps1` and `new-skill.sh` — routing auto-insert
- Both scripts now insert a TODO placeholder row into all three routing tables (CLAUDE.md, AGENTS.md, GEMINI.md) immediately after scaffolding the skill file.
- Uses Python (bash) and `.Replace()` (PowerShell) to find the known anchor and insert before it.
- Prints a warning and skips gracefully if the anchor is not found.
- "Next steps" output now says to *replace* the TODO row rather than *add* a row.

#### `scripts/install.ps1` and `install.sh` — done output
- "Next steps" section now includes step 4: run `validate` to confirm templates are filled.
- Added a "Starter prompts" section listing the 5 most useful prompts with their purpose.
- "Later, to pull in kit updates…" line moved after the prompts list.

#### Version bump
- `KIT_VERSION` bumped to `1.3.0` in `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

---

## [1.2.0] - 2026-05-14

### Added

#### New skill: `java-kotlin`
- `skills/java-kotlin/SKILL.md` — covers Java and Kotlin on the JVM.
- Project structure: Clean Architecture layers adapted to Spring Boot / Ktor.
- Language guidance: Kotlin as modern default, Java for existing codebases, interop rules.
- Kotlin idioms: null safety, data classes, value classes, sealed classes, extension functions, coroutines, Flow.
- Spring Boot 3.x: controllers, `@ConfigurationProperties`, `@RestControllerAdvice`.
- JPA/Hibernate: entity mapping, Kotlin `noArg`/`allOpen` plugins, Flyway migrations.
- Build tools: Gradle Kotlin DSL (preferred) and Maven.
- Testing: JUnit 5 + MockK (Kotlin) / Mockito (Java) + Testcontainers (no H2).
- Code quality: detekt + ktlint for Kotlin, checkstyle for Java.
- Package and runtime maintenance section (same proactive protocol as dotnet).

#### Routing
- `java-kotlin` skill added to routing tables in `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`.

### Fixed

#### Template `project-template/ARCHITECTURE.md`
- Removed .NET-specific layer names (Domain/Application/Infrastructure/Interfaces) as hard defaults.
- Added multi-stack layer name examples for .NET, Python, Go, Rust, Node.
- Layers are now placeholders (`<Layer 1>`, etc.) — teams fill in their actual names.

#### `prompts/security-audit.md`
- Added missing vulnerability check commands: `pip-audit` (Python), `cargo audit` (Rust), `govulncheck ./...` (Go).

#### `skills/architecture/SKILL.md`
- Added `## Verification` section (all other skills had one; architecture was the only exception).

#### `skills/code-review/SKILL.md`
- Removed .NET-specific EF Core reference from the SQL injection check line.

#### `scripts/uninstall.ps1` / `uninstall.sh`
- Updated header comment to accurately describe surgical removal behavior.

### Changed

#### Version bump
- `KIT_VERSION` bumped to `1.2.0` in `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

---

## [1.1.0] - 2026-05-14

### Added

#### Proactive maintenance behavior (all 3 root files)
- New `## Proactive maintenance` section in `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`.
- Agents must surface outdated packages, runtime upgrades, deprecated APIs, and transitive CVEs — never apply silently.
- Explicit approval required before any out-of-scope maintenance change.
- "One concern per PR" rule enforced for maintenance items.

#### `.NET` skill — package and runtime maintenance section
- `## Package and runtime maintenance` section added to `skills/dotnet/SKILL.md`.
- Covers NuGet update protocol, `dotnet list package --outdated / --vulnerable`, .NET runtime upgrade checklist, LTS-only upgrade rule.

#### `security` skill — multi-stack rewrite
- Input validation, authentication, and verification sections now cover .NET, Python, Node, Go, and Rust.
- Stack-specific patterns in tables for each area.
- Verification commands extended: `npm audit`, `pip-audit`, `cargo audit`, `govulncheck`.

### Changed

#### Version bump
- `KIT_VERSION` bumped to `1.1.0` in `install.ps1`, `install.sh`, `update.ps1`, `update.sh`.

#### Agent model versions (Claude)
- All Sonnet agents updated from `claude-sonnet-4-5` to `claude-sonnet-4-6`.
- Test-runner agent updated from `claude-haiku-4-5` to `claude-haiku-4-5-20251001`.

#### WebFetch allowlist expanded
- `tooling/claude/settings.json` now covers documentation domains for all skills:
  `docs.python.org`, `packaging.python.org`, `pkg.go.dev`, `go.dev`, `doc.rust-lang.org`,
  `docs.rs`, `react.dev`, `nextjs.org`, `docs.flutter.dev`, `api.flutter.dev`,
  `expo.dev`, `docs.docker.com`, `kubernetes.io`, `developer.hashicorp.com`,
  `graphql.org`, `nodejs.org`.

#### Cross-tool alignment (CLAUDE.md, GEMINI.md)
- Engineering principles aligned with AGENTS.md: "One concern per PR", "Add abstractions only when...", "Avoid unrelated formatting changes".
- Security rules aligned: added "Never print...", "Do not read `.env`...", added CSP to the list.
- GEMINI.md context strategy: added step 6 (read relevant skill file), added "Do not scan entire repo" note.

### Fixed

#### Uninstall scripts — surgical removal
- `uninstall.ps1` and `uninstall.sh` no longer delete the entire `.claude/`, `.gemini/` or `.codex/` directories.
- Now removes only kit-installed files: root `.md`, `settings.json`, `agents/`, `skills/`.
- Parent directories are cleaned up only if empty — preserving `settings.local.json`, custom hooks, etc.

#### `validate.sh` — STOP pattern precision
- `grep -q "STOP"` replaced with `grep -qE '^> .*STOP|⚠️.*STOP'` to avoid false positives on words containing "STOP".

---

## [1.0.0] - 2026-05-14

### Added

#### New skills
- `python` — FastAPI / Django / pytest / uv / ruff / mypy / SQLAlchemy.
- `node` — Express / NestJS / Fastify, strict TypeScript, Vitest / Jest, pnpm.
- `go` — modules, errors with `%w`, contexts, table-driven tests, net/http + chi.
- `rust` — cargo workspaces, thiserror / anyhow, tokio, axum, sqlx.
- `react` — hooks, Next.js App Router, Remix, RTL + userEvent, MSW.
- `mobile-rn` — Expo + bare RN, React Navigation, Reanimated, EAS, Detox / Maestro.
- `mobile-flutter` — Riverpod / BLoC, go_router, mocktail, flutter_test.
- `infrastructure` — Docker, Kubernetes, Terraform / OpenTofu, GitHub Actions.
- `api-design` — REST, OpenAPI, GraphQL, RFC 7807 problem details, idempotency.
- `dependencies` — MIT-only enforcement, 20-line native rule, anti-overkill list.

#### Skill rewrites
- `database` — extended from EF Core-only to multi-engine (Postgres, MySQL, SQLite, MongoDB, Redis, ORM-agnostic).
- `testing` — added frontend testing section (Vitest, Vue Test Utils, Angular TestBed) and per-language examples (pytest, go test, cargo test, JUnit, Jest).

#### Operational scripts
- `scripts/update.sh` — bash equivalent of `update.ps1` with MD5 diff and version drift warning.
- `scripts/validate.sh` and `scripts/validate.ps1` — post-install check that `docs/ai/` templates have been filled (no `STOP` notices or `<!-- placeholder -->` left).
- `scripts/uninstall.sh` and `scripts/uninstall.ps1` — cleanly remove kit files from a project (preserves `docs/ai/`).
- `scripts/new-skill.sh` and `scripts/new-skill.ps1` — scaffold a new skill following the standard template.
- Version drift detection in `update.sh` / `update.ps1` — warns when installed `.kit-version` differs from source kit version.

#### Codex parity
- New `tooling/codex/agents/security-reviewer.toml` — closes the gap with Claude / Gemini.

#### Routing additions in CLAUDE.md, AGENTS.md, GEMINI.md
- Entries for all 10 new / rewritten skills.
- `dependencies` skill routing on "adding, updating, or replacing any library/package".

#### Project templates
- `STOP` notices on top of every `project-template/*.md` to prevent agents from reading empty templates.

#### Filled example
- `examples/filled-project/docs/ai/` — concrete reference of what filled templates look like.

#### Prompts
- `prompts/run-tests.md` — start a focused test pass.
- `prompts/security-audit.md` — targeted security review.

### Changed

#### Install / update semantics (clarified and tested)
- `install` now **always overwrites kit files** (skills, tooling configs, subagents, root `.md`). The `-Force` / `--force` flag has been removed — overwriting is the default and only mode.
- `install` continues to **never overwrite `docs/ai/`** — project content is always preserved.
- `update` is the MD5-diff-based path: only files that are missing or whose content differs are touched.

#### Subagent naming consistency (Codex)
- `codebase-explorer.toml` → `codebase-investigator.toml` to match Claude / Gemini.
- All `name = "..."` fields in Codex agents normalized to kebab-case
  (`code-reviewer`, `codebase-investigator`, `security-reviewer`, `test-runner`).

#### Subagent enrichment
- All five subagents in all three tools now include a "Context to read first" section pointing to `docs/ai/*` and the relevant skill file.

#### Engineering principles (all 3 root files)
- "Do not add dependencies without justification" upgraded to **"MIT license only. Avoid library bloat — if it can be done in ~20 lines of native code, do not pull a package."**

#### Definition of Done (all 3 root files)
- "covered by tests when practical" replaced by **"If tests are not added, state explicitly why and what should be tested manually."**

#### Gemini token budget
- Removed `includeDirectories: ["docs/ai"]` from `tooling/gemini/settings.json` — avoids loading all project docs into every session (~4 400 tokens saved per session).

#### Codex sandbox
- `project_doc_max_bytes = 32768` enabled in `tooling/codex/config.toml` (cap per-doc context size).

#### Claude permissions
- `WebFetch(domain:*)` deny replaced with an allowlist of documentation domains (docs.microsoft.com, learn.microsoft.com, vuejs.org, angular.dev, vitest.dev, npmjs.com).
- Added `vue-tsc`, `vite`, `vitest`, `npx vitest` to the bash allowlist.
- Added `git push --force-with-lease` and `git clean -fd` to deny (parity with `--force` and `reset --hard`).
- Branch-specific push restrictions (e.g. "deny push to main") cannot be expressed in the permission matcher (the `:*` wildcard only works at end-of-pattern). Enforcement of "no direct push to main / dev" stays in the `## Git rules` section of CLAUDE.md and at the GitHub branch-protection level.

#### CLAUDE.md
- Added `## Git rules` section (already present in AGENTS.md, missing here).

### Fixed

#### Install / update scripts
- `install.ps1` rewritten in ASCII — UTF-8 box-drawing characters were corrupting under Windows PowerShell 5.1 (Windows-1252 default reader).
- `update.ps1` rewritten in ASCII (same root cause).
- Gemini installer now copies `skills/` to `.gemini/skills/` — previously skipped, which broke the new GEMINI.md routing.
- `validate.ps1` strict-mode bug on `Select-String` returning a single object (not an array).

#### Repo hygiene
- Removed garbage directory `./{skills/{dotnet,angular,...}}` (result of an unexpanded bash brace expansion).
- Removed `./agents/` at repo root — duplicated `tooling/<tool>/agents/`, never installed by the scripts.
- Structural consistency: all skills now end with a "Final response requirements" section.

### Documentation
- README rewritten to reflect the new layout (`agents/` removed, mobile + transverse skills listed).
- README now includes:
  - Skill coverage table (backend / frontend / mobile / data / cross-cutting).
  - `prompts/` directory description with usage notes.
  - Install vs update semantics table.
  - `validate` script row.

---

## [1.0.0] - 2026-05-14

### Added
- Initial kit structure: skills, agents, tooling, project-template, prompts, scripts.
- Skills: dotnet, angular, vue, architecture, testing, code-review, database, security, github-workflow.
- Agents: codebase-investigator, code-reviewer, test-runner, architect, security-reviewer.
- Tooling adapters: Codex, Claude Code, Gemini CLI.
- Install scripts: PowerShell and Bash.
- Project template: PROJECT.md, ARCHITECTURE.md, DECISIONS.md, ROADMAP.md, COMMANDS.md, TESTING.md, GLOSSARY.md.
- Prompt templates: daily-ticket, feature-planning, code-review, bug-fix, refactor.

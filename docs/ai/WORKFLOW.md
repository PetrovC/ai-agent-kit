# Workflow

This repository follows an issue-first, PR-first workflow. Documentation can be
prepared directly when requested, but implementation work needs a GitHub issue
and a dedicated branch/PR.

## Issue-first Workflow

Every implementation must start from a GitHub issue. If no issue exists:

- create one if explicitly asked and GitHub access is available; or
- ask the user to create or link one before implementation.

The issue must define:

- problem;
- scope;
- acceptance criteria;
- out-of-scope items;
- verification expectations.

One concern belongs in one issue. Do not group unrelated implementation work.

## PR-first Delivery

- Never push directly to `main` or `master`.
- Create a dedicated branch for the issue.
- Keep one concern per PR.
- Run relevant validation before final response or PR.
- Document risks and assumptions.
- Do not open a PR unless explicitly asked.

## Branch Protection

The `master` branch is protected by a GitHub **repository ruleset** ("Main",
id `16408159`) — not classic **Settings -> Branches** protection, which is not
configured (the classic protection API returns 404 for `master`). Ownership is
declared in [`.github/CODEOWNERS`](../../.github/CODEOWNERS); the ruleset makes
that ownership and the quality gate enforceable. The ruleset can only be edited
in GitHub settings — this file documents the applied posture.

- **Require a pull request before merging.** No direct pushes to `master`.
- **Require approvals** (at least one) and **require review from Code Owners**,
  so changes need sign-off from the owner declared in `.github/CODEOWNERS`.
- **Require status checks to pass before merging** — the `quality-gate` check
  (see [TESTING.md](./TESTING.md), "Quality gate"). It aggregates every
  mandatory CI check in [`.github/required-checks.txt`](../../.github/required-checks.txt),
  so a single required check stays correct as jobs are added or renamed.
- **Require branches to be up to date before merging**, so checks run against
  the latest `master`.

Two deliberate trade-offs for a **solo-maintainer** repository — documented here
so the gap between what is *configured* and what is *exercised* stays honest:

- **Admin bypass is enabled** (`bypass_actors`: Repository admin, in
  `pull_request` mode). The approval and Code-Owner rules above are configured,
  but a repository admin can still merge a PR without an outside approval — a
  solo maintainer cannot approve their own PR, so requiring an approval no one
  else can give would block every change. Recent merges have used this bypass
  (they show no recorded review), which is why OpenSSF Scorecard reports
  Code-Review = 0 while Branch-Protection = 5.
- **Last-push approval is not required** (`require_last_push_approval: false`),
  for the same reason: with a single maintainer there is no second party to
  re-approve the most recent reviewable push.

If a second maintainer or an outside reviewer joins, tighten both — remove the
admin bypass and enable last-push approval — so the configured approval rules
become enforced rather than bypassed.

## Agent Branch, Preflight, and Language Rules

These rules are canonical for agent-driven work. The `CLAUDE.md`, `AGENTS.md`,
and `AGY.md` routers and the `github-workflow` skill reference this section.

### Branch pattern

Agent branches use five slash-separated segments:

```
agent/<agent>/<model>/<type>/<area>
```

Example: `agent/claude/opus-4.8/feat-docs/antigravity-impl`.

- Git refs allow dots, so `opus-4.8` is valid; refs only forbid `..`, a trailing
  `.`, and a trailing `.lock`.
- Avoid shell-hostile characters such as `()` and spaces. Use `feat-docs`, not
  `feat(docs)` — the latter breaks unquoted shell commands.
- `<type>` mirrors the Conventional Commit type (`feat`, `fix`, `docs`,
  `refactor`, `test`, `chore`, `perf`, `ci`), optionally suffixed with the area
  (`feat-docs`).

### Issue-first mandate

Every agent PR links a GitHub issue. If none exists, create one (problem,
scope, acceptance criteria, out-of-scope, verification) and link it to a
milestone when one applies unambiguously. One concern per issue and per PR.

### Master preflight

Before starting:

1. Start from `master` and pull so it is up to date.
2. Verify no open PR already covers the intended work.
3. If an open PR exists for that work, ask for authorization before continuing.

### English-only output

All branch names, issue text, PR text, commit messages, and code comments are
in English. Keep outputs clear, explicit, and unambiguous; reference docs where
useful; avoid padding.

## Agent Workflow

1. Audit before editing.
2. Load only relevant context.
3. Prefer deterministic search before broad investigation.
4. Use subagents only when justified by context cost or specialized review.
5. Do not mix documentation and implementation unless the issue explicitly says
   so.
6. Keep final edits in the main agent session.
7. Verify with commands from [COMMANDS.md](./COMMANDS.md).

## Documentation-only Work

Documentation-only work may update `docs/ai`, README, or CHANGELOG when the
task requests documentation. It must not silently include code, hooks, scripts,
provider adapter changes, or feature implementation.

For this docs completion task:

- do not modify install, update, or uninstall scripts;
- do not create feature code;
- do not create future governance assets outside `docs/ai`;
- do not create GitHub issues unless explicitly asked;
- do not open a PR unless explicitly asked.

In this repository, `docs/ai/` is official project-owned context and may be
tracked. The repository also intentionally tracks its own
Claude/Codex/Antigravity dogfood install so agents can use the kit while
maintaining the kit:

- `AGENTS.md`
- `CLAUDE.md`
- `AGY.md`
- `.agents/`
- `.claude/`
- `.codex/`
- `.agy/`
- `.agyignore`
- `.mcp.json`
- `.mcp.example.jsonc`
- `.kit-version`
- `.kit-manifest`

`validate --strict` byte-checks the tracked `.agy/` tree against `tooling/agy/`
plus the shared `skills/` source, and the `pr-versioning.yml` /
`pr-dogfood-parity.yml` CI jobs require all three dogfood trees to stay tracked.
Do not track local/runtime files such as `.claude/settings.local.json`,
`.claude/session-log/`, `.claude/worktrees/`, or `CLAUDE.local.md`.

## Comment-mention Agents

`@claude`, `@codex`, and `@agy` comments on an issue or PR are handled by the
single `agent-on-mention.yml` workflow (three gated jobs; the non-mentioned jobs
skip silently within one run). Maintainers should set their GitHub Actions
notification preference to "failures only" to suppress any residual "Run
skipped" emails.

## Public-release Hygiene

Public-release hygiene is documentation and metadata work that prepares the kit
for external users. It includes a root `LICENSE`, `SECURITY.md`,
`CONTRIBUTING.md`, root `VERSION`, release tags, and a release checklist.

Add these through scoped issues and PRs. Do not mix public-release hygiene with
script refactors, hook rewrites, new adapters, or roadmap feature
implementation.

For the step-by-step release preparation flow, safety invariants, and the
agent/human responsibility boundary, see [RELEASE.md](./RELEASE.md).

## When Future Work Is Discovered

Document the work as planned and recommend a scoped GitHub issue. A good issue
title starts with the concern, such as:

- `feat(scripts): add minimal and full install profiles`
- `feat(claude): add context statusline`
- `docs(shared): add subagent delegation policy`

Do not implement the future work in the same documentation task.

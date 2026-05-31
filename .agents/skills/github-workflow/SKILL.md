---
name: github-workflow
description: >
  Use when working with GitHub issues, pull requests, branches, commits,
  CI/CD workflows, release processes, or branch strategies.
paths:
  - "**/.github/**"
  - "**/.github/workflows/**"
allowed-tools:
  - "Bash(git:*)"
  - "Bash(gh:*)"
---

# GitHub Workflow Skill

## Goal

Keep the Git history clean, the PR process smooth, and the CI reliable.
Small, focused, reviewable changes. One concern per PR.

---

## Branch naming

```
feat/short-description        ← new feature
fix/short-description         ← bug fix
refactor/short-description    ← refactoring without behavior change
chore/short-description       ← tooling, deps, config
docs/short-description        ← documentation only
test/short-description        ← tests only
```

### Agent branches

AI-agent contributors use a five-segment pattern so the author, model, and
scope are traceable from the branch name:

```
agent/<agent>/<model>/<type>/<area>     ← e.g. agent/claude/opus-4.8/feat-docs/antigravity-impl
```

- Dots are valid in git refs (`opus-4.8`); refs only forbid `..`, a trailing
  `.`, and a trailing `.lock`.
- Avoid shell-hostile characters such as `()` and spaces — use `feat-docs`, not
  `feat(docs)`.
- Start from an up-to-date `master`, work issue-first (create and link an issue
  if none exists), and keep all branch/issue/PR/commit text in English.

---

## Commit messages

Use conventional commits:

```
feat: add half-day leave request support
fix: correct overlap detection for same-day requests
refactor: extract leave balance calculation to domain service
test: add regression test for holiday on weekend edge case
docs: update testing strategy for leave module
chore: update xUnit to 2.9.0
```

Rules:
- Lowercase after the colon.
- No period at the end.
- Imperative mood ("add", not "added" or "adds").
- 72 characters max for the subject line.
- Use the body for "why", not "what."

---

## Pull requests

- One PR per ticket / concern.
- PR title = commit message format: `feat: add half-day leave request support`.
- PR description must include:
  - What changed and why.
  - How to test / verify.
  - Link to the GitHub issue.
  - Any risk or follow-up.
- Do not push directly to `main` or `dev`.
- Do not merge your own PR without a review unless the team has agreed to this.

---

## GitHub issues

A well-written issue includes:
- Clear goal (one sentence).
- Context (why is this needed now).
- Scope (what is in / out).
- Acceptance criteria (checkboxes).
- Technical notes (relevant files, constraints).
- Validation commands.

---

## CI

- Do not merge a PR with a failing CI pipeline unless explicitly documented why.
- CI must run: build, test, lint at minimum.
- Do not disable CI checks to unblock a merge.

---

## What NOT to do

- Do not rewrite Git history on shared branches (`dev`, `main`, `staging`).
- Do not run `git push --force` on shared branches.
- Do not squash commits that contain useful history.
- Do not commit generated files, build artifacts, or IDE config.
- Do not commit secrets, tokens, or credentials.

---

## .gitignore essentials

Always ignore:
```
.env
.env.*
!.env.example
!.env.*.example
*.local.json
*.local.toml
bin/
obj/
node_modules/
dist/
.vs/
.idea/
*.user
```

Order matters: the `!.env.example` / `!.env.*.example` whitelist entries must come *after* `.env.*` to re-include example files (with fake values) that the deny pattern would otherwise silently ignore.

---

## Final response requirements

Always report:
- Branch / commit / PR action taken (`created`, `pushed`, `opened`, `merged`).
- Commit message format used (Conventional Commits or project convention).
- CI status check at time of action (passing / failing / pending).
- Any rebase / squash performed, and against which base.
- Any policy bypass requested (force-push, skipping a check) — must be justified.

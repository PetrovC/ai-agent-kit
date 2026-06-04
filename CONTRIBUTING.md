# Contributing

Thanks for helping improve `ai-agent-kit`. This repository uses a small,
issue-first process so changes stay reviewable and safe for all supported
tools.

## Issue-first Workflow

Start implementation work from a GitHub issue. The issue should describe the
goal, context, scope, acceptance criteria, out-of-scope items, and validation
commands. One concern belongs in one issue.

See [docs/ai/WORKFLOW.md](docs/ai/WORKFLOW.md) for the canonical workflow
policy, including PR-first delivery and documentation-only boundaries.

## Branches and Commits

Create one dedicated branch per issue. Use a short, conventional topic name:

- `feat/short-description`
- `fix/short-description`
- `docs/short-description`
- `test/short-description`
- `refactor/short-description`
- `chore/short-description`

Commit messages use Conventional Commits:

```text
<type>(<scope>): <subject>
```

Examples:

```text
docs(readme): clarify public install paths
fix(hooks): preserve guard fallback parsing
test(scripts): cover manifest dry-run behavior
```

Use the same type list and Git safety rules documented in
[AGENTS.md](AGENTS.md#git-rules) and [CLAUDE.md](CLAUDE.md#git-rules). Do not
push directly to `master`; open a pull request instead.

## Definition of Done

Before opening or updating a pull request, follow the repository Definition of
Done in [AGENTS.md](AGENTS.md#definition-of-done) and
[CLAUDE.md](CLAUDE.md#definition-of-done). Keep verification evidence in the PR
description so reviewers can see what passed, what was skipped, and why.

## Local Install and Validation

Use the canonical commands in [docs/ai/COMMANDS.md](docs/ai/COMMANDS.md). At a
minimum, validate this repository before opening a PR:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -Target "."
```

```bash
./scripts/validate.sh --target .
```

For install/update/uninstall smoke checks, use a temporary target so local
project files are not overwritten:

```powershell
$target = Join-Path $env:TEMP "aak-smoke-target"
New-Item -ItemType Directory -Path $target -Force | Out-Null
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Target $target -Tools "codex,claude,agy"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\update.ps1 -Target $target -DryRun
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Target $target -DryRun
```

```bash
tmp="$(mktemp -d)"
./scripts/install.sh --target "$tmp" --tools codex,claude,agy
./scripts/update.sh --target "$tmp" --dry-run
./scripts/uninstall.sh --target "$tmp" --dry-run
```

## Plugin pinning

If your project uses the kit as a Claude plugin, consider committing
`strictKnownMarketplaces: true` and `enabledPlugins: ["PetrovC/ai-agent-kit@ai-agent-kit"]`
to the project `settings.json`. This ensures all contributors automatically have
the plugin active and cannot accidentally install plugins from other sources.
See the README "Option B — Plugin pinning" section for the full snippet.

## Pull Requests

Each pull request should link the issue it resolves, explain what changed and
why, list the validation commands that passed, and call out any risk or follow
up. Keep unrelated maintenance or cleanup in separate issues and PRs.

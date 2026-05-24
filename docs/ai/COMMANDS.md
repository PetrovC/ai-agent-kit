# Commands

This file lists verified commands for maintaining `ai-agent-kit`. Do not invent
script options. If the scripts change, update this file in the same
documentation PR.

## Windows PowerShell

Use the ExecutionPolicy bypass form when the local policy blocks direct script
execution.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Target "C:\path\to\project" -Tools "codex,claude,gemini"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\update.ps1 -Target "C:\path\to\project" -DryRun
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Target "C:\path\to\project" -DryRun
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -Target "C:\path\to\project"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\new-skill.ps1 -Name "skill-name" -Description "Use when building a focused capability."
```

## POSIX Shell

```bash
./scripts/install.sh --target /path/to/project --tools codex,claude,gemini
./scripts/update.sh --target /path/to/project --dry-run
./scripts/uninstall.sh --target /path/to/project --dry-run
./scripts/validate.sh --target /path/to/project
./scripts/new-skill.sh --name skill-name --description "Use when building a focused capability."
```

## Script Semantics

| Script | Options verified | Notes |
|---|---|---|
| `install.ps1` / `install.sh` | `Target` or `--target`; `Tools` or `--tools` | Installs managed kit files. No dry-run mode exists. Valid tools: `codex`, `claude`, `gemini`. |
| `update.ps1` / `update.sh` | `Target` or `--target`; optional `Tools` or `--tools`; `DryRun` or `--dry-run` | Refreshes managed kit files. Does not overwrite `docs/ai`. |
| `uninstall.ps1` / `uninstall.sh` | `Target` or `--target`; optional `Tools` or `--tools`; `DryRun` or `--dry-run` | Removes managed files by manifest. Preserves `docs/ai` and user-added files. |
| `validate.ps1` / `validate.sh` | `Target` or `--target` | Checks required `docs/ai` files, template warning notices, HTML placeholders, and common template placeholders. |
| `new-skill.ps1` / `new-skill.sh` | `Name` or `--name`; optional `Description` or `--description` | Scaffolds `skills/<name>/SKILL.md` and routing placeholders. |

## Repository Smoke Commands

This repository is mainly Markdown, shell, PowerShell, TOML, JSON, YAML, and
provider configuration. Do not add unrelated .NET, Angular, Node, npm, or app
runtime commands here unless they are clearly examples for target projects.

```powershell
# Validate this repository's docs/ai folder.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -Target "."

# Validate the filled example project context.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -Target "examples\filled-project"

# Smoke install into a temporary target.
$target = Join-Path $env:TEMP "aak-smoke-target"
New-Item -ItemType Directory -Path $target -Force | Out-Null
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -Target $target -Tools "codex,claude,gemini"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\update.ps1 -Target $target -DryRun
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\uninstall.ps1 -Target $target -DryRun
```

```bash
# Validate this repository's docs/ai folder.
./scripts/validate.sh --target .

# Validate the filled example project context.
./scripts/validate.sh --target examples/filled-project

# Smoke install into a temporary target.
tmp="$(mktemp -d)"
./scripts/install.sh --target "$tmp" --tools codex,claude,gemini
./scripts/update.sh --target "$tmp" --dry-run
./scripts/uninstall.sh --target "$tmp" --dry-run

# Shell syntax check.
bash -n scripts/*.sh tooling/claude/hooks/*.sh tooling/codex/hooks/*.sh

# Optional if ShellCheck is installed.
shellcheck --severity=warning -e SC1090,SC1091 scripts/*.sh tooling/claude/hooks/*.sh tooling/codex/hooks/*.sh
```

## GitHub Actions Checks

The authoritative CI checks are the PR workflows under `.github/workflows/`.
Major workflow groups are:

- PR scripts shell: Bash lifecycle smoke tests, dry-runs, validation, and
  manifest behavior.
- PR scripts PowerShell: Windows lifecycle smoke tests, dry-runs, validation,
  literal-path behavior, and manifest behavior.
- PR hooks: Claude/Codex hook presence, guard behavior matrix, and hook smoke
  checks.
- PR docs: documentation and workflow semantic checks.
- PR tooling configs: Claude, Codex, and Gemini tooling validity checks.
- PR versioning/release hygiene: Claude/Codex dogfood install tracking policy,
  runtime/Gemini exclusion checks, and plugin/extension version consistency.

## Git Workflow Rules

- Never push directly to `main` or `master`.
- Do not code without a GitHub issue.
- Do not implement without a PR.
- One concern per issue.
- One concern per PR.
- Use Conventional Commits: `type(scope): subject`.
- Run relevant validation before final response or PR.
- If a requested implementation has no issue, create or ask for one before
  editing implementation files.
- If the work is exploratory, create or link a planning/research issue first.

## Documentation-only Tasks

For documentation-only tasks like completing `docs/ai`, do not modify
install/update/uninstall scripts, provider adapters, hooks, or feature code.
Record future work in `ROADMAP.md` or recommend a GitHub issue instead.

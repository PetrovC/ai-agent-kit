# `skills/` — shared, tool-agnostic skill catalogue

Each `<name>/SKILL.md` here is a single source file the kit installs into all three target tools:

- `.agents/skills/<name>/SKILL.md` (Codex)
- `.claude/skills/<name>/SKILL.md` (Claude Code)
- `.gemini/skills/<name>/SKILL.md` (Gemini CLI)

The README's "Key design principle" says `skills/` is **tool-agnostic in content**. This file documents what *exactly* "tool-agnostic" means here, because the YAML frontmatter is a deliberate exception that has confused contributors before (issue #92).

---

## Content is tool-agnostic

Every line of *prose* in a `SKILL.md` must apply equally to Codex, Claude Code, and Gemini. Things that violate this rule:

- Mentioning Claude-specific tool names (`Edit`, `Write`, `MultiEdit`, `Bash`) as if they were the only execution path.
- Mentioning Codex-specific concepts (`apply_patch`, `safety-strategy`, `sandbox`) as if they were universal.
- Mentioning Gemini-specific concepts (`/skills`, `--approval-mode`, `gemini extensions install`) as if they were universal.
- Tool-specific config syntax (`.claude/settings.json` shape, `[mcp_servers.x]` TOML, `.gemini/settings.json` JSON keys).
- Hardcoded build/test commands for a particular stack — point at `docs/ai/COMMANDS.md` instead (see also: prompts/* are stack-agnostic for the same reason).

The CI job `Skill structure check` in `.github/workflows/pr-docs.yml` enforces the structural shape (every skill must end with "Final response requirements"); content review is on humans.

---

## Frontmatter is shared metadata

The kit ships two Claude-recognized fields in shared-skill frontmatter:

```yaml
---
name: python
description: >
  Use when editing Python code (Django, FastAPI, pytest, …).
paths:
  - "**/*.py"
  - "**/pyproject.toml"
allowed-tools:
  - "Bash(python3:*)"
  - "Bash(pytest:*)"
  - "Bash(ruff:*)"
---
```

- **`paths:`** — Claude Code auto-loads the skill when an editor opens a matching file. Codex and Gemini ignore the field; they route via the table in `AGENTS.md` / `GEMINI.md`.
- **`allowed-tools:`** — Claude Code pre-approves the listed `Bash(<cmd>:*)` commands so the skill can run them without per-call confirmation. Codex and Gemini ignore the field; they inherit the user's approval mode (`safety-strategy`, `--approval-mode`).

These fields stay here, in the shared file, on purpose:

1. Splitting them into a Claude-only overlay would force a merge step at install time and double the failure surface of `install.sh`/`install.ps1`.
2. The fields are pure metadata. Codex and Gemini parsers don't fail on unknown YAML keys — they simply don't read them.
3. A single source-of-truth file is easier for contributors to evolve than three parallel copies.

The cost: the kit's "tool-agnostic" property applies to **skill content**, not to **skill frontmatter**. The README spells this out explicitly. Lint check #16 in `pr-docs.yml` (`lint-workflow-semantics`) rejects `allowed-tools:` values that don't follow the `Bash(<cmd>:*)` shape, because anything else would be both invalid Claude syntax and silently ignored by Codex/Gemini.

---

## Adding a new skill

`scripts/new-skill.sh --name <slug>` (or `.ps1`) scaffolds the file with the standard structure and inserts a TODO row into all three routing tables. Edit the result and:

- Fill the prose so it applies to every supported tool (see "Content is tool-agnostic" above).
- Add `paths:` if Claude Code should auto-load on file open.
- Add `allowed-tools:` only with `Bash(<cmd>:*)` values; Codex/Gemini won't see them but contributors reviewing the file should.
- Replace the TODO routing rows with a concrete description and re-run the install in any target project to deploy.

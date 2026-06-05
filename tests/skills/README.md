# Skill evals

Lightweight, offline validation for skill routing and content.
No LLM calls. No CI gate. Run manually when editing a skill.

## What is tested

| Check | Description |
|---|---|
| Path routing | Paths in `paths.txt` match the skill's `paths:` glob patterns |
| No-match paths | Paths in `no-paths.txt` do NOT match the skill's globs |
| Content | Every term in `must-contain.txt` appears in the skill's SKILL.md |

## How to run

```bash
# All evals
bash tests/skills/run-evals.sh

# One skill
bash tests/skills/run-evals.sh dotnet
```

## How to add an eval for a new skill

1. Create `tests/skills/<skill-name>/`
2. Add `paths.txt` — one file path per line that should trigger the skill
3. Add `no-paths.txt` — one file path per line that should NOT trigger the skill
4. Add `must-contain.txt` — key terms (one per line) that must appear in SKILL.md
5. Run `bash tests/skills/run-evals.sh <skill-name>` to verify

## File format

`paths.txt` / `no-paths.txt`: one file path per line (relative, no leading `/`).
`must-contain.txt`: one search term per line. Blank lines and `#` comments ignored.

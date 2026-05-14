#!/usr/bin/env bash
# new-skill.sh — Scaffold a new skill under skills/<name>/SKILL.md
#
# Creates the skill file with the standard structure all existing skills follow.
# Reminds you to update the routing tables in CLAUDE.md / AGENTS.md / GEMINI.md.
#
# Usage:
#   ./new-skill.sh --name <name> [--description "<one-line>"]
#
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME=""
DESCRIPTION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)        NAME="$2"; shift 2 ;;
        --description) DESCRIPTION="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "$NAME" ]]; then
    echo "Usage: $0 --name <name> [--description \"<one-line>\"]"
    exit 1
fi

# Validate name (kebab-case)
if [[ ! "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
    echo "Error: skill name must be kebab-case (a-z, 0-9, -). Got: $NAME"
    exit 1
fi

SKILL_DIR="$KIT_ROOT/skills/$NAME"
SKILL_FILE="$SKILL_DIR/SKILL.md"

if [[ -e "$SKILL_DIR" ]]; then
    echo "Error: skills/$NAME already exists."
    exit 1
fi

[[ -z "$DESCRIPTION" ]] && DESCRIPTION="Use when ... (describe the trigger condition for this skill in one sentence)."

mkdir -p "$SKILL_DIR"

cat > "$SKILL_FILE" <<EOF
---
name: $NAME
description: >
  $DESCRIPTION
---

# $(echo "$NAME" | sed 's/-/ /g' | awk '{ for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2) }1') Skill

## Goal

<!-- One paragraph: what does this skill ensure? What is the "definition of good"? -->

---

## Universal rules

- <!-- the 3-7 rules that apply regardless of stack / framework -->

---

## <Topic 1>

- <!-- detailed guidance for the first topic -->

---

## <Topic 2>

- <!-- detailed guidance for the second topic -->

---

## What NOT to do

- <!-- common anti-patterns to refuse, with reasons if non-obvious -->

---

## Verification commands

\`\`\`bash
# Commands to run to verify the work locally
\`\`\`

---

## Final response requirements

Always report:
- <!-- what the agent must include in its final response -->
- Any new dependency: name, version, **license (MIT only — see \`dependencies\` skill)**.
EOF

echo "+--------------------------------------+"
echo "|        new-skill scaffolded          |"
echo "+--------------------------------------+"
echo "  Created: skills/$NAME/SKILL.md"
echo ""
echo "Next steps:"
echo "  1. Edit skills/$NAME/SKILL.md and fill the placeholders."
echo "  2. Add a routing row in:"
echo "       tooling/claude/CLAUDE.md"
echo "       tooling/codex/AGENTS.md"
echo "       tooling/gemini/GEMINI.md"
echo "  3. Add an entry to CHANGELOG.md under [Unreleased] -> Added -> New skills."
echo "  4. Re-run the install script in any target project to deploy."

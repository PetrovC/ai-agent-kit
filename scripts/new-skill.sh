#!/usr/bin/env bash
# new-skill.sh — Scaffold a new skill under skills/<name>/SKILL.md
#
# Creates the skill file with the standard structure all existing skills follow,
# and inserts a TODO placeholder row into all three routing tables.
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

# Title: kebab-case → Title Case
TITLE="$(echo "$NAME" | sed 's/-/ /g' | awk '{ for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2) }1')"

cat > "$SKILL_FILE" <<EOF
---
name: $NAME
description: >
  $DESCRIPTION
---

# $TITLE Skill

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

# ── Insert placeholder routing rows ────────────────────────────────────────
# Uses Python (available on all target platforms) to insert rows before known
# anchors in each routing table. Prints a warning and skips on failure.

insert_routing_row() {
    local file="$1"
    local row="$2"
    local anchor="$3"
    python3 - "$file" "$row" "$anchor" <<'PYEOF'
import sys

filepath, row, anchor = sys.argv[1], sys.argv[2], sys.argv[3]
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()
idx = content.find(anchor)
if idx == -1:
    print(f"  [warn] anchor not found in {filepath} — add the row manually", file=sys.stderr)
    sys.exit(0)
content = content[:idx] + '\n' + row + content[idx:]
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF
}

CLAUDE_ROW="| TODO: describe when to use $NAME | \`$NAME\` skill |"
AGENTS_ROW="| TODO: describe when to use $NAME | \`\$$NAME\` |"
GEMINI_ROW="| TODO: describe when to use $NAME | \`skills/$NAME/SKILL.md\` |"

# Anchor: the blank line + --- that ends the skill routing table
ANCHOR_CLAUDE_GEMINI=$'\n\n---\n\n## Subagent routing'
ANCHOR_AGENTS=$'\n\nActivate only the skills relevant to the current task.'

insert_routing_row "$KIT_ROOT/tooling/claude/CLAUDE.md"   "$CLAUDE_ROW" "$ANCHOR_CLAUDE_GEMINI"
insert_routing_row "$KIT_ROOT/tooling/codex/AGENTS.md"    "$AGENTS_ROW" "$ANCHOR_AGENTS"
insert_routing_row "$KIT_ROOT/tooling/gemini/GEMINI.md"   "$GEMINI_ROW" "$ANCHOR_CLAUDE_GEMINI"

# ── Done ───────────────────────────────────────────────────────────────────
echo "+--------------------------------------+"
echo "|        new-skill scaffolded          |"
echo "+--------------------------------------+"
echo "  Created: skills/$NAME/SKILL.md"
echo "  Routing: TODO row added to CLAUDE.md, AGENTS.md, GEMINI.md"
echo ""
echo "Next steps:"
echo "  1. Edit skills/$NAME/SKILL.md and fill the placeholders."
echo "  2. Replace the TODO routing rows with a real description in:"
echo "       tooling/claude/CLAUDE.md"
echo "       tooling/codex/AGENTS.md"
echo "       tooling/gemini/GEMINI.md"
echo "  3. Add an entry to CHANGELOG.md under [Unreleased] -> Added -> New skills."
echo "  4. Re-run the install script in any target project to deploy."

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

# Validate that a flag's value argument is present and is not another flag.
# `--description ""` is still accepted (empty falls back to the default text
# below); only missing-arg and accidental flag-as-value cases are rejected.
require_value() {
    local opt="$1" value="$2" remaining="$3"
    if (( remaining < 2 )); then
        echo "Error: $opt requires a value" >&2
        exit 1
    fi
    if [[ "$value" == --* ]]; then
        echo "Error: $opt requires a value, got '$value'" >&2
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)        require_value "$1" "${2-}" "$#"; NAME="$2"; shift 2 ;;
        --description) require_value "$1" "${2-}" "$#"; DESCRIPTION="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "$NAME" ]]; then
    echo "Usage: $0 --name <name> [--description \"<one-line>\"]"
    exit 1
fi

# Validate name as a cross-tool identifier. The slug becomes:
#   - a directory under skills/<name>/
#   - a Codex activation token written as `$<name>` in AGENTS.md
#   - a Antigravity path .agy/skills/<name>/SKILL.md
#   - a row in three routing tables installed into target projects.
# So it must be true kebab-case (alphanumeric segments joined by single hyphens),
# not just "matches [a-z][a-z0-9-]*" which would also accept "foo-" or "foo--bar".
if [[ ! "$NAME" =~ ^[a-z][a-z0-9]*(-[a-z0-9]+)*$ ]]; then
    echo "Error: skill name must be lowercase alphanumeric segments joined by single hyphens (e.g. graphql-server). Got: $NAME" >&2
    exit 1
fi

# Reject Windows reserved device names so the same slug works on every
# target filesystem (PowerShell new-skill.ps1 has the same guard).
case "$NAME" in
    con|prn|aux|nul|com[1-9]|lpt[1-9])
        echo "Error: '$NAME' is a Windows reserved device name and cannot be used as a skill slug." >&2
        exit 1
        ;;
esac

# Locate a usable Python interpreter BEFORE creating any file. Routing-row
# insertion below uses Python; on Windows Git Bash, plain `python3` can
# resolve to the Microsoft Store launcher stub (`Python was not found …`),
# which exits non-zero and would otherwise leave a partially-scaffolded skill
# behind (skills/<name>/SKILL.md created but no routing rows inserted).
PYTHON_CMD=()
for candidate in python3 python "py -3"; do
    # shellcheck disable=SC2086
    if $candidate -c "import sys" >/dev/null 2>&1; then
        read -ra PYTHON_CMD <<< "$candidate"
        break
    fi
done

if [[ ${#PYTHON_CMD[@]} -eq 0 ]]; then
    echo "Error: no working Python interpreter found (tried: python3, python, py -3)." >&2
    echo "       new-skill.sh uses Python to insert routing rows into CLAUDE.md / AGENTS.md / AGY.md." >&2
    echo "       Install Python 3 (https://python.org, apt, brew, or the Windows Store launcher) and re-run." >&2
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
# Tracks per-file success so partial routing failures cannot masquerade as a
# full scaffold. Exits non-zero at the end if any anchor was missing.

ROUTING_RESULTS=()
ROUTING_OK=true

insert_routing_row() {
    local file="$1"
    local row="$2"
    local anchor="$3"
    local base
    base="$(basename "$file")"

    # `if` (not `cmd; rc=$?`) avoids set -e tripping when the helper exits 2.
    if "${PYTHON_CMD[@]}" - "$file" "$row" "$anchor" <<'PYEOF'
import sys

filepath, row, anchor = sys.argv[1], sys.argv[2], sys.argv[3]
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()
idx = content.find(anchor)
if idx == -1:
    sys.exit(2)
content = content[:idx] + '\n' + row + content[idx:]
with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
PYEOF
    then
        ROUTING_RESULTS+=("$base: row added")
    else
        ROUTING_RESULTS+=("$base: ANCHOR NOT FOUND — add the row manually")
        ROUTING_OK=false
    fi
}

CLAUDE_ROW="| TODO: describe when to use $NAME | \`$NAME\` skill |"
AGENTS_ROW="| TODO: describe when to use $NAME | \`\$$NAME\` |"
AGY_ROW="| TODO: describe when to use $NAME | \`.agy/skills/$NAME/SKILL.md\` |"

# Anchor: the blank line before the "## Subagent routing" heading that ends the
# skill routing section (stable across all three routers; does not depend on a
# `---` separator or specific trailing prose).
ANCHOR_SUBAGENT=$'\n\n## Subagent routing'

insert_routing_row "$KIT_ROOT/tooling/claude/CLAUDE.md"   "$CLAUDE_ROW" "$ANCHOR_SUBAGENT"
insert_routing_row "$KIT_ROOT/tooling/codex/AGENTS.md"    "$AGENTS_ROW" "$ANCHOR_SUBAGENT"
insert_routing_row "$KIT_ROOT/tooling/agy/AGY.md"   "$AGY_ROW" "$ANCHOR_SUBAGENT"

# ── Done ───────────────────────────────────────────────────────────────────
echo "+--------------------------------------+"
echo "|        new-skill scaffolded          |"
echo "+--------------------------------------+"
echo "  Created: skills/$NAME/SKILL.md"
echo "  Routing:"
for r in "${ROUTING_RESULTS[@]}"; do
    echo "    $r"
done
echo ""
if [[ "$ROUTING_OK" == "false" ]]; then
    echo "  WARNING: one or more routing anchors were missing; the skill file was"
    echo "           created but the routing tables above are incomplete."
    echo ""
fi
echo "Next steps:"
echo "  1. Edit skills/$NAME/SKILL.md and fill the placeholders."
echo "  2. Replace the TODO routing rows with a real description in:"
echo "       tooling/claude/CLAUDE.md"
echo "       tooling/codex/AGENTS.md"
echo "       tooling/agy/AGY.md"
echo "  3. Add an entry to CHANGELOG.md under [Unreleased] -> Added -> New skills."
echo "  4. Re-run the install script in any target project to deploy."

# Exit non-zero when routing was only partially applied. CI / release scripts
# treating new-skill.sh's exit status as truth must not see a green run when
# the routing tables are out of sync with the new skill file.
if [[ "$ROUTING_OK" == "false" ]]; then
    exit 1
fi

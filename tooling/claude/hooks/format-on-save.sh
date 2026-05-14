#!/usr/bin/env bash
# format-on-save.sh — PostToolUse(Edit|Write) hook
#
# Reads the edited file path from Claude's hook JSON (stdin) and runs the
# appropriate formatter. Runs async so it never blocks Claude.
#
# SETUP in .claude/settings.json:
#   "hooks": {
#     "PostToolUse": [{
#       "matcher": "Edit|Write",
#       "hooks": [{"type": "command", "command": ".claude/hooks/format-on-save.sh", "async": true}]
#     }]
#   }
#
# REQUIREMENTS: install the formatters you actually use.
#   prettier  — npm i -g prettier
#   ruff      — pip install ruff
#   gofmt     — comes with Go
#   rustfmt   — rustup component add rustfmt
#   dotnet    — dotnet tool install -g dotnet-format
set -euo pipefail

# Read hook JSON from stdin
INPUT=$(cat)
FILE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)

[[ -z "$FILE" || ! -f "$FILE" ]] && exit 0

EXT="${FILE##*.}"

case "$EXT" in
    js|mjs|cjs|ts|tsx|jsx|json|css|scss|html|md|yaml|yml)
        command -v prettier &>/dev/null && prettier --write "$FILE" --log-level silent || true
        ;;
    py)
        command -v ruff &>/dev/null && ruff format "$FILE" --quiet || true
        ;;
    go)
        command -v gofmt &>/dev/null && gofmt -w "$FILE" || true
        ;;
    rs)
        command -v rustfmt &>/dev/null && rustfmt "$FILE" 2>/dev/null || true
        ;;
    cs)
        command -v dotnet &>/dev/null && dotnet format --include "$FILE" 2>/dev/null || true
        ;;
esac

exit 0

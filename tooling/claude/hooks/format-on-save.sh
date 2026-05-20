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
#   prettier            — npm i -g prettier
#   ruff                — pip install ruff
#   gofmt               — comes with Go
#   rustfmt             — rustup component add rustfmt
#   dotnet              — dotnet tool install -g dotnet-format
#   google-java-format  — brew install google-java-format (or download jar)
#   ktlint              — brew install ktlint (or curl + chmod)
set -euo pipefail

# Read hook JSON from stdin
INPUT=$(cat)

# Same parser chain as pre-bash-guard.sh: jq → python3 → sed. A missing or
# broken interpreter (e.g. the Windows python3 App-Execution-Alias stub) yields
# empty stdout and falls through to the next parser, so the hook never wedges
# on a bad python. Sed is dependency-free and always runs as a last resort.
parse_with_jq() {
    command -v jq >/dev/null 2>&1 || return 1
    printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null
}
parse_with_python() {
    command -v python3 >/dev/null 2>&1 || return 1
    printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null
}
parse_with_sed() {
    printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p'
}

FILE=$(parse_with_jq || true)
[ -n "${FILE:-}" ] || FILE=$(parse_with_python || true)
[ -n "${FILE:-}" ] || FILE=$(parse_with_sed || true)

[[ -z "${FILE:-}" || ! -f "$FILE" ]] && exit 0

# Walk up from a C# file to the nearest enclosing .csproj or .sln. `dotnet
# format` needs to find a project/solution; `--include` only filters within
# one. Without this, the hook ran with whatever cwd it was invoked in and
# `dotnet format` silently failed (masked by 2>/dev/null) the moment the file
# was outside that cwd's project — i.e. most of the time.
find_dotnet_project() {
    local dir
    dir="$(cd "$(dirname "$1")" && pwd)"
    while [[ -n "$dir" && "$dir" != "/" ]]; do
        local hit
        hit="$(ls "$dir"/*.sln 2>/dev/null | head -1)"
        [[ -n "$hit" ]] && { printf '%s' "$hit"; return 0; }
        hit="$(ls "$dir"/*.csproj 2>/dev/null | head -1)"
        [[ -n "$hit" ]] && { printf '%s' "$hit"; return 0; }
        dir="$(dirname "$dir")"
    done
    return 1
}

EXT="${FILE##*.}"

case "$EXT" in
    js|mjs|cjs|ts|tsx|jsx|json|css|scss|html|md|yaml|yml)
        command -v prettier >/dev/null 2>&1 && prettier --write "$FILE" --log-level silent || true
        ;;
    py)
        command -v ruff >/dev/null 2>&1 && ruff format "$FILE" --quiet || true
        ;;
    go)
        command -v gofmt >/dev/null 2>&1 && gofmt -w "$FILE" || true
        ;;
    rs)
        command -v rustfmt >/dev/null 2>&1 && rustfmt "$FILE" 2>/dev/null || true
        ;;
    cs)
        if command -v dotnet >/dev/null 2>&1; then
            proj="$(find_dotnet_project "$FILE" 2>/dev/null || true)"
            if [[ -n "$proj" ]]; then
                dotnet format "$proj" --include "$FILE" 2>/dev/null || true
            fi
            # No enclosing project — skip silently (file is not in a .NET project).
        fi
        ;;
    java)
        command -v google-java-format >/dev/null 2>&1 && google-java-format -i "$FILE" 2>/dev/null || true
        ;;
    kt|kts)
        command -v ktlint >/dev/null 2>&1 && ktlint -F "$FILE" >/dev/null 2>&1 || true
        ;;
esac

exit 0

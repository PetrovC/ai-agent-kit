#!/usr/bin/env bash
# format-on-save.sh — Codex PostToolUse hook (file edits)
#
# Reads the edited file path from Codex's hook JSON (stdin) and runs the
# appropriate formatter. Best-effort: never fails the turn.
#
# Wired in .codex/hooks.json:
#   { "hooks": { "PostToolUse": [
#       { "matcher": "Edit|Write|Patch",
#         "hooks": [{"type":"command","command":".codex/hooks/format-on-save.sh"}] } ] } }
#
# REQUIREMENTS: install the formatters you actually use.
#   prettier  — npm i -g prettier
#   ruff      — pip install ruff
#   gofmt     — comes with Go
#   rustfmt   — rustup component add rustfmt
#   dotnet    — dotnet tool install -g dotnet-format
set -euo pipefail

INPUT=$(cat)

# Robust file_path extraction: probe jq, then python3, then dependency-free sed.
# Same Windows-python3-stub caveat as pre-bash-guard.
parse_with_jq() {
    command -v jq >/dev/null 2>&1 || return 1
    [ "$(printf '{"tool_input":{"file_path":"_ok_"}}' | jq -r '.tool_input.file_path // ""' 2>/dev/null)" = "_ok_" ] || return 1
    printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null
}
parse_with_python() {
    command -v python3 >/dev/null 2>&1 || return 1
    local probe
    probe=$(printf '{"tool_input":{"file_path":"_ok_"}}' | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null) || return 1
    [ "$probe" = "_ok_" ] || return 1
    printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null
}
parse_with_sed() {
    printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p'
}

FILE=$(parse_with_jq || true)
[ -n "${FILE:-}" ] || FILE=$(parse_with_python || true)
[ -n "${FILE:-}" ] || FILE=$(parse_with_sed || true)

[[ -z "${FILE:-}" || ! -f "$FILE" ]] && exit 0

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

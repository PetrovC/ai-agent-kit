#!/usr/bin/env bash
# format-on-save.sh — Codex PostToolUse hook (apply_patch)
#
# Codex's apply_patch tool reports its payload as tool_input.command (the patch
# text), NOT tool_input.file_path — so parsing a file path out of the hook JSON
# is unreliable. Instead this formats every file git currently reports as
# modified (uncommitted) by known extension. Payload-agnostic and robust;
# formatters are idempotent so re-formatting an already-clean file is a no-op.
# Best-effort: never fails the turn.
#
# Wired in .codex/hooks.json (PostToolUse matcher "apply_patch").
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

# Drain stdin so Codex doesn't see a broken pipe; we don't rely on its content.
cat >/dev/null 2>&1 || true

command -v git >/dev/null 2>&1 || exit 0
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || exit 0
cd "$ROOT" || exit 0

# Walk up from a C# file to the nearest enclosing .csproj or .sln. `dotnet
# format` needs a project/solution; without it the call silently failed
# (masked by 2>/dev/null) whenever the file wasn't directly under cwd's
# project — i.e. most of the time.
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

format_file() {
    local f="$1"
    [ -f "$f" ] || return 0
    case "${f##*.}" in
        js|mjs|cjs|ts|tsx|jsx|json|css|scss|html|md|yaml|yml)
            command -v prettier >/dev/null 2>&1 && prettier --write "$f" --log-level silent || true ;;
        py)
            command -v ruff >/dev/null 2>&1 && ruff format "$f" --quiet || true ;;
        go)
            command -v gofmt >/dev/null 2>&1 && gofmt -w "$f" || true ;;
        rs)
            command -v rustfmt >/dev/null 2>&1 && rustfmt "$f" 2>/dev/null || true ;;
        cs)
            if command -v dotnet >/dev/null 2>&1; then
                local proj
                proj="$(find_dotnet_project "$f" 2>/dev/null || true)"
                if [ -n "$proj" ]; then
                    dotnet format "$proj" --include "$f" 2>/dev/null || true
                fi
            fi ;;
        java)
            command -v google-java-format >/dev/null 2>&1 && google-java-format -i "$f" 2>/dev/null || true ;;
        kt|kts)
            command -v ktlint >/dev/null 2>&1 && ktlint -F "$f" >/dev/null 2>&1 || true ;;
    esac
}

# Uncommitted changes: unstaged + staged, deduplicated. Null-delimited for
# paths with spaces.
{
    git diff --name-only -z 2>/dev/null || true
    git diff --cached --name-only -z 2>/dev/null || true
} | sort -zu | while IFS= read -r -d '' f; do
    format_file "$f"
done

exit 0

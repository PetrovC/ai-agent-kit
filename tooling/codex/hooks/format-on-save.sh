#!/usr/bin/env bash
if [[ -n "${AAK_DEBUG:-}" && "${AAK_DEBUG}" != "0" && "${AAK_DEBUG}" != "false" ]]; then set -x; fi  # AAK_DEBUG: opt-in trace (#305)
# format-on-save.sh — Codex PostToolUse hook (apply_patch)
#
# Closes #57: previously this hook ignored its stdin payload and ran the
# formatters on EVERY uncommitted file in the worktree. In a dirty worktree
# (the common case during an agent session), a small Codex edit would also
# reformat user work-in-progress files that the agent never touched — silent
# scope creep, noisy diffs, contradicting the README's "format files written
# by the agent" promise.
#
# Now the hook parses the apply_patch payload (`tool_input.command`, which
# is the patch text) and formats only files the patch added or updated.
# Files marked `*** Delete File:` are skipped (they're gone). If the payload
# can't be parsed at all, the hook emits a stderr warning and exits 0 — it
# never silently sweeps the worktree.
#
# Formatters are idempotent so re-formatting an already-clean file is a
# no-op. Best-effort: never fails the turn.
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

# Slurp the full JSON event from stdin (Codex feeds it in). Empty stdin =
# no parse possible = exit silently rather than sweep the worktree.
PAYLOAD="$(cat 2>/dev/null || true)"
[ -n "$PAYLOAD" ] || exit 0

command -v git >/dev/null 2>&1 || exit 0
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || exit 0
cd "$ROOT" || exit 0

# Extract tool_input.command (the apply_patch text) from the JSON. Try
# jq → python3 → sed in that order so the hook works on the same minimal
# toolchain pre-bash-guard.sh assumes (jq is preferred; python3 ships on
# every supported platform; sed is the irreducible fallback).
PATCH_TEXT=""
if command -v jq >/dev/null 2>&1; then
    PATCH_TEXT="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
fi
if [ -z "$PATCH_TEXT" ] && command -v python3 >/dev/null 2>&1; then
    PATCH_TEXT="$(printf '%s' "$PAYLOAD" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
v = (d.get("tool_input") or {}).get("command", "")
sys.stdout.write(v if isinstance(v, str) else "")
' 2>/dev/null || true)"
fi
if [ -z "$PATCH_TEXT" ]; then
    # Last-ditch: pull the value out of `"command":"…"` with sed. Handles
    # the common case; fails on unusual JSON layouts (multi-line escaped
    # strings) — that's why jq / python3 come first.
    PATCH_TEXT="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"tool_input"[[:space:]]*:[[:space:]]*{[^{}]*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1 || true)"
fi

if [ -z "$PATCH_TEXT" ]; then
    # Parse failed completely. Be transparent rather than fall back to
    # the all-uncommitted sweep this hook used to do (issue #57).
    echo "format-on-save: could not extract tool_input.command from payload; skipping" >&2
    exit 0
fi

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
    # Source-code extensions only. Issue #152: previously the prettier
    # arm also matched json|css|scss|html|md|yaml|yml — running on every
    # doc / config edit. Trimmed to JS/TS source; non-source paths
    # (md, json, yml, sh, ps1, …) fall into the *) catch-all and are
    # silently skipped. Users who want prettier on docs can run it
    # manually or add a project-level pre-commit hook.
    case "${f##*.}" in
        js|mjs|cjs|ts|tsx|jsx)
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
        rb)
            command -v rubocop >/dev/null 2>&1 && rubocop -a --force-exclusion "$f" >/dev/null 2>&1 || true ;;
        *)
            : ;; # non-source extension — skip silently
    esac
}

# Pull every `*** Add File: <path>` and `*** Update File: <path>` header
# from the patch text. Skip `*** Delete File:` — the file is gone. Paths
# in apply_patch are repo-root relative (Codex always cd's to the worktree
# root before applying). Dedupe so a single patch touching the same file
# twice doesn't format it twice.
mapfile -t PATCHED_FILES < <(
    printf '%s\n' "$PATCH_TEXT" \
        | sed -nE 's/^\*\*\* (Add|Update) File: (.+)$/\2/p' \
        | awk 'NF && !seen[$0]++'
)

[ "${#PATCHED_FILES[@]}" -gt 0 ] || exit 0

for f in "${PATCHED_FILES[@]}"; do
    format_file "$f"
done

exit 0

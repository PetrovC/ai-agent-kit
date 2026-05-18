#!/usr/bin/env bash
# pre-bash-guard.sh — Codex PreToolUse(Bash) hook
#
# Blocks known destructive commands before they run.
# Exit code 2 = block the command and show stderr to Codex.
# Exit code 0 = allow the command.
#
# Wired in .codex/hooks.json:
#   { "hooks": { "PreToolUse": [
#       { "matcher": "Bash",
#         "hooks": [{"type":"command","command":".codex/hooks/pre-bash-guard.sh"}] } ] } }
set -euo pipefail

INPUT=$(cat)

block() {
    echo "$1" >&2
    exit 2
}

# Extract the command string from the hook JSON input.
#
# Never silently allow a command just because a parser is missing or broken.
# `command -v python3` is NOT reliable: on Windows the App-Execution-Alias stub
# resolves on PATH, prints "Python was not found", and exits 0 — so neither a
# presence check nor an exit-code check catches it. Each parser is *probed* with
# a known input and only used if it returns the expected value. The final
# fallback is a dependency-free sed extraction that always runs.
parse_with_jq() {
    command -v jq >/dev/null 2>&1 || return 1
    [ "$(printf '{"tool_input":{"command":"_ok_"}}' | jq -r '.tool_input.command // ""' 2>/dev/null)" = "_ok_" ] || return 1
    printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null
}
parse_with_python() {
    command -v python3 >/dev/null 2>&1 || return 1
    local probe
    probe=$(printf '{"tool_input":{"command":"_ok_"}}' | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null) || return 1
    [ "$probe" = "_ok_" ] || return 1
    printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null
}
parse_with_sed() {
    printf '%s' "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p'
}

CMD=$(parse_with_jq || true)
[ -n "${CMD:-}" ] || CMD=$(parse_with_python || true)
[ -n "${CMD:-}" ] || CMD=$(parse_with_sed || true)

# Block force-push. Match a real -f / --force *flag*, not a branch name that
# merely contains "-f" (e.g. `git push origin feature-foo` must pass).
if echo "$CMD" | grep -qE 'git[[:space:]]+push.*[[:space:]](-f([[:space:]]|$)|--force)'; then
    block "BLOCKED: force-push is not allowed. Use --force-with-lease only after explicit approval."
fi

# Block hard reset
if echo "$CMD" | grep -qE 'git reset --hard'; then
    block "BLOCKED: git reset --hard can destroy uncommitted work. Use git stash or explicit approval."
fi

# Block recursive+force delete on dangerous targets.
# POSIX ERE has no negative lookahead. Detect the rm recursive+force "shape"
# case-insensitively (-rf, -Rf, -fr, split -r -f, and long --recursive/--force
# forms), then allow an explicit temp target, otherwise block dangerous
# operands: an absolute path, home, parent traversal, the current directory
# (. ./) or a bare glob (* ./*). `rm -rf .` / `rm -rf *` are game-over.
if echo "$CMD" | grep -qiE 'rm[[:space:]]+-([a-z]*r[a-z]*f|[a-z]*f[a-z]*r)|rm[[:space:]]+-[rf][[:space:]]+-[rf]|rm[[:space:]]+(--recursive[[:space:]]+(--force|-f)|--force[[:space:]]+(--recursive|-r)|-r[[:space:]]+--force|-f[[:space:]]+--recursive)'; then
    if echo "$CMD" | grep -qE 'rm[[:space:]].*[[:space:]](--[[:space:]]+)?(/tmp/|/var/tmp/)'; then
        : # explicitly allowed temp target
    elif echo "$CMD" | grep -qE 'rm[[:space:]].*[[:space:]](--[[:space:]]+)?(/|~|\.\.)' \
      || echo "$CMD" | grep -qE 'rm[[:space:]].*[[:space:]](--[[:space:]]+)?(\.|\./|\*|\./\*)([[:space:]]|$)'; then
        block "BLOCKED: recursive force-delete (rm -rf) on an absolute path, home, parent traversal, the current directory (.) or a bare glob (*) requires explicit approval."
    fi
fi

# Block DROP TABLE / DROP DATABASE without explicit approval marker
if echo "$CMD" | grep -iqE 'DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)'; then
    if ! echo "$CMD" | grep -q 'APPROVED_DESTRUCTIVE'; then
        block "BLOCKED: SQL DROP requires explicit approval. Add comment '-- APPROVED_DESTRUCTIVE' to proceed."
    fi
fi

exit 0

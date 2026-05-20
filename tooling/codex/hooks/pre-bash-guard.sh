#!/usr/bin/env bash
# pre-bash-guard.sh — Codex PreToolUse(Bash) hook
#
# Blocks known destructive commands before they run.
# Exit code 2 = block the command and show stderr to Codex.
# Exit code 0 = allow the command.
#
# SCOPE / HONEST LIMITS: this is a best-effort *denylist* over the raw command
# string, not a sandbox. It deliberately catches the destructive commands an
# agent issues by mistake (force-push, rm -rf, DROP, ref deletion). It does
# NOT, and cannot, defeat deliberate obfuscation: base64|eval, here-strings,
# `bash -c "$(...)"`, exotic encodings. The real safety boundary is the tool's
# own sandbox / approval mode — keep that enabled. This guard is the cheap
# second layer, not the only one.
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
# We must never silently allow a command just because a parser is missing or
# broken. The correctness guarantee is the empty-output fallthrough below: a
# missing/broken parser yields empty stdout, so we move to the next parser and
# ultimately to the dependency-free sed extraction that always runs. (This is
# why no per-parser "probe" is needed — the Windows python App-Execution-Alias
# stub prints to stderr and emits nothing on stdout, so it falls through like
# any other failure. One spawn per parser instead of two on every Bash call.)
parse_with_jq() {
    command -v jq >/dev/null 2>&1 || return 1
    printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null
}
parse_with_python() {
    command -v python3 >/dev/null 2>&1 || return 1
    printf '%s' "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null
}
parse_with_sed() {
    printf '%s' "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p'
}

CMD=$(parse_with_jq || true)
[ -n "${CMD:-}" ] || CMD=$(parse_with_python || true)
[ -n "${CMD:-}" ] || CMD=$(parse_with_sed || true)

# Block force-push. Match a real -f / --force *flag* (not a branch name that
# merely contains "-f", e.g. `git push origin feature-foo` must pass), the
# `+refspec` force form (`git push origin +main`), and the destructive
# --mirror / --delete / -d forms.
if echo "$CMD" | grep -qE 'git[[:space:]]+push.*[[:space:]](-f([[:space:]]|$)|--force([[:space:]]|$)|--mirror|--delete|-d([[:space:]]|$)|\+[^[:space:]]+:?)'; then
    block "BLOCKED: force/mirror/delete push is not allowed. Use --force-with-lease only after explicit approval; never +refspec, --mirror, or --delete unattended."
fi

# Block branch / ref deletion that destroys history pointers.
if echo "$CMD" | grep -qE 'git[[:space:]]+branch[[:space:]].*(-D|--delete[[:space:]]+--force|--force[[:space:]]+--delete)([[:space:]]|$)'; then
    block "BLOCKED: 'git branch -D' force-deletes a branch (possibly unmerged work). Use -d or explicit approval."
fi
if echo "$CMD" | grep -qE 'git[[:space:]]+update-ref[[:space:]].*-d'; then
    block "BLOCKED: 'git update-ref -d' deletes a ref directly. Requires explicit approval."
fi

# Block destructive reset (--hard discards working tree, --keep discards too).
if echo "$CMD" | grep -qE 'git[[:space:]]+reset[[:space:]].*(--hard|--keep)'; then
    block "BLOCKED: git reset --hard/--keep can destroy uncommitted work. Use git stash or explicit approval."
fi

# Block destructive `git switch` variants. `git switch <branch>` itself is safe
# and Git refuses to switch when it would overwrite local changes; these flags
# bypass that guard or reset a branch pointer:
#   --discard-changes / -f / --force  : throw away local modifications
#   -C <name> / --force-create        : create/reset and switch (resets branch ref)
if echo "$CMD" | grep -qE 'git[[:space:]]+switch[[:space:]].*(--discard-changes|--force-create|--force|-f|-C)([[:space:]]|$)'; then
    block "BLOCKED: 'git switch --discard-changes/--force/-f/-C/--force-create' can discard uncommitted work or reset a branch pointer. Commit/stash first, or use plain 'git switch <branch>' / 'git switch -c <new>'."
fi

# Block destructive `git clean`. The force flags (-f / --force, including
# combined short forms like -fd, -fdx, -ffdx) actually delete untracked files;
# -d/-x/-X widen the scope. `git clean -n` / `--dry-run` (no -f) stays allowed
# as a safe preview.
if echo "$CMD" | grep -qE 'git[[:space:]]+clean([[:space:]]+|.*[[:space:]])(-[a-zA-Z]*f[a-zA-Z]*|--force)([[:space:]]|$)'; then
    block "BLOCKED: 'git clean -f' deletes untracked files (often irrecoverable). Use 'git clean -n' / '--dry-run' first; require explicit approval before a forceful clean."
fi

# Block obfuscated rm via $IFS word-splitting (rm${IFS}-rf${IFS}/ evades the
# whitespace-anchored shape detector below — there is no legitimate reason for
# $IFS to appear in an rm invocation).
if echo "$CMD" | grep -qE '(^|[^a-zA-Z0-9])rm[^a-zA-Z0-9]{0,3}\$\{?IFS'; then
    block "BLOCKED: rm using \$IFS word-splitting is an obfuscation pattern. Use an explicit, plainly-written command."
fi

# Block recursive+force delete on dangerous targets.
# POSIX ERE has no negative lookahead. Detect the rm recursive+force "shape"
# case-insensitively (-rf, -Rf, -fr, split -r -f, and long --recursive/--force
# forms), then allow an explicit temp target, otherwise block dangerous
# operands: an absolute path, home, parent traversal, the current directory
# (. ./) or a bare glob (* ./*). `rm -rf .` / `rm -rf *` are game-over.
if echo "$CMD" | grep -qiE 'rm[[:space:]]+-([a-z]*r[a-z]*f|[a-z]*f[a-z]*r)|rm[[:space:]]+-[rf][[:space:]]+-[rf]|rm[[:space:]]+(--recursive[[:space:]]+(--force|-f)|--force[[:space:]]+(--recursive|-r)|-r[[:space:]]+--force|-f[[:space:]]+--recursive)'; then
    # A variable / command-substituted *operand* (the token right after the rm
    # flags is $VAR, "${VAR}", "$(...)", or `...`) — the agent cannot know what
    # it expands to. Anchored to the operand so `rm -rf node_modules && echo
    # "$X"` (literal safe target, unrelated trailing $var) is NOT a false hit.
    if echo "$CMD" | grep -qE 'rm[[:space:]]+((-{1,2}[A-Za-z][A-Za-z-]*)[[:space:]]+)+(--[[:space:]]+)?("|\\")?(\$|`)'; then
        block "BLOCKED: recursive force-delete (rm -rf) with a variable or command-substituted target (\$VAR, \$(...), \`...\`) is unsafe — the agent cannot know what it expands to. Use an explicit literal path or explicit approval."
    elif echo "$CMD" | grep -qE 'rm[[:space:]].*[[:space:]](--[[:space:]]+)?(/tmp/|/var/tmp/)'; then
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

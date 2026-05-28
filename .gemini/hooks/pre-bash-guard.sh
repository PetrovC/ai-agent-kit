#!/usr/bin/env bash
# pre-bash-guard.sh — Gemini BeforeTool(run_shell_command) hook
#
# Blocks known destructive commands before they run.
# Exit code 2 = block the command and show stderr to Gemini.
# Exit code 0 = allow the command.
#
# SCOPE / HONEST LIMITS: this is a best-effort *denylist* over the raw command
# string, not a sandbox. It deliberately catches the destructive commands an
# agent issues by mistake (force-push, rm -rf, DROP, ref deletion). It does
# NOT, and cannot, defeat deliberate obfuscation: base64|eval, here-strings,
# `bash -c "$(...)"`, exotic encodings. The real safety boundary is the tool's
# own approval mode — keep `default` or `auto_edit` enabled on Gemini. This
# guard is the cheap second layer, not the only one.
#
# Wired in .gemini/settings.json:
#   { "hooks": { "BeforeTool": [
#       { "matcher": "run_shell_command",
#         "hooks": [{"type":"command","command":"bash .gemini/hooks/pre-bash-guard.sh"}] } ] } }
#
# stdin schema (per https://geminicli.com/docs/hooks/reference/):
#   {
#     "hook_event_name": "BeforeTool",
#     "tool_name": "run_shell_command",
#     "tool_input": { "command": "<the command>", "timeout": 30000 },
#     "session_id": "...", "transcript_path": "...", "cwd": "...", "timestamp": "..."
#   }
# We only read .tool_input.command, which is the same field Claude/Codex pass.
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

# Fail closed if all three parsers returned empty. Without this, an unknown
# input schema (missing `tool_input.command`, malformed JSON, future schema
# change) leaves $CMD="" — every grep below then fails to match and the
# script exits 0, i.e. the hook silently authorizes the call. A
# BeforeTool(run_shell_command) guard must refuse what it cannot inspect.
if [ -z "${CMD:-}" ]; then
    block "BLOCKED: pre-bash-guard could not extract the Bash command from its input (empty stdin, malformed JSON, or unfamiliar hook schema). Refusing fail-open."
fi

# Shared prefix for `git` + optional global options before the subcommand.
# Covers `git -C <dir>`, `git -c <key=val>`, `git --git-dir=<p>`, `git --work-tree=<p>`
# (including the space-separated forms). Without this, `git -C repo push --force`
# bypasses the per-subcommand patterns below.
GIT_PREFIX='git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|-c[[:space:]]+[^[:space:]]+|--git-dir[=[:space:]][^[:space:]]+|--work-tree[=[:space:]][^[:space:]]+))*[[:space:]]+'

# Block force-push. Match a real -f / --force *flag* (not a branch name that
# merely contains "-f", e.g. `git push origin feature-foo` must pass), the
# `+refspec` force form (`git push origin +main`), and the destructive
# --mirror / --delete / -d forms.
if echo "$CMD" | grep -qE "${GIT_PREFIX}push.*[[:space:]](-f([[:space:]]|$)|--force([[:space:]]|$)|--mirror|--delete|-d([[:space:]]|$)|\+[^[:space:]]+:?)"; then
    block "BLOCKED: force/mirror/delete push is not allowed. Use --force-with-lease only after explicit approval; never +refspec, --mirror, or --delete unattended."
fi

# Block remote ref deletion via the empty-source colon refspec form.
# `git push <remote> :<dst>` deletes <dst> on the remote — same destructive
# intent as `--delete` / `-d`, but neither flag is present so the regex
# above lets it through. The deletion token is a whitespace-delimited word
# that *starts* with `:`; `main:dev` (rename push) or `HEAD:main` keep a
# leading non-space, so they do not match.
if echo "$CMD" | grep -qE "${GIT_PREFIX}push[[:space:]].*[[:space:]]:[^[:space:]]+"; then
    block "BLOCKED: 'git push <remote> :<ref>' deletes a remote ref (same as --delete). Requires explicit approval; use 'git push --delete' after review if intentional."
fi

# Block branch / ref deletion that destroys history pointers.
# `-D` shortcut implies force-delete; any split combination of -d/--delete
# with -f/--force is the same intent (Git accepts -d -f / -f -d / --delete -f
# / -d --force / bundled short flags like -df, -fd).
if echo "$CMD" | grep -qE "${GIT_PREFIX}branch[[:space:]]"; then
    if echo "$CMD" | grep -qE "${GIT_PREFIX}branch.*[[:space:]]-D([[:space:]]|$)"; then
        block "BLOCKED: 'git branch -D' force-deletes a branch (possibly unmerged work). Use -d or explicit approval."
    fi
    if echo "$CMD" | grep -qE "${GIT_PREFIX}branch.*[[:space:]](--delete|-[a-z]*d[a-z]*)([[:space:]]|$)" \
       && echo "$CMD" | grep -qE "${GIT_PREFIX}branch.*[[:space:]](--force|-[a-z]*f[a-z]*)([[:space:]]|$)"; then
        block "BLOCKED: 'git branch' combining -d/--delete with -f/--force is force-delete (-D equivalent). Use plain -d or explicit approval."
    fi
fi
if echo "$CMD" | grep -qE "${GIT_PREFIX}update-ref[[:space:]].*-d"; then
    block "BLOCKED: 'git update-ref -d' deletes a ref directly. Requires explicit approval."
fi

# Block destructive reset (--hard discards working tree, --keep discards too).
if echo "$CMD" | grep -qE "${GIT_PREFIX}reset[[:space:]].*(--hard|--keep)"; then
    block "BLOCKED: git reset --hard/--keep can destroy uncommitted work. Use git stash or explicit approval."
fi

# Block destructive `git switch` variants. `git switch <branch>` itself is safe
# and Git refuses to switch when it would overwrite local changes; these flags
# bypass that guard or reset a branch pointer:
#   --discard-changes / -f / --force  : throw away local modifications
#   -C <name> / --force-create        : create/reset and switch (resets branch ref)
if echo "$CMD" | grep -qE "${GIT_PREFIX}switch[[:space:]].*(--discard-changes|--force-create|--force|-f|-C)([[:space:]]|$)"; then
    block "BLOCKED: 'git switch --discard-changes/--force/-f/-C/--force-create' can discard uncommitted work or reset a branch pointer. Commit/stash first, or use plain 'git switch <branch>' / 'git switch -c <new>'."
fi

# Block destructive `git clean`. The force flags (-f / --force, including
# combined short forms like -fd, -fdx, -ffdx) actually delete untracked files;
# -d/-x/-X widen the scope. `git clean -n` / `--dry-run` (no -f) stays allowed
# as a safe preview.
if echo "$CMD" | grep -qE "${GIT_PREFIX}clean([[:space:]]+|.*[[:space:]])(-[a-zA-Z]*f[a-zA-Z]*|--force)([[:space:]]|$)"; then
    block "BLOCKED: 'git clean -f' deletes untracked files (often irrecoverable). Use 'git clean -n' / '--dry-run' first; require explicit approval before a forceful clean."
fi

# Block obfuscated rm via $IFS word-splitting (rm${IFS}-rf${IFS}/ evades the
# whitespace-anchored shape detector below — there is no legitimate reason for
# $IFS to appear in an rm invocation).
if echo "$CMD" | grep -qE '(^|[^a-zA-Z0-9])rm[^a-zA-Z0-9]{0,3}\$\{?IFS'; then
    block "BLOCKED: rm using \$IFS word-splitting is an obfuscation pattern. Use an explicit, plainly-written command."
fi

# Inspect rm -rf operands one by one before the legacy denylist below. A safe
# /tmp operand must not allow a second dangerous operand on the same command.
is_rm_separator() {
    case "$1" in
        '&&'|'&&'|'||'|';'|'|') return 0 ;;
        *) return 1 ;;
    esac
}

strip_outer_quotes() {
    local value="$1"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    printf '%s' "$value"
}

is_safe_rm_operand() {
    local operand
    operand="$(strip_outer_quotes "$1")"

    case "$operand" in
        ''|'.'|'./'|'*'|./\*|\~|\~/*|/*/../*|*/../*|../*|*/..|..)
            return 1
            ;;
        *'$'*|*'`'*)
            return 1
            ;;
        /tmp/*|/var/tmp/*)
            [[ "$operand" != *'..'* ]]
            return
            ;;
        /*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

check_rm_rf_operands() {
    local -a words
    read -r -a words <<< "$CMD"

    local idx arg_idx token saw_recursive saw_force parsing_operands
    idx=0
    while ((idx < ${#words[@]})); do
        if [[ "${words[$idx]}" != "rm" ]]; then
            ((idx++))
            continue
        fi

        saw_recursive=0
        saw_force=0
        parsing_operands=0
        arg_idx=$((idx + 1))

        while ((arg_idx < ${#words[@]})); do
            token="${words[$arg_idx]}"
            if is_rm_separator "$token"; then
                break
            fi

            if [[ "$parsing_operands" -eq 0 && "$token" == "--" ]]; then
                parsing_operands=1
                ((arg_idx++))
                continue
            fi

            if [[ "$parsing_operands" -eq 0 && "$token" == --* ]]; then
                [[ "$token" == "--recursive" ]] && saw_recursive=1
                [[ "$token" == "--force" ]] && saw_force=1
                ((arg_idx++))
                continue
            fi

            if [[ "$parsing_operands" -eq 0 && "$token" == -* ]]; then
                [[ "$token" == *[rR]* ]] && saw_recursive=1
                [[ "$token" == *f* ]] && saw_force=1
                ((arg_idx++))
                continue
            fi

            parsing_operands=1
            if [[ "$saw_recursive" -eq 1 && "$saw_force" -eq 1 ]] && ! is_safe_rm_operand "$token"; then
                block "BLOCKED: recursive force-delete (rm -rf) includes an unsafe target. Absolute paths outside /tmp or /var/tmp, home, parent traversal, cwd, bare globs, variables, and command substitutions require explicit approval."
            fi
            ((arg_idx++))
        done
        idx=$arg_idx
    done
}

if echo "$CMD" | grep -qiE '(^|[^a-zA-Z0-9])rm[[:space:]]'; then
    check_rm_rf_operands
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

# Block DROP TABLE / DROP DATABASE without an explicit SQL approval comment.
# The marker must be a SQL line comment after the DROP statement, not just a
# magic token elsewhere in the shell command.
if echo "$CMD" | grep -iqE 'DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)'; then
    if ! echo "$CMD" | grep -iqE 'DROP[[:space:]]+(TABLE|DATABASE|SCHEMA).*([[:space:];]|\\n)--[[:space:]]*APPROVED_DESTRUCTIVE([^[:alnum:]_]|$)'; then
        block "BLOCKED: SQL DROP requires explicit approval. Add SQL comment '-- APPROVED_DESTRUCTIVE' after the DROP statement to proceed."
    fi
fi

exit 0

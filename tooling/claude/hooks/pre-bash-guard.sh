#!/usr/bin/env bash
# pre-bash-guard.sh — PreToolUse(Bash) hook
#
# Blocks known destructive commands before they run.
# Exit code 2 = block the command and show stderr to Claude.
# Exit code 0 = allow the command.
#
# SETUP in .claude/settings.json:
#   "hooks": {
#     "PreToolUse": [{
#       "matcher": "Bash",
#       "hooks": [{"type": "command", "command": ".claude/hooks/pre-bash-guard.sh"}]
#     }]
#   }
set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || true)

block() {
    echo "$1" >&2
    exit 2
}

# Block force-push to shared branches
if echo "$CMD" | grep -qE 'git push.*(--force|-f)'; then
    block "BLOCKED: force-push is not allowed. Use --force-with-lease only after explicit approval."
fi

# Block hard reset
if echo "$CMD" | grep -qE 'git reset --hard'; then
    block "BLOCKED: git reset --hard can destroy uncommitted work. Use git stash or explicit approval."
fi

# Block recursive delete of non-temp paths
if echo "$CMD" | grep -qE 'rm\s+-[a-z]*r[a-z]*\s+/(?!tmp|var/tmp)'; then
    block "BLOCKED: recursive rm on non-temp path requires explicit approval."
fi

# Block DROP TABLE / DROP DATABASE without explicit approval marker
if echo "$CMD" | grep -iqE 'DROP\s+(TABLE|DATABASE|SCHEMA)'; then
    if ! echo "$CMD" | grep -q 'APPROVED_DESTRUCTIVE'; then
        block "BLOCKED: SQL DROP requires explicit approval. Add comment '-- APPROVED_DESTRUCTIVE' to proceed."
    fi
fi

exit 0

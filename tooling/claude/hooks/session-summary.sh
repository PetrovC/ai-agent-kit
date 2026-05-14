#!/usr/bin/env bash
# session-summary.sh — PreCompact hook
#
# Before context is compacted, exports a human-readable summary of what
# files were modified in this session. Saved to .claude/session-log/.
#
# SETUP in .claude/settings.json:
#   "hooks": {
#     "PreCompact": [{
#       "matcher": "",
#       "hooks": [{"type": "command", "command": ".claude/hooks/session-summary.sh", "async": true}]
#     }]
#   }
set -euo pipefail

LOG_DIR=".claude/session-log"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
OUT="$LOG_DIR/pre-compact-$TIMESTAMP.md"

{
    echo "# Session snapshot — $TIMESTAMP"
    echo ""
    echo "## Git status"
    echo '```'
    git status --short 2>/dev/null || echo "(not a git repo)"
    echo '```'
    echo ""
    echo "## Modified files (staged + unstaged)"
    echo '```'
    git diff --name-only 2>/dev/null || true
    git diff --cached --name-only 2>/dev/null || true
    echo '```'
    echo ""
    echo "## Recent commits"
    echo '```'
    git log --oneline -5 2>/dev/null || echo "(no commits)"
    echo '```'
} > "$OUT"

echo "[hook] session snapshot saved to $OUT"
exit 0

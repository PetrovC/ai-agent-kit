#!/usr/bin/env bash
if [[ -n "${AAK_DEBUG:-}" && "${AAK_DEBUG}" != "0" && "${AAK_DEBUG}" != "false" ]]; then set -x; fi
# statusline.sh — PostToolUse hook (async, opt-in)
#
# Prints a one-line context-usage summary after each tool call, so you can
# see session cost signals before drift.
#
# Output format (stdout):
#   [aak] ctx: 4% (~8 400 tok) | 14 calls | cache: < 5 min
#
# Context % is estimated: cumulative session tokens ÷ AAK_CONTEXT_WINDOW (default 200 000).
# Token counts come from .claude/session-log/token-log.jsonl written by token-log.sh.
# If token-log.sh is not enabled, the statusline skips silently.
#
# OFF BY DEFAULT. To enable, add BOTH token-log.sh AND this script to
# PostToolUse in .claude/settings.json. See CLAUDE.md "## Statusline (opt-in)".
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
[[ -d "$ROOT" ]] || exit 0
cd "$ROOT" || exit 0

LOG_DIR=".claude/session-log"
LOG_FILE="$LOG_DIR/token-log.jsonl"

# If token-log.jsonl doesn't exist, nothing to show.
[[ -f "$LOG_FILE" ]] || exit 0

CTX_WINDOW="${AAK_CONTEXT_WINDOW:-200000}"
TODAY=$(date +"%Y-%m-%d")

# Sum approx_total_tokens for entries from today using awk (fast, no python needed)
read -r TOTAL_TOKENS CALL_COUNT <<< "$(awk -v today="$TODAY" '
  BEGIN { total=0; calls=0 }
  index($0, today) > 0 && /"approx_total_tokens"/ {
    match($0, /"approx_total_tokens":[[:space:]]*([0-9]+)/, arr)
    if (arr[1] != "") { total += arr[1]; calls++ }
  }
  END { print total, calls }
' "$LOG_FILE" 2>/dev/null || echo "0 0")"

TOTAL_TOKENS="${TOTAL_TOKENS:-0}"
CALL_COUNT="${CALL_COUNT:-0}"

# Context % (integer)
if [[ "$CTX_WINDOW" -gt 0 ]]; then
  CTX_PCT=$(( TOTAL_TOKENS * 100 / CTX_WINDOW ))
else
  CTX_PCT=0
fi

# Format token count with thousands separator (awk)
TOKENS_FMT=$(awk "BEGIN { printf \"%'d\", $TOTAL_TOKENS }" 2>/dev/null || echo "$TOTAL_TOKENS")

# Cache age: find most recent pre-compact snapshot
CACHE_LABEL="fresh (new session)"
COMPACT_FILE=$(ls -t "$LOG_DIR"/pre-compact-*.md 2>/dev/null | head -1 || true)
if [[ -n "$COMPACT_FILE" ]]; then
  NOW_EPOCH=$(date +%s)
  # Use stat for file mtime (portable: try GNU stat, fall back to date)
  FILE_EPOCH=$(stat -c %Y "$COMPACT_FILE" 2>/dev/null \
    || stat -f %m "$COMPACT_FILE" 2>/dev/null \
    || echo "$NOW_EPOCH")
  AGE_SEC=$(( NOW_EPOCH - FILE_EPOCH ))
  if [[ "$AGE_SEC" -lt 300 ]]; then
    CACHE_LABEL="fresh (< 5 min)"
  elif [[ "$AGE_SEC" -lt 3600 ]]; then
    AGE_MIN=$(( AGE_SEC / 60 ))
    CACHE_LABEL="< ${AGE_MIN}m"
  else
    AGE_HR=$(( AGE_SEC / 3600 ))
    AGE_MIN=$(( (AGE_SEC % 3600) / 60 ))
    CACHE_LABEL="${AGE_HR}h ${AGE_MIN}m"
  fi
fi

printf '[aak] ctx: %d%% (~%s tok) | %d calls | cache: %s\n' \
  "$CTX_PCT" "$TOKENS_FMT" "$CALL_COUNT" "$CACHE_LABEL"

exit 0

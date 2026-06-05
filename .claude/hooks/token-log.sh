#!/usr/bin/env bash
if [[ -n "${AAK_DEBUG:-}" && "${AAK_DEBUG}" != "0" && "${AAK_DEBUG}" != "false" ]]; then set -x; fi  # AAK_DEBUG: opt-in trace (#305)
# token-log.sh — PostToolUse hook
#
# Appends an approximate token-usage entry to .claude/session-log/token-log.jsonl
# each time a tool call completes. Token counts are estimated (chars / 4) —
# not billing-accurate. Useful for tracking session cost trends over time.
#
# OFF BY DEFAULT. To enable, add to .claude/settings.json under hooks.PostToolUse:
#   {
#     "matcher": "",
#     "hooks": [{
#       "type": "command",
#       "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/hooks/token-log.sh\"",
#       "async": true
#     }]
#   }
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
[[ -d "$ROOT" ]] || exit 0
cd "$ROOT" || exit 0

LOG_DIR=".claude/session-log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/token-log.jsonl"

# Read JSON payload from stdin; exit gracefully if no input.
PAYLOAD=""
if read -t 1 -r line 2>/dev/null; then
    PAYLOAD="$line"
    while IFS= read -t 0.1 -r extra 2>/dev/null; do
        PAYLOAD="$PAYLOAD$extra"
    done
fi

[[ -z "$PAYLOAD" ]] && exit 0

TOOL_NAME="unknown"
INPUT_CHARS=0
OUTPUT_CHARS=0

PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1 && python3 -c "import sys" >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1 && python -c "import sys" >/dev/null 2>&1; then
    PYTHON_CMD="python"
fi

if [[ -n "$PYTHON_CMD" ]]; then
    read -r TOOL_NAME INPUT_CHARS OUTPUT_CHARS <<< "$("$PYTHON_CMD" - "$PAYLOAD" <<'PYEOF'
import sys, json
try:
    d = json.loads(sys.argv[1]) if len(sys.argv) > 1 else json.load(sys.stdin)
    name = d.get("tool_name", "unknown")
    inp   = len(json.dumps(d.get("tool_input", {})))
    out   = len(json.dumps(d.get("tool_response", {})))
    print(name, inp, out)
except Exception:
    print("unknown", 0, 0)
PYEOF
)" 2>/dev/null || true
fi

# Fallback: estimate from raw payload length
if [[ "$INPUT_CHARS" -eq 0 && "$OUTPUT_CHARS" -eq 0 ]]; then
    INPUT_CHARS=${#PAYLOAD}
fi

# Approximate tokens at 4 chars / token
INPUT_TOKENS=$(( INPUT_CHARS / 4 ))
OUTPUT_TOKENS=$(( OUTPUT_CHARS / 4 ))
TOTAL_TOKENS=$(( INPUT_TOKENS + OUTPUT_TOKENS ))

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

printf '{"ts":"%s","tool":"%s","input_chars":%d,"output_chars":%d,"approx_input_tokens":%d,"approx_output_tokens":%d,"approx_total_tokens":%d}\n' \
    "$TIMESTAMP" "$TOOL_NAME" "$INPUT_CHARS" "$OUTPUT_CHARS" \
    "$INPUT_TOKENS" "$OUTPUT_TOKENS" "$TOTAL_TOKENS" \
    >> "$LOG_FILE"

exit 0

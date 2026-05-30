#!/usr/bin/env bash
# Best-effort agy hook integration for anonymized agent audit metadata.
# It exits zero when audit is disabled, unavailable, or unable to record so
# normal agy behavior is unchanged.

set +e

# Antigravity's hook env/field names are not publicly documented, so use a
# robust fallback: the stdin JSON cwd (read below) -> candidate env var -> pwd.
# Source: https://antigravity.google/docs/hooks (JS-rendered; names unconfirmed).
PROJECT_DIR="${ANTIGRAVITY_PROJECT_DIR:-$(pwd)}"
AUDIT_SCRIPT="$PROJECT_DIR/.ai-agent-kit/audit/record-event.sh"
CONFIG_PATH="${AAK_AUDIT_CONFIG:-$HOME/.ai-agent-kit/config.json}"

if [[ ! -x "$AUDIT_SCRIPT" && ! -f "$AUDIT_SCRIPT" ]]; then
    exit 0
fi
if [[ ! -f "$CONFIG_PATH" ]]; then
    exit 0
fi

stdin_payload="$(cat 2>/dev/null)"
if [[ -z "$stdin_payload" ]]; then
    stdin_payload="{}"
fi

if command -v python3 >/dev/null 2>&1 && python3 -c "pass" >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1 && python -c "pass" >/dev/null 2>&1; then
    PYTHON_BIN="python"
else
    exit 0
fi

event_json="$("$PYTHON_BIN" - "$stdin_payload" <<'PY'
import hashlib
import json
import os
import sys
import time

raw = sys.argv[1]
try:
    hook = json.loads(raw)
except Exception:
    hook = {}

hook_name = str(hook.get("hook_event_name") or hook.get("event") or "unknown")
tool_name = str(hook.get("tool_name") or hook.get("tool") or "unknown")
tool_lower = tool_name.lower()
if "bash" in tool_lower:
    tool_category = "shell"
elif tool_lower in {"edit", "write", "multiedit"}:
    tool_category = "file_write"
elif "read" in tool_lower or "grep" in tool_lower or "glob" in tool_lower:
    tool_category = "file_read"
elif "web" in tool_lower:
    tool_category = "web"
elif tool_name == "unknown":
    tool_category = "unknown"
else:
    tool_category = "other"

if hook_name == "PreCompact":
    event_type = "compact.observed"
elif tool_name != "unknown":
    event_type = "tool.observed"
else:
    event_type = "hook.observed"

# Prefer the stdin JSON cwd/session_id (cross-agent hook convention), then a
# candidate Antigravity env var, then the process cwd. Exact Antigravity names
# are unconfirmed: https://antigravity.google/docs/hooks
project_dir = hook.get("cwd") or os.environ.get("ANTIGRAVITY_PROJECT_DIR") or os.getcwd()
seed = hook.get("session_id") or os.environ.get("ANTIGRAVITY_SESSION_ID") or f"{os.environ.get('USER', 'user')}:{project_dir}"
run_hash = hashlib.sha256(seed.encode("utf-8")).hexdigest()[:16]
run_id = os.environ.get("AAK_AUDIT_RUN_ID") or f"run_agy_{time.strftime('%Y%m%d')}_{run_hash}"
project_hash = "hmac_sha256_" + hashlib.sha256(project_dir.encode("utf-8")).hexdigest()[:16]
sequence = int(time.time() * 1000)
event = {
    "schema_version": "0.1.0",
    "event_id": f"evt_agy_{sequence}",
    "audit_run_id": run_id,
    "sequence": sequence,
    "occurred_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "event_type": event_type,
    "actor_kind": "hook",
    "invocation_id": None,
    "payload": {
        "provider": "agy",
        "hook_name": hook_name,
        "tool_category": tool_category,
        "project_hash": project_hash,
    },
}
print(json.dumps(event, separators=(",", ":")))
PY
)"

if [[ -n "$event_json" ]]; then
    printf '%s\n' "$event_json" | "$AUDIT_SCRIPT" --config "$CONFIG_PATH" --source-root "$PROJECT_DIR" >/dev/null 2>&1
fi

exit 0

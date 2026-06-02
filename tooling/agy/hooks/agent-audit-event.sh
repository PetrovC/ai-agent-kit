#!/usr/bin/env bash
if [[ -n "${AAK_DEBUG:-}" && "${AAK_DEBUG}" != "0" && "${AAK_DEBUG}" != "false" ]]; then set -x; fi  # AAK_DEBUG: opt-in trace (#305)
# Best-effort agy hook integration for anonymized agent audit metadata.
# It exits zero when audit is disabled, unavailable, or unable to record so
# normal agy behavior is unchanged.
#
# Lifecycle wiring passes the event name as $1 (e.g. SessionStart / SessionEnd /
# BeforeAgent / AfterAgent) so the mapping does not depend on Antigravity's
# (publicly undocumented) stdin field names; tool hooks call it with no argument
# and fall back to stdin. On a run-end event it also auto-finalizes the run.

set +e

EVENT_ARG="${1:-}"
# Antigravity's hook env/field names are not publicly documented, so use a
# robust fallback: the stdin JSON cwd (read below) -> candidate env var -> pwd.
# Source: https://antigravity.google/docs/hooks (JS-rendered; names unconfirmed).
PROJECT_DIR="${ANTIGRAVITY_PROJECT_DIR:-$(pwd)}"
AUDIT_SCRIPT="$PROJECT_DIR/.ai-agent-kit/audit/record-event.sh"
FINALIZE_SCRIPT="$PROJECT_DIR/.ai-agent-kit/audit/finalize-run.sh"
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

audit_output="$("$PYTHON_BIN" - "$stdin_payload" "$EVENT_ARG" <<'PY'
import hashlib
import json
import os
import sys
import time

provider = "agy"

raw = sys.argv[1]
event_arg = sys.argv[2] if len(sys.argv) > 2 else ""
try:
    hook = json.loads(raw)
except Exception:
    hook = {}

hook_name = str(event_arg or hook.get("hook_event_name") or hook.get("event") or "unknown")
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

# Provider lifecycle hook -> audit event. "Stop" is the session-close event in
# Codex but fires every turn in Claude, so it only ends a run for Codex.
lifecycle = {
    "SessionStart": "run.started",
    "SessionEnd": "run.completed",
    "SubagentStart": "agent.invoked",
    "SubagentStop": "agent.completed",
    "BeforeAgent": "agent.invoked",
    "AfterAgent": "agent.completed",
}
event_type = lifecycle.get(hook_name)
if event_type is None:
    if provider == "codex" and hook_name == "Stop":
        event_type = "run.completed"
    elif hook_name in ("PreCompact", "PreCompress"):
        event_type = "compact.observed"
    elif tool_name == "Task":
        event_type = "agent.invoked"
    elif tool_name != "unknown":
        event_type = "tool.observed"
    else:
        event_type = "hook.observed"

if event_type in ("run.started", "run.completed"):
    actor_kind = "system"
elif event_type in ("agent.invoked", "agent.completed", "agent.selected"):
    actor_kind = "subagent"
else:
    actor_kind = "hook"

# Prefer the stdin JSON cwd/session_id (cross-agent hook convention), then a
# candidate Antigravity env var, then the process cwd. Exact Antigravity names
# are unconfirmed: https://antigravity.google/docs/hooks
project_dir = hook.get("cwd") or os.environ.get("ANTIGRAVITY_PROJECT_DIR") or os.getcwd()
seed = hook.get("session_id") or os.environ.get("ANTIGRAVITY_SESSION_ID") or f"{os.environ.get('USER', 'user')}:{project_dir}"
run_hash = hashlib.sha256(seed.encode("utf-8")).hexdigest()[:16]
run_id = os.environ.get("AAK_AUDIT_RUN_ID") or f"run_{provider}_{time.strftime('%Y%m%d')}_{run_hash}"
project_hash = "hmac_sha256_" + hashlib.sha256(project_dir.encode("utf-8")).hexdigest()[:16]
sequence = int(time.time() * 1000)

payload = {
    "provider": provider,
    "hook_name": hook_name,
    "tool_category": tool_category,
    "project_hash": project_hash,
}
if event_type == "run.completed":
    payload["status"] = "completed"

event = {
    "schema_version": "0.1.0",
    "event_id": f"evt_{provider}_{sequence}",
    "audit_run_id": run_id,
    "sequence": sequence,
    "occurred_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "event_type": event_type,
    "actor_kind": actor_kind,
    "invocation_id": None,
    "payload": payload,
}
print(run_id)
print(event_type)
print(json.dumps(event, separators=(",", ":")))
PY
)"

run_id=""
event_type=""
event_json=""
{ read -r run_id; read -r event_type; read -r event_json; } <<EOF
$audit_output
EOF
# Strip a trailing CR so Windows python's \r\n stdout does not break the
# run.completed comparison below (and keeps the recorded JSON clean).
run_id="${run_id%$'\r'}"
event_type="${event_type%$'\r'}"
event_json="${event_json%$'\r'}"

if [[ -n "$event_json" ]]; then
    printf '%s\n' "$event_json" | "$AUDIT_SCRIPT" --config "$CONFIG_PATH" --source-root "$PROJECT_DIR" >/dev/null 2>&1
fi

# On a run-end event, auto-finalize this run. Best-effort and synchronous so it
# completes before the session exits; it no-ops without a configured central
# audit clone (finalize-run rejects a non-audit branch / missing repo).
if [[ "$event_type" == "run.completed" && -n "$run_id" && -f "$FINALIZE_SCRIPT" ]]; then
    "$FINALIZE_SCRIPT" --config "$CONFIG_PATH" --source-root "$PROJECT_DIR" --run-id "$run_id" >/dev/null 2>&1
fi

exit 0

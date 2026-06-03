#!/usr/bin/env bash
if [[ -n "${AAK_DEBUG:-}" && "${AAK_DEBUG}" != "0" && "${AAK_DEBUG}" != "false" ]]; then set -x; fi  # AAK_DEBUG: opt-in trace (#305)
# Log Codex PermissionRequest events without echoing raw commands, paths, or
# prompts. The hook is observability only and must never block the request flow.

set +e

stdin_payload="$(cat 2>/dev/null)"
if [[ -z "$stdin_payload" ]]; then
    stdin_payload="{}"
fi

if command -v python3 >/dev/null 2>&1 && python3 -c "pass" >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1 && python -c "pass" >/dev/null 2>&1; then
    PYTHON_BIN="python"
else
    printf 'ai-agent-kit PermissionRequest tool=unknown permission=unknown reason_hash=unavailable reason_chars=0\n' >&2
    exit 0
fi

"$PYTHON_BIN" - "$stdin_payload" <<'PY' >&2
import hashlib
import json
import re
import sys

try:
    payload = json.loads(sys.argv[1])
except Exception:
    payload = {}

tool = str(payload.get("tool_name") or payload.get("tool") or payload.get("name") or "unknown")
tool = re.sub(r"[^A-Za-z0-9_.:-]", "_", tool)[:80] or "unknown"

tool_input = payload.get("tool_input")
if not isinstance(tool_input, dict):
    tool_input = {}

permission = (
    payload.get("permission")
    or payload.get("permission_kind")
    or payload.get("requested_permission")
    or payload.get("sandbox_permissions")
    or tool_input.get("sandbox_permissions")
    or tool_input.get("permission")
    or "unknown"
)
permission = re.sub(r"[^A-Za-z0-9_.:-]", "_", str(permission))[:80] or "unknown"

reason = (
    payload.get("reason")
    or payload.get("justification")
    or payload.get("message")
    or payload.get("description")
    or tool_input.get("justification")
    or tool_input.get("reason")
    or ""
)
reason = str(reason)
reason_hash = hashlib.sha256(reason.encode("utf-8")).hexdigest()[:16] if reason else "none"
print(
    "ai-agent-kit PermissionRequest "
    f"tool={tool} permission={permission} reason_hash=sha256:{reason_hash} reason_chars={len(reason)}"
)
PY

exit 0

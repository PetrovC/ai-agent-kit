#!/usr/bin/env bash
if [[ -n "${AAK_DEBUG:-}" && "${AAK_DEBUG}" != "0" && "${AAK_DEBUG}" != "false" ]]; then set -x; fi  # AAK_DEBUG: opt-in trace (#305)
# Print a compact Codex session banner. Fail open so hook issues never block a
# thread start.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PROJECT_DIR="${CODEX_PROJECT_DIR:-$(pwd)}"
if [[ ! -f "$PROJECT_DIR/VERSION" && -f "$SCRIPT_DIR/../../VERSION" ]]; then
    PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." >/dev/null 2>&1 && pwd)"
fi
VERSION_FILE="$PROJECT_DIR/VERSION"
if [[ -f "$VERSION_FILE" ]]; then
    KIT_VERSION="$(head -n 1 "$VERSION_FILE" 2>/dev/null | tr -d '\r\n')"
else
    KIT_VERSION="unknown"
fi

stdin_payload="$(cat 2>/dev/null)"
if [[ -z "$stdin_payload" ]]; then
    stdin_payload="{}"
fi

PROFILE="${CODEX_ACTIVE_PROFILE:-${CODEX_PROFILE:-}}"
START_SOURCE="unknown"

if command -v python3 >/dev/null 2>&1 && python3 -c "pass" >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1 && python -c "pass" >/dev/null 2>&1; then
    PYTHON_BIN="python"
else
    PYTHON_BIN=""
fi

if [[ -n "$PYTHON_BIN" ]]; then
    parsed="$("$PYTHON_BIN" - "$stdin_payload" <<'PY'
import json
import sys

try:
    payload = json.loads(sys.argv[1])
except Exception:
    payload = {}

profile = (
    payload.get("profile")
    or payload.get("active_profile")
    or payload.get("config_profile")
    or payload.get("profile_name")
    or ""
)
source = payload.get("source") or payload.get("start_source") or payload.get("matcher") or payload.get("event") or ""
print(str(profile).replace("\n", " ")[:80])
print(str(source).replace("\n", " ")[:80])
PY
)"
    payload_profile="$(printf '%s\n' "$parsed" | sed -n '1p' | tr -d '\r')"
    payload_source="$(printf '%s\n' "$parsed" | sed -n '2p' | tr -d '\r')"
    [[ -n "$PROFILE" ]] || PROFILE="$payload_profile"
    [[ -n "$payload_source" ]] && START_SOURCE="$payload_source"
fi

[[ -n "$PROFILE" ]] || PROFILE="unknown"
PROFILE="$(printf '%s' "$PROFILE" | tr '\r\n\t' '   ' | cut -c 1-80)"
START_SOURCE="$(printf '%s' "$START_SOURCE" | tr '\r\n\t' '   ' | cut -c 1-80)"
printf 'ai-agent-kit %s | Codex profile: %s | SessionStart: %s\n' "$KIT_VERSION" "$PROFILE" "$START_SOURCE" >&2
exit 0

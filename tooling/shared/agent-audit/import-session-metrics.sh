#!/usr/bin/env bash
if [[ -n "${AAK_DEBUG:-}" && "${AAK_DEBUG}" != "0" && "${AAK_DEBUG}" != "false" ]]; then set -x; fi  # AAK_DEBUG: opt-in trace (#305)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON:-}"
if [[ -z "$PYTHON_BIN" ]]; then
    if command -v python3 >/dev/null 2>&1 && python3 -c "pass" >/dev/null 2>&1; then
        PYTHON_BIN="python3"
    elif command -v python >/dev/null 2>&1 && python -c "pass" >/dev/null 2>&1; then
        PYTHON_BIN="python"
    else
        echo "Error: python3 or python is required for agent audit runtime" >&2
        exit 127
    fi
fi

exec "$PYTHON_BIN" "$SCRIPT_DIR/audit_runtime.py" import-session-metrics "$@"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON:-}"
if [[ -z "$PYTHON_BIN" ]]; then
    # Test execution, not just presence: on Windows, `python3`/`python` can be
    # the Microsoft Store app-execution alias — on PATH but exits non-zero
    # without running. Picking it would silently break finalize/push.
    if command -v python3 >/dev/null 2>&1 && python3 -c "pass" >/dev/null 2>&1; then
        PYTHON_BIN="python3"
    elif command -v python >/dev/null 2>&1 && python -c "pass" >/dev/null 2>&1; then
        PYTHON_BIN="python"
    else
        echo "Error: a working python3 or python is required for agent audit runtime" >&2
        exit 127
    fi
fi

exec "$PYTHON_BIN" "$SCRIPT_DIR/audit_runtime.py" finalize-run "$@"

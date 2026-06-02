#!/usr/bin/env bats
#
# AAK_DEBUG opt-in trace (#305): setting AAK_DEBUG turns on `set -x` tracing in
# the lifecycle scripts and hooks WITHOUT changing default output or exit codes.
# "0"/"false" are treated as off (matching the existing AAK_DEBUG convention).

load 'bats_helper'

setup() {
    aak_setup
    # validate.sh against the shipped filled example is a deterministic,
    # read-only run that exits 0 — a stable probe for the trace toggle.
    EXAMPLE="$KIT_ROOT/examples/filled-project"
}

# Count `set -x` trace lines (they start with "+ ") on stderr only.
trace_lines() {
    local dbg="$1"
    if [[ -n "$dbg" ]]; then
        AAK_DEBUG="$dbg" bash "$KIT_ROOT/scripts/validate.sh" --target "$EXAMPLE" 2>/tmp/aak_dbg_err 1>/dev/null
    else
        bash "$KIT_ROOT/scripts/validate.sh" --target "$EXAMPLE" 2>/tmp/aak_dbg_err 1>/dev/null
    fi
    grep -c '^+ ' /tmp/aak_dbg_err || true
}

@test "default run emits no trace and exits 0" {
    run bash "$KIT_ROOT/scripts/validate.sh" --target "$EXAMPLE"
    assert_success
    [ "$(trace_lines '')" -eq 0 ]
}

@test "AAK_DEBUG=1 emits a trace and keeps the same exit code" {
    run env AAK_DEBUG=1 bash "$KIT_ROOT/scripts/validate.sh" --target "$EXAMPLE"
    assert_success                       # exit code unchanged from the default run
    [ "$(trace_lines '1')" -gt 0 ]       # trace present
}

@test "AAK_DEBUG=0 is treated as off (no trace)" {
    [ "$(trace_lines '0')" -eq 0 ]
}

@test "AAK_DEBUG=false is treated as off (no trace)" {
    [ "$(trace_lines 'false')" -eq 0 ]
}

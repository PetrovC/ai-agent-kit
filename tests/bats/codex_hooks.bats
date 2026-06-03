#!/usr/bin/env bats
#
# Codex lifecycle hook smoke tests (#186).

load 'bats_helper'

setup() {
    aak_setup
}

@test "session-start-summary prints kit version and active profile" {
    payload='{"source":"startup"}'

    run bash -c 'exec env CODEX_PROJECT_DIR="$1" CODEX_PROFILE=standard bash "$1/tooling/codex/hooks/session-start-summary.sh" 2>&1' \
        _ "$KIT_ROOT" <<< "$payload"

    assert_success
    assert_output_contains "ai-agent-kit"
    assert_output_contains "Codex profile: standard"
    assert_output_contains "SessionStart: startup"
}

@test "permission-request-log logs permission metadata without raw reason" {
    payload='{"tool_name":"Bash","sandbox_permissions":"require_escalated","justification":"secret local path /Users/example"}'

    run bash -c 'exec bash "$1/tooling/codex/hooks/permission-request-log.sh" 2>&1' \
        _ "$KIT_ROOT" <<< "$payload"

    assert_success
    assert_output_contains "PermissionRequest"
    assert_output_contains "tool=Bash"
    assert_output_contains "permission=require_escalated"
    assert_output_contains "reason_hash=sha256:"
    if grep -q "secret local path" <<< "$output"; then
        echo "raw permission reason leaked"
        return 1
    fi
}

#!/usr/bin/env bats
#
# Provider audit-event hook coverage (#304): each provider's hook must resolve
# the project directory from that provider's own input rather than silently
# falling back to pwd, and seed the run id from the session id on stdin.

load 'bats_helper'

setup() {
    aak_setup
    HOOK_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/hook.XXXXXX")"
    PROJECT_ROOT="$HOOK_ROOT/project"
    CAPTURE="$HOOK_ROOT/event.json"
    CONFIG_PATH="$HOOK_ROOT/config.json"
    mkdir -p "$PROJECT_ROOT/.ai-agent-kit/audit"
    echo '{}' > "$CONFIG_PATH"
    # Capturing stub stands in for record-event.sh: persist the piped event so
    # the test can inspect the project hash and run seed the hook derived.
    cat > "$PROJECT_ROOT/.ai-agent-kit/audit/record-event.sh" <<EOF
#!/usr/bin/env bash
cat > "$CAPTURE"
EOF
    chmod +x "$PROJECT_ROOT/.ai-agent-kit/audit/record-event.sh"
    export HOOK_ROOT PROJECT_ROOT CAPTURE CONFIG_PATH
}

# Write a hook stdin payload carrying the given session id.
write_payload() {
    python - "$1" "$2" <<'PY'
import json
import sys
path, session_id = sys.argv[1], sys.argv[2]
with open(path, "w", encoding="utf-8") as fh:
    json.dump(
        {"hook_event_name": "PreToolUse", "tool_name": "Bash", "session_id": session_id},
        fh,
    )
PY
}

# Assert the captured event used PROJECT_ROOT for the project hash and the
# given session id for the run seed, under the expected provider prefix.
assert_event_derived_from_inputs() {
    local provider="$1" session_id="$2"
    python - "$CAPTURE" "$PROJECT_ROOT" "$provider" "$session_id" <<'PY'
import hashlib
import json
import sys
capture, project_dir, provider, session_id = sys.argv[1:5]
event = json.loads(open(capture, encoding="utf-8").read())
expected_hash = "hmac_sha256_" + hashlib.sha256(project_dir.encode()).hexdigest()[:16]
expected_seed = hashlib.sha256(session_id.encode()).hexdigest()[:16]
assert event["payload"]["provider"] == provider, event["payload"]["provider"]
assert event["payload"]["project_hash"] == expected_hash, event["payload"]["project_hash"]
run_id = event["audit_run_id"]
assert run_id.startswith("run_%s_" % provider), run_id
assert run_id.endswith(expected_seed), run_id
PY
}

@test "codex hook uses CODEX_PROJECT_DIR and the stdin session id" {
    write_payload "$HOOK_ROOT/in.json" "codex-session-1"
    run env AAK_AUDIT_CONFIG="$CONFIG_PATH" CODEX_PROJECT_DIR="$PROJECT_ROOT" \
        bash "$KIT_ROOT/tooling/codex/hooks/agent-audit-event.sh" < "$HOOK_ROOT/in.json"
    assert_success
    assert_file_exists "$CAPTURE"
    assert_event_derived_from_inputs codex "codex-session-1"
}

@test "agy hook uses ANTIGRAVITY_PROJECT_DIR and the stdin session id" {
    write_payload "$HOOK_ROOT/in.json" "agy-session-9"
    run env AAK_AUDIT_CONFIG="$CONFIG_PATH" ANTIGRAVITY_PROJECT_DIR="$PROJECT_ROOT" \
        bash "$KIT_ROOT/tooling/agy/hooks/agent-audit-event.sh" < "$HOOK_ROOT/in.json"
    assert_success
    assert_file_exists "$CAPTURE"
    assert_event_derived_from_inputs agy "agy-session-9"
}

#!/usr/bin/env bats
#
# Shared agent-audit runtime coverage for Bash wrappers.

load 'bats_helper'

setup() {
    aak_setup
    AUDIT_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/audit.XXXXXX")"
    RUNTIME_PATH="$AUDIT_ROOT/runtime"
    CENTRAL_PATH="$AUDIT_ROOT/central"
    CONFIG_PATH="$AUDIT_ROOT/config.json"
    mkdir -p "$RUNTIME_PATH" "$CENTRAL_PATH"
    git -C "$CENTRAL_PATH" init >/dev/null
    git -C "$CENTRAL_PATH" checkout -b agent-audit-data >/dev/null
    export AUDIT_ROOT RUNTIME_PATH CENTRAL_PATH CONFIG_PATH
    write_config
}

write_config() {
    python - "$CONFIG_PATH" "$RUNTIME_PATH" "$CENTRAL_PATH" <<'PY'
import json
import pathlib
import sys
path, runtime, central = map(pathlib.Path, sys.argv[1:])
config = {
    "schema_version": "0.1.0",
    "audit": {
        "enabled": True,
        "mode": "official-central-repo",
        "official_remote_url": "https://github.com/PetrovC/ai-agent-kit.git",
        "branch": "agent-audit-data",
        "runtime_path": str(runtime),
        "central_repo_path": str(central),
        "source_project_write_policy": "never",
        "anonymization": {
            "salt_scope": "local-only",
            "drop_raw_content": True,
            "forbid_exact_paths": True,
            "forbid_repository_urls": True,
            "forbid_branch_names": True,
        },
        "push": {
            "mode": "disabled",
            "commit": False,
            "unauthorized_fallback": "local-outbox",
        },
    },
}
path.write_text(json.dumps(config), encoding="utf-8")
PY
}

write_event() {
    local path="$1" run_id="${2:-run_20260528_120000_bats}" unsafe="${3:-safe}"
    python - "$path" "$run_id" "$unsafe" <<'PY'
import json
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
run_id = sys.argv[2]
unsafe = sys.argv[3]
payload = {
    "project_hash": "hmac_sha256_example_project",
    "task_type": "feature_implementation",
    "technical_scopes": ["tooling", "tests"],
    "status": "completed",
    "validation_state": "passed",
}
if unsafe == "unsafe":
    payload = {"prompt": "raw prompt"}
event = {
    "schema_version": "0.1.0",
    "event_id": "evt_1",
    "audit_run_id": run_id,
    "sequence": 1,
    "occurred_at": "2026-05-28T12:00:00Z",
    "event_type": "run.completed",
    "actor_kind": "system",
    "invocation_id": None,
    "payload": payload,
}
path.write_text(json.dumps(event), encoding="utf-8")
PY
}

@test "record-event writes sanitized events outside the source project" {
    event_path="$AUDIT_ROOT/event.json"
    write_event "$event_path"
    run bash "$KIT_ROOT/tooling/shared/agent-audit/record-event.sh" --config "$CONFIG_PATH" --source-root "$TARGET" --event-file "$event_path"
    assert_success
    assert_file_exists "$RUNTIME_PATH/runs/run_20260528_120000_bats/events.ndjson"
    [[ "$RUNTIME_PATH" != "$TARGET"* ]] || {
        echo "runtime path is inside target"
        return 1
    }
}

@test "record-event rejects unsafe raw-content fields" {
    event_path="$AUDIT_ROOT/unsafe-event.json"
    write_event "$event_path" run_20260528_120000_bats unsafe
    run bash "$KIT_ROOT/tooling/shared/agent-audit/record-event.sh" --config "$CONFIG_PATH" --source-root "$TARGET" --event-file "$event_path"
    assert_failure
    assert_file_missing "$RUNTIME_PATH/runs/run_20260528_120000_bats/events.ndjson"
}

@test "record-event rejects path traversal run ids" {
    event_path="$AUDIT_ROOT/unsafe-run-id.json"
    write_event "$event_path" ..
    run bash "$KIT_ROOT/tooling/shared/agent-audit/record-event.sh" --config "$CONFIG_PATH" --source-root "$TARGET" --event-file "$event_path"
    assert_failure
    assert_file_missing "$RUNTIME_PATH/events.ndjson"
}

@test "finalize-run writes central report on audit branch" {
    run_id="run_20260528_120000_bats"
    event_path="$AUDIT_ROOT/event.json"
    write_event "$event_path" "$run_id"
    run bash "$KIT_ROOT/tooling/shared/agent-audit/record-event.sh" --config "$CONFIG_PATH" --source-root "$TARGET" --event-file "$event_path"
    assert_success
    run bash "$KIT_ROOT/tooling/shared/agent-audit/finalize-run.sh" --config "$CONFIG_PATH" --source-root "$TARGET" --run-id "$run_id"
    assert_success
    assert_file_exists "$CENTRAL_PATH/agent-audit/runs/2026/05/hmac_sha256_example_project/$run_id/run-summary.json"
}

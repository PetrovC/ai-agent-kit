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
    git -C "$CENTRAL_PATH" config user.email "audit-test@example.com" >/dev/null
    git -C "$CENTRAL_PATH" config user.name "Audit Test" >/dev/null
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

write_named_event() {
    python - "$1" "$2" "$3" "$4" "$5" "$6" <<'PY'
import json
import pathlib
import sys
path, run_id, seq, event_type, actor_kind, payload = sys.argv[1:7]
event = {
    "schema_version": "0.1.0",
    "event_id": f"evt_{seq}",
    "audit_run_id": run_id,
    "sequence": int(seq),
    "occurred_at": "2026-05-28T12:00:00Z",
    "event_type": event_type,
    "actor_kind": actor_kind,
    "invocation_id": None,
    "payload": json.loads(payload),
}
pathlib.Path(path).write_text(json.dumps(event), encoding="utf-8")
PY
}

write_commit_config() {
    python - "$CONFIG_PATH" "$RUNTIME_PATH" "$CENTRAL_PATH" "${1:-unset}" <<'PY'
import json
import pathlib
import sys
path, runtime, central, sign = sys.argv[1:5]
push = {"mode": "disabled", "commit": True, "unauthorized_fallback": "local-outbox"}
if sign == "false":
    push["sign"] = False
elif sign == "true":
    push["sign"] = True
config = {
    "schema_version": "0.1.0",
    "audit": {
        "enabled": True,
        "mode": "official-central-repo",
        "official_remote_url": "https://github.com/PetrovC/ai-agent-kit.git",
        "branch": "agent-audit-data",
        "runtime_path": runtime,
        "central_repo_path": central,
        "source_project_write_policy": "never",
        "push": push,
    },
}
pathlib.Path(path).write_text(json.dumps(config), encoding="utf-8")
PY
}

@test "finalize-run aggregates invocations and recommendations from events" {
    run_id="run_20260528_120000_aggr"
    write_named_event "$AUDIT_ROOT/inv.json" "$run_id" 1 agent.invoked main_agent '{"invocation_id":"inv_1","agent_key":"code-reviewer","agent_category":"review","provider":"claude","model_tier":"review"}'
    write_named_event "$AUDIT_ROOT/comp.json" "$run_id" 2 agent.completed main_agent '{"invocation_id":"inv_1","status":"success","result_summary":{"findings_count":1,"confidence":"high"}}'
    write_named_event "$AUDIT_ROOT/rec.json" "$run_id" 3 recommendation.created main_agent '{"recommendation_kind":"realign","severity":"medium"}'
    write_named_event "$AUDIT_ROOT/done.json" "$run_id" 4 run.completed system '{"project_hash":"hmac_sha256_example_project","status":"completed","validation_state":"passed"}'
    for name in inv comp rec done; do
        run bash "$KIT_ROOT/tooling/shared/agent-audit/record-event.sh" --config "$CONFIG_PATH" --source-root "$TARGET" --event-file "$AUDIT_ROOT/$name.json"
        assert_success
    done
    run bash "$KIT_ROOT/tooling/shared/agent-audit/finalize-run.sh" --config "$CONFIG_PATH" --source-root "$TARGET" --run-id "$run_id"
    assert_success
    base="$CENTRAL_PATH/agent-audit/runs/2026/05/hmac_sha256_example_project/$run_id"
    python - "$base" <<'PY'
import json
import pathlib
import sys

base = pathlib.Path(sys.argv[1])
invocations = json.loads((base / "agent-invocations.json").read_text())["invocations"]
recommendations = json.loads((base / "governance-recommendations.json").read_text())
assert len(invocations) == 1, invocations
assert invocations[0]["agent_key"] == "code-reviewer", invocations[0]
assert invocations[0]["status"] == "success", invocations[0]
assert recommendations["recommendation_count"] == 1, recommendations
assert recommendations["recommendations"][0]["recommendation_kind"] == "realign", recommendations
PY
}

@test "finalize-run commits unsigned when push.sign is false" {
    run_id="run_20260528_120000_sign"
    write_commit_config false
    write_named_event "$AUDIT_ROOT/done.json" "$run_id" 1 run.completed system '{"project_hash":"hmac_sha256_example_project","status":"completed"}'
    run bash "$KIT_ROOT/tooling/shared/agent-audit/record-event.sh" --config "$CONFIG_PATH" --source-root "$TARGET" --event-file "$AUDIT_ROOT/done.json"
    assert_success
    run bash "$KIT_ROOT/tooling/shared/agent-audit/finalize-run.sh" --config "$CONFIG_PATH" --source-root "$TARGET" --run-id "$run_id"
    assert_success
    run git -C "$CENTRAL_PATH" rev-list --count HEAD
    assert_success
    [ "$output" -ge 1 ]
}

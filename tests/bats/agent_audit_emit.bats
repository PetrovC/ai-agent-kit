#!/usr/bin/env bats
#
# Governance event emission coverage (#311): the emit-event wrapper must feed
# the richer governance event types into the runtime, and a scripted session
# must produce run.*, an agent.invoked/agent.completed pair, and a
# report.evaluated/recommendation.created event that survive finalization.

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
        "push": {"mode": "disabled", "commit": False},
    },
}
path.write_text(json.dumps(config), encoding="utf-8")
PY
}

emit() {
    run bash "$KIT_ROOT/tooling/shared/agent-audit/emit-event.sh" \
        --config "$CONFIG_PATH" --source-root "$TARGET" "$@"
}

@test "emit-event requires a run id" {
    run env -u AAK_AUDIT_RUN_ID bash "$KIT_ROOT/tooling/shared/agent-audit/emit-event.sh" \
        --config "$CONFIG_PATH" --source-root "$TARGET" --type run.started --actor system
    assert_failure
}

@test "emit-event rejects an event type outside the controlled set" {
    AAK_AUDIT_RUN_ID="run_emit_bad" emit --type tool.exfiltrate --actor system
    assert_failure
}

@test "a scripted governance loop survives finalization" {
    export AAK_AUDIT_RUN_ID="run_emit_loop"
    emit --type run.started --actor system; assert_success
    emit --type task.classified --actor main_agent --payload '{"task_type":"security_review","risk_level":"high"}'; assert_success
    emit --type agent.selected --actor main_agent --invocation-id inv_1 --payload '{"agent_key":"security-reviewer","agent_category":"security","model_tier":"review"}'; assert_success
    emit --type agent.invoked --actor subagent --invocation-id inv_1; assert_success
    emit --type agent.completed --actor subagent --invocation-id inv_1 --payload '{"status":"success","result_summary":{"findings_count":2,"confidence":"high"}}'; assert_success
    emit --type report.evaluated --actor main_agent --payload '{"quality_category":"accepted"}'; assert_success
    emit --type recommendation.created --actor main_agent --payload '{"recommendation_kind":"realign","severity":"medium"}'; assert_success
    emit --type run.completed --actor system --payload '{"project_hash":"hmac_sha256_example_project","task_type":"security_review","risk_level":"high","status":"completed","validation_state":"passed","observed_model_tier":"review"}'; assert_success

    run bash "$KIT_ROOT/tooling/shared/agent-audit/finalize-run.sh" \
        --config "$CONFIG_PATH" --source-root "$TARGET" --run-id "run_emit_loop"
    assert_success

    base="$CENTRAL_PATH/agent-audit/runs/2026/05/hmac_sha256_example_project/run_emit_loop"
    python - "$base" <<'PY'
import json
import pathlib
import sys
base = pathlib.Path(sys.argv[1])
events = [
    json.loads(line)
    for line in (base / "governance-events.ndjson").read_text().splitlines()
    if line.strip()
]
types = {e["event_type"] for e in events}
for need in (
    "run.started", "run.completed", "task.classified",
    "agent.invoked", "agent.completed", "report.evaluated",
    "recommendation.created",
):
    assert need in types, f"missing {need}: {sorted(types)}"
invocations = json.loads((base / "agent-invocations.json").read_text())["invocations"]
assert len(invocations) == 1, invocations
assert invocations[0]["invocation_id"] == "inv_1", invocations
assert invocations[0]["status"] == "success", invocations
recs = json.loads((base / "governance-recommendations.json").read_text())
assert any(r.get("recommendation_kind") == "realign" for r in recs["recommendations"]), recs
PY
}

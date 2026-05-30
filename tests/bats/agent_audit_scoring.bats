#!/usr/bin/env bats
#
# Governance scoring coverage (#310): finalize-run must compute the quality
# score, noise score, and model-fit detection deterministically from the
# event stream, matching the worked examples in AGENT_AUDIT_GOVERNANCE.md.

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

# Config carries a fixed report-token target so the verbosity component is
# deterministic across machines.
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
        "governance": {"target_report_tokens": 1200},
        "push": {"mode": "disabled", "commit": False},
    },
}
path.write_text(json.dumps(config), encoding="utf-8")
PY
}

# Build a run's event files from a compact [seq, type, actor, payload] array
# read on stdin, then record each through the bash wrapper.
seed_run() {
    local run_id="$1" dir="$AUDIT_ROOT/$run_id"
    mkdir -p "$dir"
    cat > "$dir/spec.json"
    python - "$dir" "$run_id" <<'PY'
import json, pathlib, sys
d = pathlib.Path(sys.argv[1])
run_id = sys.argv[2]
spec = json.loads((d / "spec.json").read_text())
for seq, etype, actor, payload in spec:
    event = {
        "schema_version": "0.1.0",
        "event_id": f"evt_{seq}",
        "audit_run_id": run_id,
        "sequence": seq,
        "occurred_at": "2026-05-28T12:00:00Z",
        "event_type": etype,
        "actor_kind": actor,
        "payload": payload,
    }
    (d / f"ev_{seq:03d}.json").write_text(json.dumps(event), encoding="utf-8")
PY
    local f
    for f in "$dir"/ev_*.json; do
        run bash "$KIT_ROOT/tooling/shared/agent-audit/record-event.sh" \
            --config "$CONFIG_PATH" --source-root "$TARGET" --event-file "$f"
        assert_success
    done
    run bash "$KIT_ROOT/tooling/shared/agent-audit/finalize-run.sh" \
        --config "$CONFIG_PATH" --source-root "$TARGET" --run-id "$run_id"
    assert_success
}

# Assert report-quality.json / governance-recommendations.json fields. The
# remaining args are key=value pairs checked against the merged report; keys
# prefixed with rec_ check the recommendations summary.
run_dir() {
    echo "$CENTRAL_PATH/agent-audit/runs/2026/05/hmac_sha256_example_project/$1"
}

@test "good run scores accepted, low noise, appropriate model fit" {
    seed_run "run_good" <<'JSON'
[[1,"run.completed","system",{"project_hash":"hmac_sha256_example_project","task_type":"feature_implementation","risk_level":"low","complexity":"small","answered_assigned_task":true,"has_sanitized_evidence":true,"validation_state":"passed","observed_model_tier":"standard","report_tokens":800,"status":"completed"}]]
JSON
    python - "$(run_dir run_good)" <<'PY'
import json, pathlib, sys
base = pathlib.Path(sys.argv[1])
rq = json.loads((base / "report-quality.json").read_text())
recs = json.loads((base / "governance-recommendations.json").read_text())
assert rq["quality_score"] == 10.0, rq
assert rq["quality_category"] == "accepted", rq
assert rq["noise_level"] == "low", rq
assert rq["model_fit"] == "appropriate", rq
assert recs["recommendation_count"] == 0, recs
PY
}

@test "high-noise run reproduces the documented 9.1 example" {
    seed_run "run_noisy" <<'JSON'
[[1,"run.completed","system",{"project_hash":"hmac_sha256_example_project","task_type":"feature_implementation","risk_level":"low","complexity":"small","answered_assigned_task":true,"has_sanitized_evidence":true,"observed_model_tier":"standard","repeated_read_count":4,"large_output_event_count":2,"truncated_output_count":1,"expected_subagent_count":2,"report_tokens":3600,"scope_narrowing_count":1,"rework_detected":true,"status":"completed"}],
 [2,"agent.invoked","subagent",{"invocation_id":"inv_1"}],
 [3,"agent.invoked","subagent",{"invocation_id":"inv_2"}],
 [4,"agent.invoked","subagent",{"invocation_id":"inv_3"}],
 [5,"agent.invoked","subagent",{"invocation_id":"inv_4"}],
 [6,"agent.invoked","subagent",{"invocation_id":"inv_5"}],
 [7,"retry.requested","main_agent",{}],
 [8,"retry.requested","main_agent",{}]]
JSON
    python - "$(run_dir run_noisy)" <<'PY'
import json, pathlib, sys
base = pathlib.Path(sys.argv[1])
rq = json.loads((base / "report-quality.json").read_text())
recs = json.loads((base / "governance-recommendations.json").read_text())
assert rq["noise_score"] == 9.1, rq
assert rq["noise_level"] == "high", rq
assert any(r["recommendation_id"] == "rec_noise_high" for r in recs["recommendations"]), recs
PY
}

@test "underpowered model on high-risk review opens an issue candidate" {
    seed_run "run_under" <<'JSON'
[[1,"run.completed","system",{"project_hash":"hmac_sha256_example_project","task_type":"security_review","risk_level":"high","complexity":"large","answered_assigned_task":false,"has_sanitized_evidence":false,"observed_model_tier":"fast","validation_state":"failed","status":"completed_with_warnings"}],
 [2,"retry.requested","main_agent",{}]]
JSON
    python - "$(run_dir run_under)" <<'PY'
import json, pathlib, sys
base = pathlib.Path(sys.argv[1])
rq = json.loads((base / "report-quality.json").read_text())
recs = json.loads((base / "governance-recommendations.json").read_text())
assert rq["quality_score"] == 5.0, rq
assert rq["quality_category"] == "unusable", rq
assert rq["model_fit"] == "underpowered", rq
assert rq["confidence"] == "high" and rq["evidence_strength"] == "strong", rq
rec = next(r for r in recs["recommendations"] if r["recommendation_id"] == "rec_model_fit_underpowered")
assert rec["category"] == "model_routing", rec
assert rec["issue_candidate"]["should_open_issue"] is True, rec
PY
}

@test "overkill model on trivial docs work is advisory only" {
    seed_run "run_over" <<'JSON'
[[1,"run.completed","system",{"project_hash":"hmac_sha256_example_project","task_type":"docs_update","risk_level":"low","complexity":"trivial","answered_assigned_task":true,"has_sanitized_evidence":true,"observed_model_tier":"deep","report_tokens":700,"status":"completed"}]]
JSON
    python - "$(run_dir run_over)" <<'PY'
import json, pathlib, sys
base = pathlib.Path(sys.argv[1])
rq = json.loads((base / "report-quality.json").read_text())
recs = json.loads((base / "governance-recommendations.json").read_text())
assert rq["model_fit"] == "overkill", rq
rec = next(r for r in recs["recommendations"] if r["recommendation_id"] == "rec_model_fit_overkill")
assert rec["recommended_action"] == "monitor", rec
assert rec["issue_candidate"]["should_open_issue"] is False, rec
PY
}

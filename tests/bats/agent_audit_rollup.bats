#!/usr/bin/env bats
#
# Cross-run rollup coverage (#330): rollup must aggregate ACROSS finalized run
# folders (per project_hash / agent / task_type) deterministically, reading only
# the already-sanitized run artifacts and never leaking raw content.

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
        "governance": {"target_report_tokens": 1200},
        "push": {"mode": "disabled", "commit": False},
    },
}
path.write_text(json.dumps(config), encoding="utf-8")
PY
}

# Record a run's events from a compact [seq, type, actor, payload] array on
# stdin, then finalize it so it lands as a central run folder.
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

@test "rollup aggregates across runs by project, agent, and task type" {
    seed_run "run_a1" <<'JSON'
[[1,"run.completed","system",{"project_hash":"hmac_sha256_proj_a","task_type":"security_review","risk_level":"high","complexity":"large","answered_assigned_task":true,"has_sanitized_evidence":true,"validation_state":"passed","observed_model_tier":"review","report_tokens":800,"status":"completed"}],
 [2,"session.metrics","system",{"provider":"codex","model":"gpt-5.5","tokens":{"input":900,"output":100,"cache_creation":0,"cache_read":100,"total":1100,"cache_hit_ratio":0.1},"speed":{"avg_tokens_per_sec":50.0,"samples":1},"context":{"context_used_ratio":0.9}}],
 [3,"agent.invoked","subagent",{"invocation_id":"inv_1","agent_category":"security"}],
 [4,"agent.completed","subagent",{"invocation_id":"inv_1","status":"success"}],
 [5,"skill.activated","main_agent",{"skill_key":"security"}],
 [6,"skill.activated","main_agent",{"skill_key":"testing"}]]
JSON
    seed_run "run_a2" <<'JSON'
[[1,"run.completed","system",{"project_hash":"hmac_sha256_proj_a","task_type":"security_review","risk_level":"high","complexity":"large","answered_assigned_task":false,"has_sanitized_evidence":false,"validation_state":"failed","observed_model_tier":"fast","status":"completed_with_warnings"}],
 [2,"retry.requested","main_agent",{}],
 [3,"agent.invoked","subagent",{"invocation_id":"inv_1","agent_category":"security"}],
 [4,"agent.completed","subagent",{"invocation_id":"inv_1","status":"success"}],
 [5,"skill.activated","main_agent",{"skill_key":"security"}]]
JSON
    seed_run "run_b1" <<'JSON'
[[1,"run.completed","system",{"project_hash":"hmac_sha256_proj_b","task_type":"docs_update","risk_level":"low","complexity":"trivial","answered_assigned_task":true,"has_sanitized_evidence":true,"validation_state":"passed","observed_model_tier":"deep","report_tokens":700,"status":"completed"}],
 [2,"session.metrics","system",{"provider":"claude","model":"claude-opus-4-8","tokens":{"input":1000,"output":200,"cache_creation":0,"cache_read":0,"total":1200,"cache_hit_ratio":0.0},"speed":{"avg_tokens_per_sec":70.0,"samples":1},"cost_estimate":{"currency":"USD","amount":0.01,"basis":"list-price-approximation"}}]]
JSON

    run bash "$KIT_ROOT/tooling/shared/agent-audit/rollup.sh" \
        --config "$CONFIG_PATH" --source-root "$TARGET"
    assert_success

    python - "$CENTRAL_PATH/agent-audit/rollups/cross-run-rollup.json" <<'PY'
import json, pathlib, sys
d = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert d["run_count"] == 3, d
assert set(d["by_project_hash"]) == {"hmac_sha256_proj_a", "hmac_sha256_proj_b"}, d
a = d["by_project_hash"]["hmac_sha256_proj_a"]
assert a["run_count"] == 2, a
# run_a2: fast tier on high-risk review + failed validation + retry -> underpowered
assert a["model_fit_distribution"].get("underpowered", 0) == 1, a["model_fit_distribution"]
# context exhaustion measured from the codex ratio 0.9 (>= 0.85)
assert a["context_exhaustion"]["exhausted_run_count"] == 1, a["context_exhaustion"]
assert a["context_exhaustion"]["measured_run_count"] == 1, a["context_exhaustion"]
# tokens aggregated from the one run that imported session.metrics
assert a["tokens"]["sum_total"] == 1100, a["tokens"]
# grouping by agent category (security appears in both proj_a runs)
assert d["by_agent"]["security"]["run_count"] == 2, d["by_agent"]
assert set(d["by_task_type"]) == {"security_review", "docs_update"}, d
# cost aggregated from the claude run (gpt-5.5 has no list price -> unpriced)
assert d["overall"]["cost"]["runs_with_cost"] == 1, d["overall"]["cost"]
assert d["overall"]["cost"]["sum_amount"] > 0, d["overall"]["cost"]
# skill usage aggregated from skill.activated events (#331)
assert d["skill_usage"]["activation_count"] == 3, d["skill_usage"]
assert d["skill_usage"]["by_skill"] == {"security": 2, "testing": 1}, d["skill_usage"]
assert d["skill_usage"]["runs_with_skills"] == 2, d["skill_usage"]
# findings: run_a2 is underpowered on a high-risk review -> issue candidate (#331)
fids = {f["summary_code"]: f for f in d["findings"]}
under = fids["underpowered_model_for_security_review"]
assert under["issue_candidate"]["should_open_issue"] is True, under
assert under["issue_candidate"]["creation"] == "manual", under
assert under["category"] == "model_routing", under
PY

    # Human-readable companion exists and the run data does not leak.
    [ -f "$CENTRAL_PATH/agent-audit/rollups/cross-run-rollup.md" ]
    run grep -rn "hmac_sha256_proj" "$CENTRAL_PATH/agent-audit/rollups/cross-run-rollup.json"
    assert_success
}

@test "rollup on an empty central writes a zero-run rollup" {
    run bash "$KIT_ROOT/tooling/shared/agent-audit/rollup.sh" \
        --config "$CONFIG_PATH" --source-root "$TARGET"
    assert_success
    python - "$CENTRAL_PATH/agent-audit/rollups/cross-run-rollup.json" <<'PY'
import json, pathlib, sys
d = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert d["run_count"] == 0, d
assert d["overall"] == {}, d
PY
    [ -f "$CENTRAL_PATH/agent-audit/rollups/cross-run-rollup.md" ]
}

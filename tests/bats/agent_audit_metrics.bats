#!/usr/bin/env bats
#
# Session-metrics import coverage (#327): import-session-metrics parses a
# provider transcript into one anonymized session.metrics event that populates
# token-context.json / pricing-estimate.json, and NEVER leaks raw content,
# paths, or branch names.

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
    python - "$CONFIG_PATH" "$RUNTIME_PATH" "$CENTRAL_PATH" <<'PY'
import json, pathlib, sys
path, runtime, central = map(pathlib.Path, sys.argv[1:])
path.write_text(json.dumps({
    "schema_version": "0.1.0",
    "audit": {
        "enabled": True, "mode": "official-central-repo",
        "official_remote_url": "https://github.com/PetrovC/ai-agent-kit.git",
        "branch": "agent-audit-data", "runtime_path": str(runtime),
        "central_repo_path": str(central), "source_project_write_policy": "never",
        "push": {"mode": "disabled", "commit": False},
    },
}), encoding="utf-8")
PY
}

# A Claude transcript that deliberately embeds forbidden data (content, cwd,
# gitBranch) so the test proves none of it reaches the audit output.
write_transcript() {
    python - "$1" <<'PY'
import json, sys
rows = [
    {"type": "user", "timestamp": "2026-05-31T10:00:00Z", "cwd": "/Users/zzleakzz/p",
     "gitBranch": "feature/zzleakzz", "message": {"role": "user", "content": "zzleakzz prompt"}},
    {"type": "assistant", "timestamp": "2026-05-31T10:00:05Z",
     "message": {"role": "assistant", "model": "claude-opus-4-7",
                 "content": [{"type": "text", "text": "zzleakzz answer"}],
                 "usage": {"input_tokens": 1000, "output_tokens": 200,
                           "cache_creation_input_tokens": 50,
                           "cache_read_input_tokens": 4000, "speed": 90.0}}},
    {"type": "assistant", "timestamp": "2026-05-31T10:00:09Z", "isSidechain": True,
     "message": {"role": "assistant", "model": "claude-opus-4-7",
                 "usage": {"input_tokens": 300, "output_tokens": 90,
                           "cache_read_input_tokens": 1000, "speed": 110.0}}},
    {"type": "system", "subtype": "compact_boundary", "timestamp": "2026-05-31T10:00:20Z"},
]
open(sys.argv[1], "w", encoding="utf-8").write("\n".join(json.dumps(r) for r in rows))
PY
}

@test "import-session-metrics requires a run id" {
    write_transcript "$AUDIT_ROOT/t.jsonl"
    run env -u AAK_AUDIT_RUN_ID bash "$KIT_ROOT/tooling/shared/agent-audit/import-session-metrics.sh" \
        --config "$CONFIG_PATH" --source-root "$TARGET" --provider claude --transcript "$AUDIT_ROOT/t.jsonl"
    assert_failure
}

@test "import populates token-context/pricing and never leaks raw content" {
    write_transcript "$AUDIT_ROOT/t.jsonl"
    export AAK_AUDIT_RUN_ID="run_metrics"
    run bash "$KIT_ROOT/tooling/shared/agent-audit/emit-event.sh" --config "$CONFIG_PATH" \
        --source-root "$TARGET" --type run.completed --actor system \
        --payload '{"project_hash":"hmac_sha256_example_project","status":"completed"}'
    assert_success
    run bash "$KIT_ROOT/tooling/shared/agent-audit/import-session-metrics.sh" --config "$CONFIG_PATH" \
        --source-root "$TARGET" --provider claude --transcript "$AUDIT_ROOT/t.jsonl" --run-id run_metrics
    assert_success
    run bash "$KIT_ROOT/tooling/shared/agent-audit/finalize-run.sh" --config "$CONFIG_PATH" \
        --source-root "$TARGET" --run-id run_metrics
    assert_success

    base="$CENTRAL_PATH/agent-audit/runs/2026/05/hmac_sha256_example_project/run_metrics"
    python - "$base" <<'PY'
import json, pathlib, sys
base = pathlib.Path(sys.argv[1])
tc = json.loads((base / "token-context.json").read_text())
assert tc["measurement_mode"] == "imported-transcript", tc
assert tc["provider_usage_available"] is True, tc
assert tc["tokens"]["input"] == 1300, tc["tokens"]
assert tc["tokens"]["output"] == 290, tc["tokens"]
assert tc["tokens"]["cache_read"] == 5000, tc["tokens"]
assert 0.0 < tc["tokens"]["cache_hit_ratio"] <= 1.0, tc["tokens"]
assert tc["subagent"]["sidechain_output_tokens"] == 90, tc["subagent"]
assert tc["compression"]["executed_count"] == 1, tc["compression"]
pr = json.loads((base / "pricing-estimate.json").read_text())
assert pr["measurement_mode"] == "list-price-approximation" and pr["amount"] > 0, pr
PY
    assert_success

    # Privacy: none of the injected forbidden data may appear anywhere.
    run grep -rn "zzleakzz" "$base" "$RUNTIME_PATH"
    assert_failure
}

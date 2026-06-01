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

    # emit/import stamp events with the real current time, so the year/month
    # path segments are not hardcodable; locate the run folder by name.
    base="$(find "$CENTRAL_PATH/agent-audit/runs" -type d -name run_metrics | head -1)"
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

# A Codex rollout embedding forbidden data (cwd, prompt/answer text) and a
# cumulative-counter reset after compaction, to exercise segment summing.
write_codex_transcript() {
    python - "$1" <<'PY'
import json, sys
def tc(inp, cached, out, reason, total, prim, win_p=300, sec=None):
    info = {"total_token_usage": {"input_tokens": inp, "cached_input_tokens": cached,
                                  "output_tokens": out, "reasoning_output_tokens": reason,
                                  "total_tokens": total},
            "last_token_usage": {"input_tokens": inp, "cached_input_tokens": cached,
                                 "output_tokens": out, "reasoning_output_tokens": reason,
                                 "total_tokens": total},
            "model_context_window": 200000}
    limits = {"primary": {"used_percent": prim, "window_minutes": win_p}}
    if sec is not None:
        limits["secondary"] = {"used_percent": sec, "window_minutes": 10080}
    return {"type": "event_msg", "payload": {"type": "token_count", "info": info, "rate_limits": limits}}
rows = [
    {"type": "session_meta", "timestamp": "2026-05-31T10:00:00Z",
     "payload": {"id": "x", "cwd": "/Users/zzleakzz/p", "model_provider": "openai"}},
    {"type": "turn_context", "timestamp": "2026-05-31T10:00:01Z",
     "payload": {"model": "gpt-5.5", "cwd": "/Users/zzleakzz/p"}},
    {"type": "response_item", "timestamp": "2026-05-31T10:00:02Z",
     "payload": {"type": "message", "role": "user", "content": "zzleakzz prompt"}},
    {"type": "response_item", "timestamp": "2026-05-31T10:00:03Z",
     "payload": {"type": "function_call", "name": "shell"}},
    {"type": "response_item", "timestamp": "2026-05-31T10:00:04Z",
     "payload": {"type": "function_call_output"}},
    {"type": "response_item", "timestamp": "2026-05-31T10:00:05Z",
     "payload": {"type": "reasoning"}},
    {"type": "response_item", "timestamp": "2026-05-31T10:00:06Z",
     "payload": {"type": "message", "role": "assistant", "content": "zzleakzz answer"}},
    {**tc(1000, 400, 120, 50, 1120, 75.0, sec=20.0), "timestamp": "2026-05-31T10:00:07Z"},
    {"type": "event_msg", "timestamp": "2026-05-31T10:00:08Z", "payload": {"type": "context_compacted"}},
    {**tc(450, 100, 50, 20, 500, 90.0), "timestamp": "2026-05-31T10:00:09Z"},
    {**tc(800, 200, 100, 40, 900, 85.0), "timestamp": "2026-05-31T10:00:10Z"},
]
open(sys.argv[1], "w", encoding="utf-8").write("\n".join(json.dumps(r) for r in rows))
PY
}

# An Antigravity SQLite conversation: protobuf BLOBs carrying the model enum
# string plus forbidden bytes, proving only the model id + counts are extracted.
write_antigravity_db() {
    python - "$1" <<'PY'
import sqlite3, sys
con = sqlite3.connect(sys.argv[1]); cur = con.cursor()
cur.execute("CREATE TABLE steps (idx INTEGER, step_type INTEGER, step_payload BLOB)")
for i in range(3):
    cur.execute("INSERT INTO steps VALUES (?,?,?)", (i, 1, b"zzleakzz step /Users/zzleakzz"))
cur.execute("CREATE TABLE gen_metadata (idx INTEGER, data BLOB, size INTEGER)")
for i in range(2):
    cur.execute("INSERT INTO gen_metadata VALUES (?,?,?)", (i, b"model_enum\x00gemini-3-flash\x00zzleakzz", 10))
cur.execute("CREATE TABLE executor_metadata (idx INTEGER, data BLOB)")
cur.execute("INSERT INTO executor_metadata VALUES (0,?)", (b"exec\x00gemini-3-flash-low\x00zzleakzz",))
con.commit(); con.close()
PY
}

@test "import codex token_count populates tokens/rate-limit and never leaks" {
    write_codex_transcript "$AUDIT_ROOT/codex.jsonl"
    export AAK_AUDIT_RUN_ID="run_codex"
    run bash "$KIT_ROOT/tooling/shared/agent-audit/emit-event.sh" --config "$CONFIG_PATH" \
        --source-root "$TARGET" --type run.completed --actor system \
        --payload '{"project_hash":"hmac_sha256_example_project","status":"completed"}'
    assert_success
    run bash "$KIT_ROOT/tooling/shared/agent-audit/import-session-metrics.sh" --config "$CONFIG_PATH" \
        --source-root "$TARGET" --provider codex --transcript "$AUDIT_ROOT/codex.jsonl" --run-id run_codex
    assert_success
    run bash "$KIT_ROOT/tooling/shared/agent-audit/finalize-run.sh" --config "$CONFIG_PATH" \
        --source-root "$TARGET" --run-id run_codex
    assert_success

    base="$(find "$CENTRAL_PATH/agent-audit/runs" -type d -name run_codex | head -1)"
    python - "$base" <<'PY'
import json, pathlib, sys
base = pathlib.Path(sys.argv[1])
tc = json.loads((base / "token-context.json").read_text())
assert tc["provider"] == "codex" and tc["model"] == "gpt-5.5", tc
assert tc["measurement_mode"] == "imported-transcript", tc
assert tc["provider_usage_available"] is True, tc
# segment summing across the post-compaction counter reset (1120 -> reset -> 900)
assert tc["tokens"]["input"] == 1200, tc["tokens"]
assert tc["tokens"]["cache_read"] == 600, tc["tokens"]
assert tc["tokens"]["output"] == 220, tc["tokens"]
assert tc["tokens"]["total"] == 2020, tc["tokens"]
assert 0.0 < tc["tokens"]["cache_hit_ratio"] < 1.0, tc["tokens"]
assert tc["reasoning"]["output_tokens"] == 90, tc["reasoning"]
assert tc["rate_limit"]["primary_used_percent"] == 90.0, tc["rate_limit"]
assert tc["context"]["peak_request_input_tokens"] == 1000, tc["context"]
assert tc["context"]["context_used_ratio"] == 0.005, tc["context"]
assert tc["compression"]["executed_count"] == 1, tc["compression"]
assert tc["turns"]["tool_results"] == 1 and tc["tool_calls"]["total"] == 1, tc
# Codex list prices are not configured -> pricing stays honest/unavailable
pr = json.loads((base / "pricing-estimate.json").read_text())
assert pr["measurement_mode"] == "unavailable", pr
PY
    assert_success

    run grep -rn "zzleakzz" "$base" "$RUNTIME_PATH"
    assert_failure
}

@test "import antigravity reads structural metrics only and never leaks" {
    write_antigravity_db "$AUDIT_ROOT/agy.db"
    export AAK_AUDIT_RUN_ID="run_agy"
    run bash "$KIT_ROOT/tooling/shared/agent-audit/emit-event.sh" --config "$CONFIG_PATH" \
        --source-root "$TARGET" --type run.completed --actor system \
        --payload '{"project_hash":"hmac_sha256_example_project","status":"completed"}'
    assert_success
    run bash "$KIT_ROOT/tooling/shared/agent-audit/import-session-metrics.sh" --config "$CONFIG_PATH" \
        --source-root "$TARGET" --provider antigravity --transcript "$AUDIT_ROOT/agy.db" --run-id run_agy
    assert_success
    run bash "$KIT_ROOT/tooling/shared/agent-audit/finalize-run.sh" --config "$CONFIG_PATH" \
        --source-root "$TARGET" --run-id run_agy
    assert_success

    base="$(find "$CENTRAL_PATH/agent-audit/runs" -type d -name run_agy | head -1)"
    python - "$base" <<'PY'
import json, pathlib, sys
base = pathlib.Path(sys.argv[1])
tc = json.loads((base / "token-context.json").read_text())
assert tc["provider"] == "antigravity", tc
assert tc["model"] == "gemini-3-flash-low", tc
assert tc["measurement_mode"] == "imported-transcript-structural", tc
assert tc["provider_usage_available"] is False, tc
assert tc["tokens"]["total"] == 0, tc["tokens"]
assert tc["context"]["step_count"] == 3, tc["context"]
assert tc["context"]["generation_count"] == 2, tc["context"]
PY
    assert_success

    run grep -rn "zzleakzz" "$base" "$RUNTIME_PATH"
    assert_failure
}

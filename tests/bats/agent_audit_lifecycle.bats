#!/usr/bin/env bats
#
# Lifecycle auto-emit coverage (#328): provider hooks map session/agent
# lifecycle events to run.*/agent.* governance events sharing a stable run id,
# auto-finalize on run end, stay fail-open, and never leak raw content. The
# hook reads $PROJECT_DIR/.ai-agent-kit/audit/* so the repo's own dogfood
# install (KIT_ROOT) is used as the project dir.

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

# claude_hook <run_id> <stdin-json> [event-arg]
claude_hook() {
    printf '%s' "$2" | env CLAUDE_PROJECT_DIR="$KIT_ROOT" AAK_AUDIT_CONFIG="$CONFIG_PATH" \
        AAK_AUDIT_RUN_ID="$1" bash "$KIT_ROOT/tooling/claude/hooks/agent-audit-event.sh" "${3:-}"
}

@test "claude lifecycle hooks emit run/agent events, auto-finalize, and never leak" {
    claude_hook run_life '{}' SessionStart
    claude_hook run_life '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"echo zzleakzz /Users/zzleakzz"}}'
    claude_hook run_life '{}' SubagentStop
    claude_hook run_life '{}' SessionEnd

    base="$(find "$CENTRAL_PATH/agent-audit/runs" -type d -name run_life | head -1)"
    [ -n "$base" ]
    python - "$base" <<'PY'
import json, pathlib, sys, collections
base = pathlib.Path(sys.argv[1])
ev = collections.Counter()
for line in (base / "governance-events.ndjson").read_text().splitlines():
    if line.strip():
        ev[json.loads(line)["event_type"]] += 1
assert ev["run.started"] == 1, ev
assert ev["run.completed"] == 1, ev
assert ev["agent.completed"] == 1, ev
assert ev["tool.observed"] == 1, ev
summary = json.loads((base / "run-summary.json").read_text())
assert summary["status"] == "completed", summary
PY
    run grep -rn "zzleakzz" "$base" "$RUNTIME_PATH"
    assert_failure
}

@test "claude SessionEnd auto-imports anonymized session metrics from the transcript" {
    transcript="$AUDIT_ROOT/session.jsonl"
    cat > "$transcript" <<'JSON'
{"type":"user","timestamp":"2026-06-01T10:00:00Z","cwd":"/Users/zzleakzz/p","message":{"role":"user","content":"zzleakzz prompt"}}
{"type":"assistant","timestamp":"2026-06-01T10:00:05Z","message":{"role":"assistant","model":"claude-opus-4-8","content":[{"type":"text","text":"zzleakzz answer"}],"usage":{"input_tokens":1000,"output_tokens":200,"cache_read_input_tokens":4000,"speed":90.0}}}
JSON
    claude_hook run_metrics "$(printf '{"transcript_path":"%s"}' "$transcript")" SessionEnd

    base="$(find "$CENTRAL_PATH/agent-audit/runs" -type d -name run_metrics | head -1)"
    [ -n "$base" ]
    python - "$base" <<'PY'
import json, pathlib, sys
base = pathlib.Path(sys.argv[1])
tc = json.loads((base / "token-context.json").read_text())
assert tc["measurement_mode"] == "imported-transcript", tc
assert tc["model"] == "claude-opus-4-8", tc
assert tc["tokens"]["total"] == 5200, tc["tokens"]
assert tc["tokens"]["cache_hit_ratio"] == 0.8, tc["tokens"]
PY
    # raw transcript content (prompt/answer/cwd) must never reach the run folder
    run grep -rn "zzleakzz" "$base" "$RUNTIME_PATH"
    assert_failure
}

@test "codex Stop is the session-close event and finalizes the run" {
    printf '%s' '{"hook_event_name":"Stop"}' | env CODEX_PROJECT_DIR="$KIT_ROOT" \
        AAK_AUDIT_CONFIG="$CONFIG_PATH" AAK_AUDIT_RUN_ID="run_codex_life" \
        bash "$KIT_ROOT/tooling/codex/hooks/agent-audit-event.sh"
    base="$(find "$CENTRAL_PATH/agent-audit/runs" -type d -name run_codex_life | head -1)"
    [ -n "$base" ]
    grep -q '"event_type":"run.completed"' "$base/governance-events.ndjson"
}

@test "hook is fail-open when the audit config is absent (no behavior change)" {
    run env CLAUDE_PROJECT_DIR="$KIT_ROOT" AAK_AUDIT_CONFIG="$AUDIT_ROOT/absent.json" \
        AAK_AUDIT_RUN_ID="run_noop" \
        bash "$KIT_ROOT/tooling/claude/hooks/agent-audit-event.sh" SessionStart <<< '{}'
    assert_success
    [ ! -d "$RUNTIME_PATH/runs/run_noop" ]
}

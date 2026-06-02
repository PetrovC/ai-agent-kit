#!/usr/bin/env bats
#
# Cross-tool delegation adapter coverage (#339, Phase 2). The provider CLI is
# the single mockable boundary: a stub `codex` on PATH records its argv and
# returns a canned JSON-Lines summary. Everything else (model routing,
# brief/summary sanitization, audit-event emission, fail-open behavior) is
# asserted without a live CLI.

load 'bats_helper'

setup() {
    aak_setup
    AUDIT_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/audit.XXXXXX")"
    RUNTIME_PATH="$AUDIT_ROOT/runtime"
    CENTRAL_PATH="$AUDIT_ROOT/central"
    CONFIG_PATH="$AUDIT_ROOT/config.json"
    BIN="$AUDIT_ROOT/bin"
    STUB_RECORD="$AUDIT_ROOT/argv.txt"
    STUB_ENV="$AUDIT_ROOT/model-env.txt"
    BRIEF="$AUDIT_ROOT/brief.txt"
    mkdir -p "$RUNTIME_PATH" "$CENTRAL_PATH" "$BIN"
    git -C "$CENTRAL_PATH" init >/dev/null
    git -C "$CENTRAL_PATH" checkout -b agent-audit-data >/dev/null
    export AUDIT_ROOT RUNTIME_PATH CENTRAL_PATH CONFIG_PATH BIN STUB_RECORD STUB_ENV BRIEF
    write_config
    write_codex_stub
    write_agy_stub
    echo "Please review the auth module for injection risks." > "$BRIEF"
}

write_config() {
    python - "$CONFIG_PATH" "$RUNTIME_PATH" "$CENTRAL_PATH" <<'PY'
import json, pathlib, sys
path, runtime, central = map(pathlib.Path, sys.argv[1:])
path.write_text(json.dumps({
    "schema_version": "0.1.0",
    "audit": {
        "enabled": True,
        "mode": "official-central-repo",
        "branch": "agent-audit-data",
        "runtime_path": str(runtime),
        "central_repo_path": str(central),
        "source_project_write_policy": "never",
        "push": {"mode": "disabled", "commit": False},
    },
}), encoding="utf-8")
PY
}

write_codex_stub() {
    cat > "$BIN/codex" <<'STUB'
#!/usr/bin/env bash
# Record argv (one arg per line) so the test can assert the exact invocation,
# then emit a JSON-Lines agent message like `codex exec --json` would.
printf '%s\n' "$@" > "$STUB_RECORD"
echo '{"type":"item.completed","item":{"type":"agent_message","text":"Stub review complete: no high-severity findings."}}'
STUB
    chmod +x "$BIN/codex"
}

write_agy_stub() {
    cat > "$BIN/agy" <<'STUB'
#!/usr/bin/env bash
# Record argv and the model hint passed via the environment, then emit a
# structured (JSON) answer like `agy -p --output-format json` would.
printf '%s\n' "$@" > "$STUB_RECORD"
printf '%s\n' "${ANTIGRAVITY_MODEL:-}" > "$STUB_ENV"
echo '{"response":"Stub Antigravity analysis: no blocking issue."}'
STUB
    chmod +x "$BIN/agy"
}

events_file() {
    find "$RUNTIME_PATH/runs" -name events.ndjson | head -1
}

# Run the adapter with the stub CLIs on PATH.
delegate() {
    run env PATH="$BIN:$PATH" STUB_RECORD="$STUB_RECORD" STUB_ENV="$STUB_ENV" \
        bash "$KIT_ROOT/tooling/shared/delegate/delegate.sh" \
        --config "$CONFIG_PATH" --source-root "$TARGET" --brief-file "$BRIEF" "$@"
}

@test "delegate requires a brief file" {
    run bash "$KIT_ROOT/tooling/shared/delegate/delegate.sh" \
        --config "$CONFIG_PATH" --source-root "$TARGET" --provider codex
    assert_failure
}

@test "delegate rejects an unsupported provider" {
    run bash "$KIT_ROOT/tooling/shared/delegate/delegate.sh" \
        --config "$CONFIG_PATH" --source-root "$TARGET" \
        --brief-file "$BRIEF" --provider gemini
    assert_failure
}

@test "delegate routes security_review/high to high reasoning effort" {
    delegate --provider codex --task-type security_review --risk high \
        --run-id run_deleg_high
    assert_success
    assert_output_contains "Stub review complete"
    run cat "$STUB_RECORD"
    assert_output_contains "exec"
    assert_output_contains "gpt-5.5"
    assert_output_contains "model_reasoning_effort=high"
    assert_output_contains "read-only"
    assert_output_contains "--json"
}

@test "delegate routes formatting/low to low reasoning effort" {
    delegate --provider codex --task-type formatting --risk low \
        --run-id run_deleg_low
    assert_success
    run cat "$STUB_RECORD"
    assert_output_contains "model_reasoning_effort=low"
}

@test "delegate emits agent.selected/invoked/completed with a provider field" {
    delegate --provider codex --task-type security_review --risk high \
        --run-id run_deleg_events --invocation-id inv_deleg
    assert_success
    run cat "$(events_file)"
    assert_output_contains '"event_type":"agent.selected"'
    assert_output_contains '"event_type":"agent.invoked"'
    assert_output_contains '"event_type":"agent.completed"'
    assert_output_contains '"provider":"codex"'
    assert_output_contains '"status":"success"'
}

@test "delegate routes investigation/medium to the Antigravity Pro model hint" {
    delegate --provider antigravity --task-type investigation --risk medium \
        --run-id run_agy_deep
    assert_success
    assert_output_contains "Stub Antigravity analysis"
    run cat "$STUB_RECORD"
    assert_output_contains "-p"
    assert_output_contains "--output-format"
    assert_output_contains "--dangerously-skip-permissions"
    run cat "$STUB_ENV"
    assert_output_contains "gemini-3.1-pro"
}

@test "delegate routes daily/medium to the Antigravity Flash model hint" {
    delegate --provider antigravity --task-type daily --risk medium \
        --run-id run_agy_std
    assert_success
    run cat "$STUB_ENV"
    assert_output_contains "gemini-3-flash"
}

@test "delegate emits Antigravity events with the provider field" {
    delegate --provider antigravity --task-type investigation --risk medium \
        --run-id run_agy_events --invocation-id inv_agy
    assert_success
    run cat "$(events_file)"
    assert_output_contains '"event_type":"agent.completed"'
    assert_output_contains '"provider":"antigravity"'
    assert_output_contains '"status":"success"'
}

@test "delegate skips delegation when the brief fails the privacy scan" {
    # A secret-like token must never reach the provider CLI.
    printf 'leaked secret sk-ABCDEFGHIJKLMNOPqrstuvwx here\n' > "$BRIEF"
    rm -f "$STUB_RECORD"
    delegate --provider codex --task-type other --risk low --run-id run_deleg_priv
    assert_success
    assert_file_missing "$STUB_RECORD"
}

@test "delegate is fail-open when the provider CLI fails" {
    # The provider exits non-zero: the adapter must not crash; it records an
    # error completion and returns 0 so the orchestrator is undisturbed. A
    # failing stub keeps this deterministic regardless of a real codex on PATH.
    cat > "$BIN/codex" <<'STUB'
#!/usr/bin/env bash
echo "boom" >&2
exit 7
STUB
    chmod +x "$BIN/codex"
    delegate --provider codex --task-type other --risk low --run-id run_deleg_fail
    assert_success
    run cat "$(events_file)"
    assert_output_contains '"status":"error"'
}

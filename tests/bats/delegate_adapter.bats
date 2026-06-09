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
# Record argv and the model hint passed via the environment, then print a
# plain-text answer like `agy -p` would.
printf '%s\n' "$@" > "$STUB_RECORD"
printf '%s\n' "${ANTIGRAVITY_MODEL:-}" > "$STUB_ENV"
echo "Stub Antigravity analysis: no blocking issue."
STUB
    chmod +x "$BIN/agy"
}

# An agy stub that simulates quota exhaustion on the primary (Sonnet) model:
# exits non-zero with a 429-like error so the adapter's fallback path fires,
# then succeeds on the next call (fallback model != claude-sonnet-4-6).
write_quota_agy_stub() {
    cat > "$BIN/agy" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$STUB_RECORD"
printf '%s\n' "${ANTIGRAVITY_MODEL:-}" >> "$STUB_ENV"
if [ "${ANTIGRAVITY_MODEL:-}" = "claude-sonnet-4-6" ]; then
    echo "Error: 429 quota exhausted for claude-sonnet-4-6" >&2
    exit 1
fi
echo "Stub Antigravity fallback analysis: succeeded with fallback model."
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

# Audit event emission tests removed — emit() is now a no-op (audit subsystem removed, #408).

@test "delegate routes investigation/medium to the Antigravity Opus model hint" {
    delegate --provider antigravity --task-type investigation --risk medium \
        --run-id run_agy_deep
    assert_success
    assert_output_contains "Stub Antigravity analysis"
    run cat "$STUB_RECORD"
    assert_output_contains "-p"
    assert_output_contains "--sandbox"
    assert_output_contains "--dangerously-skip-permissions"
    run cat "$STUB_ENV"
    assert_output_contains "claude-opus-4-6"
}

@test "delegate routes daily/medium to the Antigravity Sonnet model hint" {
    delegate --provider antigravity --task-type daily --risk medium \
        --run-id run_agy_std
    assert_success
    run cat "$STUB_ENV"
    assert_output_contains "claude-sonnet-4-6"
}

@test "delegate uses workspace-write sandbox for Codex implementation tasks" {
    delegate --provider codex --task-type feat --risk medium \
        --run-id run_codex_impl
    assert_success
    run cat "$STUB_RECORD"
    assert_output_contains "workspace-write"
    run grep "read-only" "$STUB_RECORD"
    assert_failure
}

@test "delegate drops --sandbox for Antigravity implementation tasks" {
    delegate --provider antigravity --task-type feat --risk medium \
        --run-id run_agy_impl
    assert_success
    run cat "$STUB_RECORD"
    assert_output_contains "--dangerously-skip-permissions"
    run grep -- "--sandbox" "$STUB_RECORD"
    assert_failure
}

@test "delegate redacts secret-like tokens in the brief and still delegates" {
    secret="sk-ABCDEFGHIJKLMNOPqrstuvwx"
    printf 'leaked secret %s here\n' "$secret" > "$BRIEF"
    rm -f "$STUB_RECORD"
    delegate --provider codex --task-type other --risk low --run-id run_deleg_priv
    assert_success
    run test -f "$STUB_RECORD"
    assert_success
    recorded="$(cat "$STUB_RECORD")"
    run grep -Fq "[REDACTED_" <<< "$recorded"
    assert_success
    run grep -Fq "$secret" <<< "$recorded"
    assert_failure
}

@test "delegate retries with Gemini fallback when Antigravity Sonnet quota is exhausted" {
    write_quota_agy_stub
    : > "$STUB_ENV"   # reset so both model hints are appended by the quota stub
    delegate --provider antigravity --task-type feat --risk medium \
        --run-id run_agy_fallback
    assert_success
    # The fallback agy call prints this to stdout; the adapter forwards it.
    assert_output_contains "fallback analysis"
    # Both the primary (claude-sonnet-4-6) and fallback (gemini-3.1-pro) hints
    # must appear in the accumulated env file.
    run cat "$STUB_ENV"
    assert_output_contains "gemini-3.1-pro"
}

@test "delegate does not retry fallback for Codex quota errors" {
    # Codex has no per-model fallback path; a quota error is an ordinary
    # provider failure that records status=error and returns 0.
    cat > "$BIN/codex" <<'STUB'
#!/usr/bin/env bash
echo "Error: 429 quota exhausted" >&2
exit 1
STUB
    chmod +x "$BIN/codex"
    delegate --provider codex --task-type feat --risk medium \
        --run-id run_codex_quota
    assert_success
    # Codex quota errors are fail-open: adapter returns 0 even on provider failure.
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
    # Provider failure is fail-open: adapter returns 0 so the orchestrator is undisturbed.
}

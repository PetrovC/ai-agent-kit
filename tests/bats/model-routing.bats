#!/usr/bin/env bats
# Regression tests for scripts/select-model.py model selection routing.

load 'bats_helper.bash'

setup() {
    aak_setup
    SELECTOR="$KIT_ROOT/scripts/select-model.py"
}

run_selector() {
    run python3 "$SELECTOR" "$@"
}

# --- basic smoke ---

@test "select-model: --help exits 0" {
    run_selector --help
    [ "$status" -eq 0 ]
}

@test "select-model: missing --task exits non-zero" {
    run_selector --risk low
    [ "$status" -ne 0 ]
}

@test "select-model: unknown --risk exits non-zero" {
    run_selector --task "fix bug" --risk extreme
    [ "$status" -ne 0 ]
}

# --- tier routing ---

@test "select-model: docs typo -> fast tier" {
    run_selector --task "fix typo in README" --risk low
    [ "$status" -eq 0 ]
    assert_output_contains "fast"
    refute_output_contains "high_reasoning"
}

@test "select-model: architecture review -> high_reasoning tier" {
    run_selector --task "review the service layer architecture" --risk medium
    [ "$status" -eq 0 ]
    assert_output_contains "high_reasoning"
}

@test "select-model: security audit -> high_reasoning tier" {
    run_selector --task "security review of authentication code" --risk high
    [ "$status" -eq 0 ]
    assert_output_contains "high_reasoning"
}

@test "select-model: normal implementation -> balanced tier" {
    run_selector --task "implement user login endpoint" --risk medium
    [ "$status" -eq 0 ]
    assert_output_contains "balanced"
    refute_output_contains "high_reasoning"
}

# --- risk bumps ---

@test "select-model: small fix + high risk -> balanced (bumped from fast)" {
    run_selector --task "update config file" --risk high
    [ "$status" -eq 0 ]
    assert_output_contains "balanced"
    assert_output_contains "+1"
}

@test "select-model: docs typo + critical risk -> high_reasoning (double bump)" {
    run_selector --task "fix typo in README" --risk critical
    [ "$status" -eq 0 ]
    assert_output_contains "high_reasoning"
    assert_output_contains "+2"
}

@test "select-model: refactor + high risk -> high_reasoning (bumped from balanced)" {
    run_selector --task "refactor the authentication module" --risk high
    [ "$status" -eq 0 ]
    assert_output_contains "high_reasoning"
}

# --- context-size bumps ---

@test "select-model: balanced + large context -> high_reasoning" {
    run_selector --task "implement feature" --risk low --context-size large
    [ "$status" -eq 0 ]
    assert_output_contains "high_reasoning"
}

# --- confirmation policy ---

@test "select-model: high_reasoning requires confirmation (json)" {
    run_selector --task "architecture review" --json
    [ "$status" -eq 0 ]
    assert_output_contains '"requires_confirmation": true'
}

@test "select-model: fast tier no confirmation (json)" {
    run_selector --task "fix typo in README" --risk low --json
    [ "$status" -eq 0 ]
    assert_output_contains '"requires_confirmation": false'
}

# --- provider filter ---

@test "select-model: --provider codex shows codex in output" {
    run_selector --task "implement feature" --provider codex
    [ "$status" -eq 0 ]
    assert_output_contains "codex"
}

@test "select-model: json output includes fallbacks" {
    run_selector --task "implement feature" --json
    [ "$status" -eq 0 ]
    assert_output_contains '"fallbacks"'
}

@test "select-model: json output includes intent field" {
    run_selector --task "fix typo in README" --risk low --json
    [ "$status" -eq 0 ]
    assert_output_contains '"intent"'
}

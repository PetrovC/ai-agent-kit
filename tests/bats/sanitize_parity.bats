#!/usr/bin/env bats
#
# Parity coverage for standalone and delegation-egress sanitization.

load 'bats_helper'

setup() {
    aak_setup
    AWS_KEY="AKIA1234567890ABCDEF"
    FINE_GRAINED_GITHUB_TOKEN="github_pat_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    BEARER_TOKEN="Bearer AbCdEfGhIjKlMn"
    PRIVATE_IP="10.1.2.3"
    CLASSIC_GITHUB_TOKEN="ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    OPENAI_KEY="sk-ABCDEFGHIJKLMNOPQRSTUVWX"
    FIXTURE="$(printf '%s\n' \
        "$AWS_KEY" \
        "$FINE_GRAINED_GITHUB_TOKEN" \
        "$BEARER_TOKEN" \
        "$PRIVATE_IP" \
        "$CLASSIC_GITHUB_TOKEN" \
        "$OPENAI_KEY")"
}

assert_fixture_redacted() {
    local sanitized="$1"
    local secret
    for secret in \
        "$AWS_KEY" \
        "$FINE_GRAINED_GITHUB_TOKEN" \
        "$BEARER_TOKEN" \
        "$PRIVATE_IP" \
        "$CLASSIC_GITHUB_TOKEN" \
        "$OPENAI_KEY"; do
        run grep -Fq "$secret" <<< "$sanitized"
        assert_failure
    done
    run grep -Fq "[REDACTED" <<< "$sanitized"
    assert_success
}

@test "sanitize.sh redacts delegation secret categories" {
    run bash -c 'printf "%s\n" "$1" | bash "$2"' \
        _ "$FIXTURE" "$KIT_ROOT/scripts/sanitize.sh"
    assert_success
    assert_fixture_redacted "$output"
}

@test "Python egress rules redact delegation secret categories" {
    run env PYTHONPATH="$KIT_ROOT/tooling/shared/delegate${PYTHONPATH:+:$PYTHONPATH}" \
        python3 -c \
        'import sys; from sanitize_patterns import redact_text; print(redact_text(sys.stdin.read())[0])' \
        <<< "$FIXTURE"
    assert_success
    assert_fixture_redacted "$output"
}

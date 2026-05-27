#!/usr/bin/env bats

load 'bats_helper'

setup() {
    aak_setup
}

@test "sanitize.sh redacts email addresses" {
    run bash "$KIT_ROOT/scripts/sanitize.sh" <<< "owner email is jane.doe@example.com"
    assert_success
    assert_output_contains "[REDACTED_EMAIL]"
}

@test "sanitize.sh redacts URL credentials" {
    run bash "$KIT_ROOT/scripts/sanitize.sh" <<< "proxy https://user:pass@internal.corp/api"
    assert_success
    assert_output_contains "https://[REDACTED_CREDENTIALS]@"
}

@test "sanitize.sh redacts GitHub tokens and bearer tokens" {
    input="token ghp_1234567890abcdefghijABCDEFGHIJ and Bearer abcdefghijklmnop123456"
    run bash "$KIT_ROOT/scripts/sanitize.sh" <<< "$input"
    assert_success
    assert_output_contains "[REDACTED_GITHUB_TOKEN]"
    assert_output_contains "Bearer [REDACTED_BEARER_TOKEN]"
}

@test "sanitize.sh redacts AWS key IDs and private IPs" {
    run bash "$KIT_ROOT/scripts/sanitize.sh" <<< "AKIA1234567890ABCDEF from 10.42.1.7"
    assert_success
    assert_output_contains "[REDACTED_AWS_ACCESS_KEY]"
    assert_output_contains "[REDACTED_PRIVATE_IP]"
}

@test "sanitize.sh redacts internal hostnames and secret key values" {
    input='endpoint api.service.internal password="super-secret-value"'
    run bash "$KIT_ROOT/scripts/sanitize.sh" <<< "$input"
    assert_success
    assert_output_contains "[REDACTED_INTERNAL_HOST]"
    assert_output_contains 'password="[REDACTED_SECRET]"'
}

@test "sanitize.sh supports --input and --output" {
    input_file="$TARGET/raw.log"
    output_file="$TARGET/sanitized.log"
    printf '%s\n' 'API_KEY=xyz123 jane@corp.example' > "$input_file"

    run bash "$KIT_ROOT/scripts/sanitize.sh" --input "$input_file" --output "$output_file"
    assert_success

    run cat "$output_file"
    assert_success
    assert_output_contains "API_KEY=[REDACTED_SECRET]"
    assert_output_contains "[REDACTED_EMAIL]"
}

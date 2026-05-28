#!/usr/bin/env bats
#
# Arg-parsing coverage for the kit lifecycle scripts.
#
# Locks down the contracts that install/update/uninstall must reject:
#   - missing --target,
#   - non-existent --target,
#   - flag-as-value (`--target --tools codex`),
#   - empty / whitespace-only --tools list,
#   - unknown tool names,
#   - unknown top-level flags,
# plus the positive cases for --dry-run and --tools normalisation
# (trim, lowercase). These mirror the require_value / normalize_tools
# invariants both shells must honour identically.

load 'bats_helper'

setup() {
    aak_setup
}

@test "install.sh fails without --target" {
    run bash "$KIT_ROOT/scripts/install.sh"
    assert_failure
    assert_output_contains "Usage:"
}

@test "install.sh rejects --target pointing at a missing directory" {
    run bash "$KIT_ROOT/scripts/install.sh" --target "$BATS_TEST_TMPDIR/does-not-exist"
    assert_failure
    assert_output_contains "Target directory does not exist"
}

@test "install.sh rejects --target consumed by another flag" {
    run bash "$KIT_ROOT/scripts/install.sh" --target --tools claude
    assert_failure
    assert_output_contains "--target requires a value"
}

@test "install.sh rejects an unknown tool" {
    run bash "$KIT_ROOT/scripts/install.sh" --target "$TARGET" --tools bogus
    assert_failure
    assert_output_contains "unknown tool"
}

@test "install.sh rejects an empty --tools list" {
    run bash "$KIT_ROOT/scripts/install.sh" --target "$TARGET" --tools ", ,"
    assert_failure
    assert_output_contains "--tools list is empty"
}

@test "install.sh rejects an unknown argument" {
    run bash "$KIT_ROOT/scripts/install.sh" --target "$TARGET" --frobnicate
    assert_failure
    assert_output_contains "Unknown argument"
}

@test "install.sh normalises --tools to lowercase + canonical order in .kit-version" {
    # Mixed case + whitespace + reversed order — must canonicalise.
    run aak_install --tools "agy, Claude"
    assert_success
    assert_file_exists "$TARGET/.kit-version"
    run cat "$TARGET/.kit-version"
    assert_success
    # Canonical order is codex,claude,agy; install.sh writes the union of
    # already-installed + --tools in that order. A fresh install with claude
    # and agy must therefore record `tools: claude,agy`, not
    # `tools: agy,Claude` or `tools: agy,claude`.
    assert_output_contains "tools: claude,agy"
}

@test "update.sh --dry-run does not modify the target" {
    aak_install --tools claude
    # Capture the post-install state.
    before="$(find "$TARGET" -type f | sort | xargs -I{} sh -c 'stat -c "%Y %n" "$1"' _ {})"
    # Force an UPDATED diff by mutating a managed file in the target.
    echo " " >> "$TARGET/CLAUDE.md"
    run aak_update --dry-run
    assert_success
    assert_output_contains "UPDATED  CLAUDE.md"
    assert_output_contains "Run without --dry-run to apply"
    # The mutated file must NOT have been overwritten by a dry run.
    run grep -c " $" "$TARGET/CLAUDE.md"
    assert_success
    [[ "$output" -ge 1 ]]
}

@test "uninstall.sh --dry-run reports removals without deleting" {
    aak_install --tools claude
    assert_file_exists "$TARGET/CLAUDE.md"
    run aak_uninstall --dry-run
    assert_success
    assert_output_contains "would-remove"
    # CLAUDE.md must survive a dry-run uninstall.
    assert_file_exists "$TARGET/CLAUDE.md"
}

@test "new-skill.sh rejects an invalid skill name" {
    run bash "$KIT_ROOT/scripts/new-skill.sh" --name "Bad_Name"
    assert_failure
    assert_output_contains "skill name must be lowercase"
}

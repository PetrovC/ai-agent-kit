#!/usr/bin/env bats
#
# doctor.sh health diagnostic checks.

load 'bats_helper'

setup() {
    aak_setup
    cp -r "$KIT_ROOT/examples/filled-project/." "$TARGET/"
}

@test "doctor.sh runs on examples/filled-project and exits 0 after install" {
    # Install the kit to make it a fully valid installation
    aak_install --tools claude,codex,agy
    
    run bash "$KIT_ROOT/scripts/doctor.sh" --target "$TARGET"
    assert_success
    assert_output_contains "Diagnostics passed successfully. Target install is healthy."
}

@test "doctor.sh exits 2 when a manifest file is missing" {
    aak_install --tools claude,codex,agy
    
    # Remove one of the files in .kit-manifest to trigger manifest drift / missing file
    rm "$TARGET/CLAUDE.md"
    
    run bash "$KIT_ROOT/scripts/doctor.sh" --target "$TARGET"
    assert_failure
    [[ "$status" -eq 2 ]]
    assert_output_contains "Manifest integrity: Missing file -> CLAUDE.md"
}

@test "doctor.sh exits 1 when a hook is not executable" {
    aak_install --tools claude,codex,agy
    
    # Make one of the hooks non-executable
    chmod -x "$TARGET/.claude/hooks/pre-bash-guard.sh"
    
    run bash "$KIT_ROOT/scripts/doctor.sh" --target "$TARGET"
    assert_failure
    [[ "$status" -eq 1 ]]
    assert_output_contains "Hook executability: Hook is not executable -> .claude/hooks/pre-bash-guard.sh"
}

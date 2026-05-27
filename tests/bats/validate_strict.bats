#!/usr/bin/env bats
#
# validate.sh strict-mode coverage (issue #150).

load 'bats_helper'

setup() {
    aak_setup
    cp -r "$KIT_ROOT/examples/filled-project/." "$TARGET/"
}

_validate() {
    bash "$KIT_ROOT/scripts/validate.sh" "$@"
}

@test "validate.sh enforces router line budget override" {
    cat > "$TARGET/CLAUDE.md" <<'EOF'
line 1
line 2
EOF

    run _validate --target "$TARGET" --router-max-lines 1
    assert_failure
    assert_output_contains "CLAUDE.md has 2 lines; budget is 1"
}

@test "validate.sh --strict fails when update dry-run would modify docs/ai" {
    mkdir -p "$TARGET/scripts" "$TARGET/tooling/claude"
    : > "$TARGET/.kit-manifest"

    cat > "$TARGET/scripts/update.sh" <<'EOF'
#!/usr/bin/env bash
echo "Changes:"
echo "  UPDATED  docs/ai/PROJECT.md"
exit 0
EOF
    chmod +x "$TARGET/scripts/update.sh"

    run _validate --target "$TARGET" --strict
    assert_failure
    assert_output_contains "strict update guard: would modify project-owned path"
    assert_output_contains "docs/ai/PROJECT.md"
}

@test "validate.sh --strict passes when update dry-run avoids project-owned paths" {
    mkdir -p "$TARGET/scripts" "$TARGET/tooling/claude"
    : > "$TARGET/.kit-manifest"

    cat > "$TARGET/scripts/update.sh" <<'EOF'
#!/usr/bin/env bash
echo "Changes:"
echo "  UPDATED  CLAUDE.md"
exit 0
EOF
    chmod +x "$TARGET/scripts/update.sh"

    run _validate --target "$TARGET" --strict
    assert_success
    assert_output_contains "update dry-run preserves docs/ai/ and .mcp.json"
}

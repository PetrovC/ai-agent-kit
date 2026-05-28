#!/usr/bin/env bats
#
# .kit-manifest read/write coverage.
#
# install.sh writes the manifest; update.sh reads it (manifest-diff GC) and
# rewrites it; uninstall.sh consults it to know what to delete. These tests
# pin the cross-script contract so a refactor cannot silently break manifest
# scoping (partial-install merge, manifest-driven uninstall).

load 'bats_helper'

setup() {
    aak_setup
}

@test "install writes a non-empty .kit-manifest and .kit-version" {
    aak_install --tools claude
    assert_file_exists "$TARGET/.kit-manifest"
    assert_file_exists "$TARGET/.kit-version"
    # Manifest must list at least CLAUDE.md and .claude/settings.json — the
    # two anchor entries every Claude install ships.
    run grep -Fx "CLAUDE.md" "$TARGET/.kit-manifest"
    assert_success
    run grep -Fx ".claude/settings.json" "$TARGET/.kit-manifest"
    assert_success
    run grep -Fx ".ai-agent-kit/audit/record-event.sh" "$TARGET/.kit-manifest"
    assert_success
    # Manifest is sorted (LC_ALL=C sort -u) — verify no duplicate lines.
    run bash -c "sort -u '$TARGET/.kit-manifest' | diff -q - '$TARGET/.kit-manifest'"
    assert_success
}

@test "install scopes the manifest to --tools" {
    aak_install --tools claude
    # No codex- or agy-owned paths should appear.
    run grep -E '^AGENTS\.md$|^AGY\.md$|^\.codex/|^\.agents/|^\.agy/' "$TARGET/.kit-manifest"
    [[ "$status" -ne 0 ]] || {
        echo "unexpected non-Claude entries:"
        echo "$output"
        return 1
    }
}

@test "partial install preserves the prior tool's manifest entries" {
    aak_install --tools claude
    before_count="$(wc -l < "$TARGET/.kit-manifest" | tr -d ' ')"
    # Add agy on top — Claude's entries must survive.
    aak_install --tools agy
    run grep -Fx "CLAUDE.md" "$TARGET/.kit-manifest"
    assert_success
    run grep -Fx "AGY.md" "$TARGET/.kit-manifest"
    assert_success
    after_count="$(wc -l < "$TARGET/.kit-manifest" | tr -d ' ')"
    # The manifest must have grown, not been replaced.
    [[ "$after_count" -gt "$before_count" ]] || {
        echo "expected manifest to grow after adding agy: $before_count -> $after_count"
        return 1
    }
    # .kit-version must record the UNION in canonical order.
    run cat "$TARGET/.kit-version"
    assert_success
    assert_output_contains "tools: claude,agy"
}

@test "uninstall reads the manifest and removes only listed files" {
    aak_install --tools claude
    # Drop a user file alongside the installed tree — uninstall must not touch it.
    mkdir -p "$TARGET/.claude/agents"
    user_file="$TARGET/.claude/agents/my-agent.md"
    echo "user-owned" > "$user_file"
    run aak_uninstall --tools claude
    assert_success
    assert_file_missing "$TARGET/CLAUDE.md"
    # The user file survives.
    assert_file_exists "$user_file"
    # Manifest + version files are removed when no tools remain.
    assert_file_missing "$TARGET/.kit-manifest"
    assert_file_missing "$TARGET/.kit-version"
}

@test "partial uninstall rewrites manifest to the remaining tool's entries" {
    aak_install --tools claude,agy
    run aak_uninstall --tools claude
    assert_success
    assert_file_exists "$TARGET/.kit-manifest"
    # Manifest must keep agy entries and drop Claude entries.
    run grep -Fx "AGY.md" "$TARGET/.kit-manifest"
    assert_success
    run grep -Fx "CLAUDE.md" "$TARGET/.kit-manifest"
    assert_failure
    run grep -Fx ".ai-agent-kit/audit/record-event.sh" "$TARGET/.kit-manifest"
    assert_success
    # .kit-version updated to remaining tools only.
    run cat "$TARGET/.kit-version"
    assert_success
    assert_output_contains "tools: agy"
}

@test "full uninstall removes shared audit runtime with the last tool" {
    aak_install --tools codex
    assert_file_exists "$TARGET/.ai-agent-kit/audit/record-event.sh"
    run aak_uninstall --tools codex
    assert_success
    assert_file_missing "$TARGET/.ai-agent-kit/audit/record-event.sh"
    assert_file_missing "$TARGET/.kit-manifest"
    assert_file_missing "$TARGET/.kit-version"
}

@test "official audit opt-in writes global config outside the target project" {
    config_dir="$BATS_TEST_TMPDIR/audit-config"
    config_path="$config_dir/config.json"
    run aak_install --tools codex --audit official --audit-config "$config_path"
    assert_success
    assert_file_exists "$config_path"
    assert_file_missing "$TARGET/.ai-agent-kit/config.json"
    run python - "$config_path" "$TARGET" <<'PY'
import json
import pathlib
import sys
config = json.loads(pathlib.Path(sys.argv[1]).read_text())
target = pathlib.Path(sys.argv[2]).resolve()
runtime = pathlib.Path(config["audit"]["runtime_path"]).resolve()
assert config["audit"]["enabled"] is True
assert config["audit"]["source_project_write_policy"] == "never"
assert target not in (runtime, *runtime.parents)
PY
    assert_success
}

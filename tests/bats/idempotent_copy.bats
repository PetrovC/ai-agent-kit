#!/usr/bin/env bats
#
# Idempotent file-copy contract.
#
# install.sh re-run on a clean install must produce identical output (overwrite
# semantics, no surprise changes). update.sh re-run must report "up to date".
# update.sh against locally-mutated managed files must report UPDATED and
# restore the canonical content. These three properties are the difference
# between a refresh that's safe to run and one that drifts silently.

load 'bats_helper'

setup() {
    aak_setup
}

snapshot_dir() {
    # Stable, content-aware fingerprint of TARGET — sorted relative paths
    # joined with SHA-256 sums. Excludes the .kit-version file because it
    # embeds the install date and intentionally changes on every run.
    (
        cd "$TARGET"
        find . -type f ! -name '.kit-version' -print0 \
            | LC_ALL=C sort -z \
            | xargs -0 sha256sum
    )
}

@test "re-running install on a clean install leaves the same files in place" {
    aak_install --tools claude
    before="$(snapshot_dir)"
    aak_install --tools claude
    after="$(snapshot_dir)"
    [[ "$before" == "$after" ]] || {
        echo "install is not idempotent (file content changed)"
        diff <(echo "$before") <(echo "$after") || true
        return 1
    }
}

@test "update.sh on an unchanged install reports 'up to date'" {
    aak_install --tools claude
    run aak_update
    assert_success
    assert_output_contains "Everything is up to date"
}

@test "update.sh restores a locally-mutated managed file" {
    aak_install --tools claude
    # Mutate CLAUDE.md — update.sh must detect the diff and overwrite.
    canonical="$(cat "$KIT_ROOT/tooling/claude/CLAUDE.md")"
    echo "LOCAL DRIFT" >> "$TARGET/CLAUDE.md"
    run aak_update
    assert_success
    assert_output_contains "UPDATED  CLAUDE.md"
    [[ "$(cat "$TARGET/CLAUDE.md")" == "$canonical" ]] || {
        echo "CLAUDE.md was not restored to canonical content"
        return 1
    }
}

@test "update.sh prunes a manifest-listed file the kit no longer ships" {
    aak_install --tools claude
    # Synthesise a stale manifest entry — a file the kit installed in a prior
    # version but no longer ships. update.sh's manifest-diff GC must prune it.
    stale="$TARGET/.claude/commands/stale-command.md"
    mkdir -p "$(dirname "$stale")"
    echo "stale" > "$stale"
    echo ".claude/commands/stale-command.md" >> "$TARGET/.kit-manifest"
    run aak_update
    assert_success
    assert_output_contains "PRUNED   .claude/commands/stale-command.md"
    assert_file_missing "$stale"
}

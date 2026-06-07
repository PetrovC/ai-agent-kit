#!/usr/bin/env bats
#
# Dogfood content-parity gate (pr-dogfood-parity.yml).
#
# `validate.sh --strict`, run against the repo root, must FAIL when a tracked
# dogfood file drifts from its canonical source under tooling/ or skills/ — the
# class of bug PR #447 fixed (a dropped statusline.sh, a stale .agents-only
# split). That `> Dogfood install drift (repo only)` block only activates on
# this source tree (it needs .kit-manifest + tooling/ + the tracked dogfood
# copies), so it is now run in required CI against the repo root itself
# (pr-dogfood-parity.yml). These tests prove the check trips on drift and stays
# green on a clean tree.

load 'bats_helper'

setup() {
    aak_setup
}

# Export the tracked repo tree (no .git, no worktrees, no untracked runtime
# files) into $1 so the dogfood-drift block has a full source tree to compare.
# The drift block also enforces git-tracked MODE parity via `git ls-files -s`,
# and validate.sh runs with `set -o pipefail`, so a non-git target would make
# that git call abort the whole script (exit 128). Re-init git and stage the
# tree so the mode check has an index to read.
_export_repo() {
    local dst="$1"
    git -C "$KIT_ROOT" archive --format=tar HEAD | tar -x -C "$dst"
    git -C "$dst" init -q
    git -C "$dst" add -A
}

_validate() {
    bash "$KIT_ROOT/scripts/validate.sh" "$@"
}

@test "validate.sh --strict passes on a clean dogfood tree" {
    local clean="$TARGET/clean"
    mkdir -p "$clean"
    _export_repo "$clean"

    run _validate --target "$clean" --strict
    assert_success
    assert_output_contains "dogfood file(s) match source"
}

@test "validate.sh --strict fails when a tracked dogfood skill drifts from source" {
    local drift="$TARGET/drift"
    mkdir -p "$drift"
    _export_repo "$drift"

    # Mutate one tracked dogfood file so it no longer matches its source: a
    # dogfood .claude/skills/<x>/SKILL.md maps to skills/<x>/SKILL.md. Appending
    # a plain line is enough to break the byte-for-byte comparison while leaving
    # the canonical source under skills/ untouched.
    local skill
    skill="$(find "$drift/.claude/skills" -name SKILL.md -type f | head -n1)"
    [ -n "$skill" ] || { echo "no dogfood skill found to mutate"; return 1; }
    printf '\ndrift injected by test\n' >> "$skill"

    run _validate --target "$drift" --strict
    assert_failure
    assert_output_contains "differs from its source under tooling/ or skills/"
}

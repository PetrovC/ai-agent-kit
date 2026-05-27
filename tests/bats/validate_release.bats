#!/usr/bin/env bats
#
# validate.sh — release metadata section (issue #253).
#
# Covers CHANGELOG.md invariants added under the "> Release metadata" section:
#   - exactly one [Unreleased] section
#   - no duplicate version section headings
#   - all version headings use valid format (## [X.Y.Z] or ## [X.Y.Z] - YYYY-MM-DD)
#
# Each test seeds a temp target from examples/filled-project (so the docs/ai/
# template checks pass cleanly) then writes a synthetic CHANGELOG.md.

load 'bats_helper'

setup() {
    aak_setup
    cp -r "$KIT_ROOT/examples/filled-project/." "$TARGET/"
}

_write_changelog() {
    cat > "$TARGET/CHANGELOG.md"
}

_validate() {
    bash "$KIT_ROOT/scripts/validate.sh" --target "$TARGET"
}

# --- No CHANGELOG.md (skip gracefully) ---

@test "validate skips release metadata checks when CHANGELOG.md is absent" {
    run _validate
    assert_success
    assert_output_contains "no CHANGELOG.md"
}

# --- Happy paths ---

@test "validate passes with one [Unreleased] and no versioned sections" {
    _write_changelog <<'EOF'
# Changelog

## [Unreleased]

### Added
- Initial feature.
EOF
    run _validate
    assert_success
    assert_output_contains "[ok] CHANGELOG.md: exactly one [Unreleased] section"
    assert_output_contains "[ok] CHANGELOG.md: no duplicate version sections"
    assert_output_contains "[ok] CHANGELOG.md: all version headings use valid format"
}

@test "validate passes with [Unreleased] and dated versioned sections" {
    _write_changelog <<'EOF'
# Changelog

## [Unreleased]

## [1.1.0] - 2026-05-01

### Changed
- Something changed.

## [1.0.0] - 2026-04-01

### Added
- Initial release.
EOF
    run _validate
    assert_success
    assert_output_contains "[ok] CHANGELOG.md: exactly one [Unreleased] section"
    assert_output_contains "[ok] CHANGELOG.md: no duplicate version sections"
    assert_output_contains "[ok] CHANGELOG.md: all version headings use valid format"
}

@test "validate passes with [Unreleased] and un-dated versioned section" {
    _write_changelog <<'EOF'
# Changelog

## [Unreleased]

## [1.0.0]

### Added
- Initial release.
EOF
    run _validate
    assert_success
    assert_output_contains "[ok] CHANGELOG.md: all version headings use valid format"
}

# --- Failure cases ---

@test "validate fails when CHANGELOG.md has no [Unreleased] section" {
    _write_changelog <<'EOF'
# Changelog

## [1.0.0] - 2026-04-01

### Added
- Initial release.
EOF
    run _validate
    assert_failure
    assert_output_contains "CHANGELOG.md: no [Unreleased] section"
}

@test "validate fails when CHANGELOG.md has two [Unreleased] sections" {
    _write_changelog <<'EOF'
# Changelog

## [Unreleased]

### Added
- First batch.

## [Unreleased]

### Added
- Second batch.
EOF
    run _validate
    assert_failure
    assert_output_contains "[Unreleased] sections (expected exactly 1)"
}

@test "validate fails when CHANGELOG.md has duplicate version sections" {
    _write_changelog <<'EOF'
# Changelog

## [Unreleased]

## [1.0.0] - 2026-04-01

### Added
- Original.

## [1.0.0] - 2026-04-15

### Fixed
- Duplicate.
EOF
    run _validate
    assert_failure
    assert_output_contains "duplicate version section [1.0.0]"
}

@test "validate fails when a version heading has a non-ISO date" {
    _write_changelog <<'EOF'
# Changelog

## [Unreleased]

## [1.0.0] - not-a-date

### Added
- Something.
EOF
    run _validate
    assert_failure
    assert_output_contains "invalid heading format"
}

@test "validate fails when a version heading has extra trailing text" {
    _write_changelog <<'EOF'
# Changelog

## [Unreleased]

## [1.0.0] BREAKING CHANGES

### Added
- Something.
EOF
    run _validate
    assert_failure
    assert_output_contains "invalid heading format"
}

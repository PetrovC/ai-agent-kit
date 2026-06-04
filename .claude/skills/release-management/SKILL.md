---
name: release-management
description: >
  Use when preparing, checking, or cutting a release. Covers SemVer bump rules,
  VERSION file maintenance, CHANGELOG [Unreleased] section, release readiness
  checks, tag naming, and explicit human confirmation before tagging.
---

# Release Management Skill

## Goal

Ensure that release preparation, checks, and tagging are performed safely, consistently, and with explicit human oversight, maintaining clear versioning tracking and a clean history.

---

## Semantic Versioning (SemVer) Rules

Version numbers must strictly follow the `MAJOR.MINOR.PATCH` format (e.g., `1.2.3`):

- **`MAJOR` bump** (e.g., `1.2.3` -> `2.0.0`): Bypasses backwards compatibility. Required when introducing incompatible API or behavioral changes.
- **`MINOR` bump** (e.g., `1.2.3` -> `1.3.0`): Backwards-compatible. Required when adding functionality or features in a backwards-compatible manner.
- **`PATCH` bump** (e.g., `1.2.3` -> `1.2.4`): Backwards-compatible. Required for backwards-compatible bug fixes or minor chores/adjustments.

---

## Single Source of Truth: VERSION File

- The file named `VERSION` at the project root must be the single source of truth for the project's current version.
- The `VERSION` file contains exactly the version string (e.g., `1.2.3`) followed by a single optional newline. No prefix, no extra text.
- Any release step or check must read this file to determine the target version.
- Changes to the project version must be made directly by modifying this file.

---

## CHANGELOG Maintenance and [Unreleased] Promotion

The project maintains a `CHANGELOG.md` tracking all user-facing changes under distinct categories.

- **`[Unreleased]` Section**: All unreleased changes belong here. Keep changes categorized (e.g., `### Added`, `### Changed`, `### Deprecated`, `### Removed`, `### Fixed`, `### Security`).
- **Promotion to a Release**: When cutting a release:
  1. Rename the `[Unreleased]` section to the new version and release date (e.g., `## [1.2.3] - 2026-06-04`).
  2. Create a new empty `## [Unreleased]` section above it with the standard categories so future changes have a place to live.
  3. Ensure the promoted version number matches the value in the `VERSION` file.

---

## Release Readiness Checklist

Before any release is tag-ready, the following validation checks must pass:

1. **Clean Working Tree**: The git working directory must be completely clean (no uncommitted changes, untracked files, or modified tracked files).
2. **Successful Tests**: Run the full test suite and ensure all tests pass.
3. **Non-Empty CHANGELOG**: The changelog must document the changes for the version being released. The promoted release section must not be empty.
4. **VERSION Bumped**: The version in `VERSION` must match the new version string being prepared.

---

## Tag Naming and Git Strategy

- **Tag Naming**: Release tags must be prefixed with `v` (e.g., `vA.B.C` format, such as `v1.2.3`).
- **Scoping**: Keep release changes scoped and reviewable. A release should represent one focused milestone or feature set (typically one PR / concern at a time).

---

## Explicit Human Confirmation and Restrictions

- **Tag Creation**: Explicit human confirmation is required before creating any git release tag. Never tag a commit automatically.
- **Tag Pushing**: Explicit human confirmation is required before pushing any release tag to a remote repository.
- **No Automation**: Never automatically push release tags or perform destructive operations without direct user instruction.
- **No Silent Actions**: Always prompt the user before cutting the release.

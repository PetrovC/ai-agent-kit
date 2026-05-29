---
description: Prepare a release — bump VERSION, update CHANGELOG, run validation. Requires explicit version or bump type.
argument-hint: <version> | patch | minor | major
---

Prepare a release for `$ARGUMENTS`.

Read `docs/ai/RELEASE.md` first for the full release workflow and safety rules.

Steps:
1. Confirm the working tree is clean. Stop if dirty — list the dirty files and exit.
2. Determine the target version:
   - If `$ARGUMENTS` is `patch`, `minor`, or `major`: read `VERSION`, compute the next semver, confirm the result with the user before proceeding.
   - If `$ARGUMENTS` is a semver string (e.g. `1.22.0`): use it directly.
   - Otherwise: stop with — "Invalid argument. Provide a semver string or bump type (patch/minor/major)."
3. For `minor` or `major` bump: stop and ask for explicit user confirmation before modifying any file.
4. Confirm the target version does not already exist as a git tag (`git tag --list`).
5. Update `VERSION`: replace the single line with the new semver string.
6. Update `CHANGELOG.md`:
   - Rename `## [Unreleased]` → `## [X.Y.Z] - YYYY-MM-DD` using today's date.
   - Add a new empty `## [Unreleased]` heading immediately above the new section.
7. Run `bash scripts/validate.sh --target .` and confirm it passes. Stop if it fails.
8. Report the proposed tag command (e.g. `git tag -s vX.Y.Z -m "Release vX.Y.Z"`). Do not run it.
9. Report what to do next (commit the two changed files, push, open a PR, then tag after merge).

Safety rules:
- Never create or push release tags without explicit user instruction.
- Never cut a release with a dirty working tree unless the only dirty files are `VERSION` and `CHANGELOG.md`.
- Never cut a release if `CHANGELOG.md` is malformed or has no `[Unreleased]` section.
- Never cut a release if `VERSION` is malformed.
- Never perform a minor or major release without explicit user confirmation.
- Never guess release notes from unrelated commits.

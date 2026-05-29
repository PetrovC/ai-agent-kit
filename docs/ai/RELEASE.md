# Release

This file documents the release workflow for maintainers and agents.

## Sources of truth

| Source | Role |
|---|---|
| `VERSION` | Single canonical version string (semver). Scripts, plugin manifests, and extension manifests read from this file. |
| `CHANGELOG.md` `[Unreleased]` | Pending release notes. Every PR that changes behavior adds an entry here. |

## Normal workflow

Normal development continues issue-first and PR-first, the same as any other change:

1. Open or reference a GitHub issue.
2. Create a branch.
3. Deliver through a PR.
4. Close the issue when the PR merges.

Release metadata changes follow the same rules: scope them, make them reviewable, keep them in a dedicated PR when possible.

## Release preparation flow

1. **Confirm version.** Agree on the target version (semver) or bump type with the maintainer. Major and minor bumps require explicit human confirmation before any file is changed.
2. **Run release check.** Verify: `VERSION` is a clean semver, `CHANGELOG.md` has exactly one `[Unreleased]` heading, working tree is clean.
3. **Update `VERSION`.** Replace the single line with the new semver.
4. **Move changelog entries.** Rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD`. Add an empty `## [Unreleased]` heading immediately above the new section for the next cycle.
5. **Run validation.** `bash scripts/validate.sh` (and `pwsh scripts/validate.ps1` if applicable).
6. **Record `.verify-state`.** Write a short one-liner to `.verify-state` at the repo root (gitignored) noting the version, date, and result. This is a local signal only; CI is authoritative.
7. **Commit release metadata.** One commit: `chore(release): prepare vX.Y.Z`. The commit must contain only `VERSION`, `CHANGELOG.md`, and `.verify-state`.
8. **Create the tag with explicit human confirmation.** The maintainer runs `git tag -s vX.Y.Z -m "Release vX.Y.Z"` after the PR merges. Agents must not create tags without explicit confirmation.
9. **Push the tag and create the GitHub Release with explicit human confirmation.** The maintainer runs `git push origin vX.Y.Z` and creates the GitHub Release using the changelog section as release notes. Agents must not push tags or create releases without explicit confirmation.

## What agents may do automatically

- Check `VERSION` and `CHANGELOG.md` for well-formedness.
- Propose a target version string.
- Update `VERSION`.
- Move `CHANGELOG.md` `[Unreleased]` entries into the new section with the release date.
- Run `scripts/validate.sh`.
- Write `.verify-state`.
- Prepare a commit with only release metadata files.

## What requires explicit human confirmation

- Bumping the major or minor version number.
- Running `git tag ...` to create a release tag.
- Running `git push origin vX.Y.Z` to push a tag.
- Creating or publishing a GitHub Release.
- Any release operation on a branch that is not the expected release branch.
- Cutting a release when the working tree contains files outside the release metadata set.

## Safety invariants

Agents must refuse to proceed if any of the following are true:

- `VERSION` is missing or not a valid semver.
- `CHANGELOG.md` is missing or has no `[Unreleased]` heading.
- `CHANGELOG.md` has more than one `[Unreleased]` heading.
- A release tag with the target version already exists.
- `HEAD` changed between verification and the release commit.
- The working tree is dirty beyond the intended release metadata files.
- A major or minor bump has not been explicitly confirmed.
- The branch is not the expected release branch.

## CI validation

CI enforces the following invariants on every PR:

- `VERSION` is a clean semver and matches `plugin.json` and `agy-extension.json`.
- `CHANGELOG.md` has exactly one `[Unreleased]` heading with no duplicate version sections.

These checks run in `pr-versioning.yml`. A release PR that fails them cannot merge.

`.verify-state` is a local convenience signal; CI never reads it.

## Tag naming

Tags use the form `vA.B.C` where `A.B.C` matches the content of `VERSION` at time of tagging.

## Related

- [WORKFLOW.md](./WORKFLOW.md) — issue-first, PR-first workflow contract.
- [COMMANDS.md](./COMMANDS.md) — local validation commands.
- [BACKLOG.md](./BACKLOG.md) — open release-related issues.

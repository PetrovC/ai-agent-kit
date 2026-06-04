# Release checklist

Quick checklist for maintainers cutting a release. For the full workflow,
see [RELEASE.md](ai/RELEASE.md). For automated readiness checks, use the
`/release-check` slash command with the `release-management` skill active.

## Pre-flight

- [ ] Working tree is clean (`git status` shows nothing staged or modified)
- [ ] All CI checks green on `master`
- [ ] `VERSION` file contains the correct semver (`cat VERSION`)
- [ ] `CHANGELOG.md` has a populated `[Unreleased]` section (not empty)

## Cut the release

1. **Promote changelog**
   - Rename `## [Unreleased]` → `## [X.Y.Z] - YYYY-MM-DD` (replace with actual
     version from `VERSION` and today's date)
   - Add a fresh empty `## [Unreleased]` section above it
   - Commit: `git commit -am "chore(release): promote CHANGELOG for vX.Y.Z"`

2. **Tag** _(requires explicit confirmation before running)_
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```

3. **GitHub Release** _(requires explicit confirmation before running)_
   ```bash
   gh release create vX.Y.Z --title "vX.Y.Z" --notes-file <(sed -n '/## \[X.Y.Z\]/,/## \[/p' CHANGELOG.md | head -n -1)
   ```
   Or use the GitHub web UI: Releases → Draft a new release → select the tag →
   paste the CHANGELOG section for that version → Publish release.

## Post-release

- [ ] Tag visible: `git tag --list | grep vX.Y.Z`
- [ ] GitHub Release page populated
- [ ] `[Unreleased]` section is empty and ready for the next cycle

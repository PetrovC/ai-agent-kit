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

## Verification

Users can verify the integrity of a release using `SHA256SUMS` published on the Releases page.

```bash
# Verify a specific file (e.g. scripts/install.sh)
sha256sum --check --ignore-missing SHA256SUMS

# Verify the signature with cosign (keyless)
cosign verify-blob SHA256SUMS --bundle SHA256SUMS.bundle \
  --certificate-identity-regexp ".*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"
```

`SHA256SUMS` and `SHA256SUMS.bundle` are automatically generated and uploaded by
the `release-checksums.yml` CI workflow when a release is published.

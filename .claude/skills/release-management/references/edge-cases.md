# Release Management Edge Cases Reference

This reference documents the expected behavior, mitigation steps, and safety checks for release management edge cases.

---

## 1. Missing or Malformed `VERSION` File

- **Symptom**: The `VERSION` file is missing, empty, or the version string is not in the strict `A.B.C` (SemVer) format.
- **Mitigation / Safety Check**:
  - Abort the release process immediately.
  - Alert the user that the `VERSION` file is invalid.
  - Do not attempt to guess the version or read it from other files.
  - Guide the user to recreate or format the `VERSION` file with a valid version (e.g., `1.0.0`).

---

## 2. Missing or Malformed `CHANGELOG.md` `[Unreleased]` Section

- **Symptom**: The `CHANGELOG.md` does not have a `## [Unreleased]` section, or the section is empty (contains no listed changes).
- **Mitigation / Safety Check**:
  - Abort the release process.
  - A release must not proceed if there are no documented changes under `[Unreleased]`.
  - Alert the user and request that they add a summary of changes to the `[Unreleased]` section before proceeding.

---

## 3. Release Tag Already Exists

- **Symptom**: The target release tag (e.g., `v1.2.3`) already exists locally or on the remote repository.
- **Mitigation / Safety Check**:
  - Check for both local tags (`git tag`) and remote tags (`git ls-remote --tags`) before initiating the release.
  - If the tag exists, abort and alert the user.
  - Under no circumstances should tags be force-overwritten (`git tag -f` or `git push -f`) or reused without explicit, deliberate user manual action.

---

## 4. Dirty Working Tree

- **Symptom**: There are uncommitted changes, untracked files, or modified tracked files in the git workspace.
- **Mitigation / Safety Check**:
  - Verify workspace cleanliness with `git status --porcelain` before verifying or cutting the release.
  - If the working tree is dirty, abort and instruct the user to stash, commit, or clean up the changes.
  - Do not create a release tag containing uncommitted or untracked changes.

---

## 5. `HEAD` Drift (HEAD changed after verification but before tag creation)

- **Symptom**: New commits have been pulled, pushed, or committed after the release verification checks passed, but before the git tag is actually created.
- **Mitigation / Safety Check**:
  - Re-verify the current commit hash (`git rev-parse HEAD`) immediately before creating the tag.
  - If the hash differs from the one verified during the readiness checklist, abort the tagging process.
  - Re-run all verification checks and the release readiness checklist on the new HEAD.

---

## 6. Incorrect Release Branch

- **Symptom**: The current branch is not the configured release branch (typically `master` or `main`), or a release is attempted from a feature/bugfix branch.
- **Mitigation / Safety Check**:
  - Check the current active branch using `git branch --show-current`.
  - Unless explicitly instructed otherwise by the user, releases should only be cut from the primary trunk (`master` or `main`).
  - If on an unexpected branch, warn the user and abort the release.

---

## 7. Major or Minor Bump Requested Without Explicit Confirmation

- **Symptom**: The requested version bump is a MAJOR or MINOR change, which introduces new features or breaking changes.
- **Mitigation / Safety Check**:
  - Any MAJOR or MINOR version bump must trigger a high-priority warning to the user.
  - Require explicit, separate confirmation from the user (e.g., typing "yes" or manually confirming) before proceeding with a MAJOR or MINOR bump.
  - Double-check that the `CHANGELOG.md` contains entries justifying the upgrade (e.g., breaking changes highlighted for MAJOR, or new features for MINOR).

---
description: Check release readiness — inspect VERSION, CHANGELOG, and working tree without modifying anything.
---

Check whether this repository is ready to cut a release.

Read `docs/ai/RELEASE.md` first for the full release workflow and safety rules.

Steps:
1. Read `VERSION` and confirm it is a valid semver string (e.g. `1.21.0`).
2. Read `CHANGELOG.md` and confirm exactly one `## [Unreleased]` section exists.
3. Check whether the `[Unreleased]` section has any entries (empty = no pending release notes).
4. Run `git status --porcelain` and confirm the working tree is clean.
5. Run `bash scripts/validate.sh --target .` and capture the result.
6. Identify the expected next version if a bump type is known (patch/minor/major).

Report:
- Current version from `VERSION`.
- CHANGELOG status: number of `[Unreleased]` sections; whether entries are present.
- Working tree: clean or dirty (list dirty files if dirty).
- Validate script: pass or fail (include failure details if failed).
- Release readiness: **ready** or **blocked**.
- Blockers: list each blocker explicitly.
- Recommended next action.

Safety rules:
- Never modify any file.
- Never create tags.
- Never push.
- Never infer release notes from commits.

#!/usr/bin/env python3
"""Aggregate every mandatory CI check on a PR head commit into one gate (#300).

Branch protection requiring each job by name is fragile: rename a job and the
protection silently stops enforcing it. Instead, branch protection requires only
``quality-gate``; this script makes that one check reflect all the others.

It polls the GitHub check-runs API for the PR head SHA until the mandatory checks
are present and every check has completed, then fails if any non-ignored check
did not pass. A *missing* mandatory check fails the gate — that is the safe
behavior when a job is renamed or removed.

Inputs (env): REPO (owner/name), SHA (head commit). Lists are read from
``.github/required-checks.txt`` (mandatory: must be present AND pass) and
``.github/optional-checks.txt`` (ignored: never block). Any other check that is
present must still pass. Tunables: GATE_TIMEOUT (s, default 1800), GATE_INTERVAL
(s, default 20), GATE_NAME (this check's own name, default ``quality-gate``).
"""
from __future__ import annotations

import json
import os
import pathlib
import subprocess
import sys
import time

SELF = os.environ.get("GATE_NAME", "quality-gate")
PASSING = {"success", "skipped", "neutral"}
REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]


def read_list(path: pathlib.Path) -> list[str]:
    """Read non-empty, non-comment lines from a check-list file."""
    if not path.is_file():
        return []
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            out.append(stripped)
    return out


def fetch_checks(repo: str, sha: str) -> list[dict]:
    """Return the check-runs for a commit, excluding this gate itself."""
    result = subprocess.run(
        [
            "gh", "api", "-H", "Accept: application/vnd.github+json",
            f"repos/{repo}/commits/{sha}/check-runs?per_page=100",
        ],
        capture_output=True, text=True, check=True,
    )
    data = json.loads(result.stdout or "{}")
    return [c for c in data.get("check_runs", []) if c.get("name") != SELF]


def all_settled(checks: list[dict], mandatory: list[str]) -> bool:
    """True when every mandatory check is present and no check is still running."""
    names = {c.get("name") for c in checks}
    if any(m not in names for m in mandatory):
        return False
    return all(c.get("status") == "completed" for c in checks)


def evaluate(
    checks: list[dict], mandatory: list[str], ignore: list[str]
) -> list[str]:
    """Return a list of failure reasons; empty means the gate passes."""
    names = {c.get("name") for c in checks}
    ignore_set = set(ignore)
    failures: list[str] = []
    for m in mandatory:
        if m not in names:
            failures.append(f"missing mandatory check (renamed/removed?): {m}")
    for c in checks:
        name = c.get("name")
        if name in ignore_set:
            continue
        if c.get("status") != "completed":
            continue
        conclusion = c.get("conclusion")
        if conclusion not in PASSING:
            failures.append(f"{name} = {conclusion or 'no conclusion'}")
    return failures


def main() -> int:
    repo = os.environ["REPO"]
    sha = os.environ["SHA"]
    mandatory = read_list(REPO_ROOT / ".github" / "required-checks.txt")
    ignore = read_list(REPO_ROOT / ".github" / "optional-checks.txt")
    timeout = int(os.environ.get("GATE_TIMEOUT", "1800"))
    interval = int(os.environ.get("GATE_INTERVAL", "20"))

    deadline = time.time() + timeout
    while True:
        checks = fetch_checks(repo, sha)
        if all_settled(checks, mandatory):
            break
        if time.time() >= deadline:
            print(f"::warning::quality-gate timed out after {timeout}s; evaluating now")
            break
        names = {c.get("name") for c in checks}
        missing = [m for m in mandatory if m not in names]
        running = sum(1 for c in checks if c.get("status") != "completed")
        print(f"waiting: {running} in progress; missing mandatory: {missing or 'none'}")
        time.sleep(interval)

    checks = fetch_checks(repo, sha)
    failures = evaluate(checks, mandatory, ignore)
    if failures:
        print("quality-gate FAILED:")
        for reason in failures:
            print(f"  - {reason}")
        return 1
    print(f"quality-gate passed ({len(checks)} checks evaluated).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

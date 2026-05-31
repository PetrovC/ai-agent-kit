#!/usr/bin/env bats
#
# Install/update audit record coverage (#313). install.sh / update.sh append a
# local NDJSON record of which managed paths were added/updated/pruned/skipped
# at which kit version, so a partial or surprising run can be inspected.

load 'bats_helper'

setup() {
    aak_setup
}

RECORD=".ai-agent-kit/install-audit.ndjson"

@test "install writes an audit record listing managed actions" {
    aak_install --tools claude
    assert_file_exists "$TARGET/$RECORD"
    run python - "$TARGET/$RECORD" <<'PY'
import json, re, sys
lines = [l for l in open(sys.argv[1], encoding="utf-8").read().splitlines() if l.strip()]
assert len(lines) == 1, f"expected 1 run, got {len(lines)}"
r = json.loads(lines[0])
assert r["action"] == "install", r["action"]
assert r["kit_version"], r
assert re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", r["occurred_at"]), r["occurred_at"]
assert r["summary"]["added"] > 0 and r["summary"]["updated"] == 0, r["summary"]
assert r["changes"] and all(set(c) == {"path", "action"} for c in r["changes"]), r["changes"][:2]
PY
    assert_success
}

@test "update appends an update record and a dry-run writes none" {
    aak_install --tools claude
    # Force one managed file to differ so update records an UPDATED action.
    printf '\n# local drift\n' >> "$TARGET/CLAUDE.md"
    aak_update --tools claude
    aak_update --tools claude --dry-run
    run python - "$TARGET/$RECORD" <<'PY'
import json, sys
lines = [l for l in open(sys.argv[1], encoding="utf-8").read().splitlines() if l.strip()]
runs = [json.loads(l) for l in lines]
actions = [r["action"] for r in runs]
assert actions == ["install", "update"], f"dry-run must not append; got {actions}"
assert runs[1]["summary"]["updated"] >= 1, runs[1]["summary"]
PY
    assert_success
}

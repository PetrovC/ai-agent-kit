#!/usr/bin/env bats
#
# Regression tests for .github/scripts/quality_gate.py (#500): the gate must
# judge only the newest run per check name. The check-runs API dedupes per
# check suite, not per name, so a re-triggered batch (e.g. "Update branch"
# cancelling a superseded run) leaves stale cancelled duplicates on the SHA.
# Pure-function tests via importlib — no `gh`, no network.

load 'bats_helper'

GATE=""

setup() {
    aak_setup
    GATE="$KIT_ROOT/.github/scripts/quality_gate.py"
}

# Each test feeds python a program on stdin; $GATE arrives as sys.argv[1].
# Shared module loader prefix:
#   import importlib.util, sys
#   spec = importlib.util.spec_from_file_location("qg", sys.argv[1])
#   qg = importlib.util.module_from_spec(spec); spec.loader.exec_module(qg)

@test "gate passes when a cancelled run is superseded by a newer success (#500)" {
    run python3 - "$GATE" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("qg", sys.argv[1])
qg = importlib.util.module_from_spec(spec); spec.loader.exec_module(qg)
runs = [
    {"name": "lint", "id": 1, "started_at": "2026-06-10T10:00:00Z",
     "status": "completed", "conclusion": "cancelled"},
    {"name": "lint", "id": 2, "started_at": "2026-06-10T10:05:00Z",
     "status": "completed", "conclusion": "success"},
]
failures = qg.evaluate(qg.latest_by_name(runs), ["lint"], [])
assert failures == [], failures
print("PASS")
PY
    assert_success
    assert_output_contains "PASS"
}

@test "gate still fails when the newest run failed despite an older success (#500)" {
    run python3 - "$GATE" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("qg", sys.argv[1])
qg = importlib.util.module_from_spec(spec); spec.loader.exec_module(qg)
runs = [
    {"name": "lint", "id": 1, "started_at": "2026-06-10T10:00:00Z",
     "status": "completed", "conclusion": "success"},
    {"name": "lint", "id": 2, "started_at": "2026-06-10T10:05:00Z",
     "status": "completed", "conclusion": "failure"},
]
failures = qg.evaluate(qg.latest_by_name(runs), ["lint"], [])
assert failures == ["lint = failure"], failures
print("PASS")
PY
    assert_success
    assert_output_contains "PASS"
}

@test "latest_by_name tiebreaks equal timestamps by run id (#500)" {
    run python3 - "$GATE" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("qg", sys.argv[1])
qg = importlib.util.module_from_spec(spec); spec.loader.exec_module(qg)
runs = [
    {"name": "lint", "id": 9, "started_at": "2026-06-10T10:00:00Z",
     "status": "completed", "conclusion": "success"},
    {"name": "lint", "id": 5, "started_at": "2026-06-10T10:00:00Z",
     "status": "completed", "conclusion": "cancelled"},
]
kept = qg.latest_by_name(runs)
assert len(kept) == 1 and kept[0]["id"] == 9, kept
print("PASS")
PY
    assert_success
    assert_output_contains "PASS"
}

@test "all_settled no longer waits on a zombie in-progress duplicate (#500)" {
    run python3 - "$GATE" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("qg", sys.argv[1])
qg = importlib.util.module_from_spec(spec); spec.loader.exec_module(qg)
runs = [
    {"name": "lint", "id": 1, "started_at": "2026-06-10T10:00:00Z",
     "status": "in_progress", "conclusion": None},
    {"name": "lint", "id": 2, "started_at": "2026-06-10T10:05:00Z",
     "status": "completed", "conclusion": "success"},
]
assert qg.all_settled(qg.latest_by_name(runs), ["lint"]) is True
print("PASS")
PY
    assert_success
    assert_output_contains "PASS"
}

@test "missing mandatory check still fails the gate after dedupe" {
    run python3 - "$GATE" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("qg", sys.argv[1])
qg = importlib.util.module_from_spec(spec); spec.loader.exec_module(qg)
runs = [
    {"name": "lint", "id": 1, "started_at": "2026-06-10T10:00:00Z",
     "status": "completed", "conclusion": "success"},
]
failures = qg.evaluate(qg.latest_by_name(runs), ["lint", "tests"], [])
assert failures == ["missing mandatory check (renamed/removed?): tests"], failures
print("PASS")
PY
    assert_success
    assert_output_contains "PASS"
}

@test "optional failing check is still ignored after dedupe" {
    run python3 - "$GATE" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("qg", sys.argv[1])
qg = importlib.util.module_from_spec(spec); spec.loader.exec_module(qg)
runs = [
    {"name": "lint", "id": 1, "started_at": "2026-06-10T10:00:00Z",
     "status": "completed", "conclusion": "success"},
    {"name": "flaky-extra", "id": 2, "started_at": "2026-06-10T10:05:00Z",
     "status": "completed", "conclusion": "failure"},
]
failures = qg.evaluate(qg.latest_by_name(runs), ["lint"], ["flaky-extra"])
assert failures == [], failures
print("PASS")
PY
    assert_success
    assert_output_contains "PASS"
}

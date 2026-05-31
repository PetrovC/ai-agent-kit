#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import datetime as dt
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
from typing import Any

SCHEMA_VERSION = "0.1.0"
DEFAULT_CONFIG_PATH = "~/.ai-agent-kit/config.json"
DEFAULT_BRANCH = "agent-audit-data"
DEFAULT_REMOTE_URL = "https://github.com/PetrovC/ai-agent-kit.git"

EVENT_REQUIRED = {
    "schema_version",
    "event_id",
    "audit_run_id",
    "sequence",
    "occurred_at",
    "event_type",
    "actor_kind",
    "payload",
}

ALLOWED_ACTORS = {"main_agent", "subagent", "system", "hook", "ci", "user"}
ALLOWED_EVENTS = {
    "run.started",
    "run.completed",
    "task.classified",
    "agent.selected",
    "agent.invoked",
    "agent.completed",
    "model.decision",
    "report.evaluated",
    "retry.requested",
    "escalation.started",
    "recommendation.created",
    "blocker.recorded",
    "tool.observed",
    "hook.observed",
    "compact.observed",
    "session.metrics",
}

FORBIDDEN_KEYS = {
    "prompt",
    "prompts",
    "raw_prompt",
    "response",
    "responses",
    "raw_response",
    "content",
    "file_content",
    "file_contents",
    "source",
    "source_code",
    "diff",
    "patch",
    "command",
    "command_output",
    "stdout",
    "stderr",
    "stack_trace",
    "exact_path",
    "file_path",
    "path",
    "repository_url",
    "repo_url",
    "branch_name",
    "issue_title",
    "pull_request_title",
    "secret",
    "credential",
    "credentials",
    "api_key",
    "environment",
    "env",
}

ABSOLUTE_PATH_RE = re.compile(
    r"(^|[\s\"'])((?:[A-Za-z]:\\|/Users/|/home/|/var/|/etc/|\\\\)[^\s\"']+)"
)
URL_RE = re.compile(r"https?://(?:github\.com|gitlab\.com|bitbucket\.org)/", re.I)
SECRET_RE = re.compile(r"(sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9_]{16,})")
SAFE_SEGMENT_RE = re.compile(r"^[A-Za-z0-9._-]+$")


class AuditError(Exception):
    def __init__(self, message: str, code: int = 1) -> None:
        super().__init__(message)
        self.code = code


def utc_now() -> str:
    return (
        dt.datetime.now(dt.UTC)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def read_json_text(text: str, label: str) -> dict[str, Any]:
    try:
        value = json.loads(text)
    except json.JSONDecodeError as exc:
        raise AuditError(f"{label} is not valid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise AuditError(f"{label} must be a JSON object")
    return value


def read_json_file(path: pathlib.Path, label: str) -> dict[str, Any]:
    try:
        return read_json_text(path.read_text(encoding="utf-8"), label)
    except FileNotFoundError as exc:
        raise AuditError(f"{label} not found: {path}", 2) from exc


def resolve_path(value: str) -> pathlib.Path:
    return pathlib.Path(os.path.expandvars(os.path.expanduser(value))).resolve()


def default_config_path() -> pathlib.Path:
    return resolve_path(os.environ.get("AAK_AUDIT_CONFIG", DEFAULT_CONFIG_PATH))


def load_config(config_path: str | None) -> tuple[pathlib.Path, dict[str, Any]]:
    path = resolve_path(config_path) if config_path else default_config_path()
    config = read_json_file(path, "audit config")
    audit = config.get("audit")
    if not isinstance(audit, dict):
        raise AuditError("audit config must contain an 'audit' object", 2)
    if audit.get("enabled") is not True:
        raise AuditError("audit is disabled in global config", 2)
    if audit.get("source_project_write_policy") != "never":
        raise AuditError("audit config must set source_project_write_policy to 'never'")
    if not audit.get("runtime_path"):
        raise AuditError("audit config must set runtime_path")
    if not audit.get("central_repo_path"):
        raise AuditError("audit config must set central_repo_path")
    return path, audit


def is_relative_to(child: pathlib.Path, parent: pathlib.Path) -> bool:
    try:
        child.relative_to(parent)
        return True
    except ValueError:
        return False


def assert_outside_source(
    candidate: pathlib.Path, source_root: pathlib.Path, label: str
) -> None:
    source = source_root.resolve()
    target = candidate.resolve()
    if target == source or is_relative_to(target, source):
        raise AuditError(f"{label} must be outside the source project: {target}")


def normalize_key(key: str) -> str:
    return key.strip().lower().replace("-", "_")


def privacy_scan(value: Any, at: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            normalized = normalize_key(str(key))
            if normalized in FORBIDDEN_KEYS:
                raise AuditError(f"unsafe audit field '{key}' at {at}")
            privacy_scan(child, f"{at}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            privacy_scan(child, f"{at}[{index}]")
    elif isinstance(value, str):
        if ABSOLUTE_PATH_RE.search(value):
            raise AuditError(f"unsafe absolute path-like value at {at}")
        if URL_RE.search(value):
            raise AuditError(f"unsafe repository URL-like value at {at}")
        if SECRET_RE.search(value):
            raise AuditError(f"unsafe secret-like value at {at}")


def validate_event(event: dict[str, Any]) -> None:
    missing = sorted(EVENT_REQUIRED - set(event))
    if missing:
        raise AuditError(f"audit event missing required field(s): {', '.join(missing)}")
    if event["schema_version"] != SCHEMA_VERSION:
        raise AuditError(f"audit event schema_version must be {SCHEMA_VERSION}")
    if not isinstance(event["event_id"], str) or not event["event_id"].strip():
        raise AuditError("audit event event_id must be a non-empty string")
    if not isinstance(event["audit_run_id"], str) or not event["audit_run_id"].strip():
        raise AuditError("audit event audit_run_id must be a non-empty string")
    if not isinstance(event["sequence"], int) or event["sequence"] < 1:
        raise AuditError("audit event sequence must be a positive integer")
    if event["event_type"] not in ALLOWED_EVENTS:
        raise AuditError(f"audit event_type is not controlled: {event['event_type']}")
    if event["actor_kind"] not in ALLOWED_ACTORS:
        raise AuditError(f"audit actor_kind is not controlled: {event['actor_kind']}")
    if not isinstance(event["payload"], dict):
        raise AuditError("audit event payload must be an object")
    privacy_scan(event)


def path_segment(value: str, field: str) -> str:
    sanitized = value.replace(":", "_")
    if not SAFE_SEGMENT_RE.match(sanitized) or sanitized in {".", ".."}:
        raise AuditError(f"{field} is not safe for an audit storage path")
    return sanitized


def runtime_events_path(
    audit: dict[str, Any], source_root: pathlib.Path, run_id: str
) -> pathlib.Path:
    runtime = resolve_path(str(audit["runtime_path"]))
    assert_outside_source(runtime, source_root, "runtime_path")
    return runtime / "runs" / path_segment(run_id, "audit_run_id") / "events.ndjson"


def read_event_input(event_file: str | None) -> dict[str, Any]:
    if event_file:
        return read_json_file(resolve_path(event_file), "audit event")
    text = sys.stdin.read()
    if not text.strip():
        raise AuditError(
            "audit event JSON must be passed on stdin or with --event-file"
        )
    return read_json_text(text, "audit event")


def record_event(args: argparse.Namespace) -> int:
    _, audit = load_config(args.config)
    source_root = resolve_path(args.source_root)
    event = read_event_input(args.event_file)
    validate_event(event)
    output_path = runtime_events_path(audit, source_root, str(event["audit_run_id"]))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(event, sort_keys=True, separators=(",", ":")))
        handle.write("\n")
    print(f"recorded audit event: {output_path}")
    return 0


def emit_event(args: argparse.Namespace) -> int:
    """Build a well-formed governance event from CLI args and record it.

    The active governance loop uses this to emit the richer event types
    (`run.started`/`run.completed`, `agent.selected`/`agent.invoked`/
    `agent.completed`, `task.classified`, `report.evaluated`,
    `recommendation.created`). Run linking is by `audit_run_id`: pass
    `--run-id` or set `AAK_AUDIT_RUN_ID` so emitted events join the same run
    folder as the hook-emitted activity events. The wrappers are fail-open, so
    a failure here never changes default agent behavior.
    """
    _, audit = load_config(args.config)
    source_root = resolve_path(args.source_root)
    run_id = args.run_id or os.environ.get("AAK_AUDIT_RUN_ID")
    if not run_id:
        raise AuditError("emit-event requires --run-id or AAK_AUDIT_RUN_ID")
    # --payload-b64 carries the JSON base64-encoded so callers (notably the
    # PowerShell wrapper) avoid native double-quote mangling; --payload is the
    # plain form for shells that quote reliably.
    payload_text = args.payload
    if args.payload_b64:
        try:
            payload_text = base64.b64decode(args.payload_b64).decode("utf-8")
        except (ValueError, UnicodeDecodeError) as exc:
            raise AuditError(f"--payload-b64 is not valid base64 UTF-8: {exc}") from exc
    try:
        payload = json.loads(payload_text) if payload_text else {}
    except json.JSONDecodeError as exc:
        raise AuditError(f"payload is not valid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise AuditError("--payload must be a JSON object")
    if args.invocation_id:
        payload.setdefault("invocation_id", args.invocation_id)
    sequence = int(dt.datetime.now(dt.UTC).timestamp() * 1_000_000)
    event = {
        "schema_version": SCHEMA_VERSION,
        "event_id": args.event_id or f"evt_{sequence}",
        "audit_run_id": run_id,
        "sequence": sequence,
        "occurred_at": utc_now(),
        "event_type": args.event_type,
        "actor_kind": args.actor_kind,
        "invocation_id": args.invocation_id,
        "payload": payload,
    }
    validate_event(event)
    output_path = runtime_events_path(audit, source_root, run_id)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(event, sort_keys=True, separators=(",", ":")))
        handle.write("\n")
    print(f"emitted audit event {args.event_type}: {output_path}")
    return 0


def run_git(
    repo: pathlib.Path, *args: str, check: bool = True
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", *args],
        cwd=str(repo),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if check and result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise AuditError(f"git {' '.join(args)} failed: {detail}")
    return result


def ensure_central_repo(
    audit: dict[str, Any], source_root: pathlib.Path
) -> pathlib.Path:
    central = resolve_path(str(audit["central_repo_path"]))
    assert_outside_source(central, source_root, "central_repo_path")
    if not central.exists():
        remote = str(audit.get("official_remote_url") or DEFAULT_REMOTE_URL)
        branch = str(audit.get("branch") or DEFAULT_BRANCH)
        central.parent.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(
            ["git", "clone", "--quiet", "--branch", branch, remote, str(central)],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if result.returncode != 0:
            detail = (result.stderr or result.stdout).strip()
            raise AuditError(
                "central audit repo is missing and could not be cloned; "
                f"no source project writes were attempted. Git said: {detail}"
            )
    if not (central / ".git").exists():
        raise AuditError(f"central_repo_path must be a git repository: {central}")
    return central


def ensure_audit_branch(repo: pathlib.Path, audit: dict[str, Any]) -> str:
    branch = str(audit.get("branch") or DEFAULT_BRANCH)
    current = run_git(repo, "symbolic-ref", "--quiet", "--short", "HEAD", check=False)
    if current.returncode != 0:
        raise AuditError("central audit repo must be on a named branch")
    current_branch = current.stdout.strip()
    if current_branch != branch:
        raise AuditError(
            f"central audit repo must be on '{branch}', not '{current_branch}'. "
            "Refusing to write audit data to a code branch."
        )
    return branch


def load_events(path: pathlib.Path) -> list[dict[str, Any]]:
    if not path.exists():
        raise AuditError(f"runtime event stream not found: {path}")
    events: list[dict[str, Any]] = []
    for line_number, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not line.strip():
            continue
        event = read_json_text(line, f"{path}:{line_number}")
        validate_event(event)
        events.append(event)
    if not events:
        raise AuditError("runtime event stream is empty")
    return events


def find_payload_value(events: list[dict[str, Any]], key: str, default: Any) -> Any:
    for event in events:
        payload = event.get("payload", {})
        if isinstance(payload, dict) and key in payload:
            return payload[key]
    return default


def event_count(events: list[dict[str, Any]], event_type: str) -> int:
    return sum(1 for event in events if event.get("event_type") == event_type)


def run_period(events: list[dict[str, Any]]) -> tuple[str, str]:
    timestamp = str(events[-1].get("occurred_at") or utc_now())
    match = re.match(r"^(\d{4})-(\d{2})-", timestamp)
    if not match:
        now = utc_now()
        return now[0:4], now[5:7]
    return match.group(1), match.group(2)


def write_json(path: pathlib.Path, value: dict[str, Any]) -> None:
    privacy_scan(value)
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def write_text(path: pathlib.Path, value: str) -> None:
    privacy_scan({"markdown": value})
    path.write_text(value, encoding="utf-8")


INVOCATION_EVENT_TYPES = ("agent.selected", "agent.invoked", "agent.completed")
INVOCATION_PAYLOAD_FIELDS = (
    "parent_invocation_id",
    "agent_key",
    "agent_category",
    "provider",
    "model_tier",
    "assigned_task",
    "selection_reason",
    "status",
    "result_summary",
    "retry_of_invocation_id",
    "escalated_to_invocation_id",
)


def parse_timestamp(value: Any) -> dt.datetime | None:
    try:
        return dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None


def duration_ms(start: Any, end: Any) -> int | None:
    started = parse_timestamp(start)
    ended = parse_timestamp(end)
    if started is None or ended is None:
        return None
    delta = int((ended - started).total_seconds() * 1000)
    return delta if delta >= 0 else None


def build_invocations(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Aggregate agent.selected/invoked/completed events into invocation records."""
    records: dict[str, dict[str, Any]] = {}
    order: list[str] = []
    for event in events:
        if event.get("event_type") not in INVOCATION_EVENT_TYPES:
            continue
        payload = event.get("payload") if isinstance(event.get("payload"), dict) else {}
        key = (
            event.get("invocation_id")
            or payload.get("invocation_id")
            or f"inv_{event.get('sequence')}"
        )
        record = records.get(key)
        if record is None:
            record = {"invocation_id": key}
            records[key] = record
            order.append(key)
        for field in INVOCATION_PAYLOAD_FIELDS:
            if field in payload:
                record[field] = payload[field]
        occurred_at = event.get("occurred_at")
        if event.get("event_type") in ("agent.selected", "agent.invoked"):
            record.setdefault("started_at", occurred_at)
        elif event.get("event_type") == "agent.completed":
            record["completed_at"] = occurred_at
    invocations: list[dict[str, Any]] = []
    for key in order:
        record = records[key]
        record.setdefault("parent_invocation_id", None)
        record.setdefault("agent_key", "unknown")
        record.setdefault("agent_category", "other")
        record.setdefault(
            "status", "success" if "completed_at" in record else "stopped"
        )
        if "duration_ms" not in record:
            span = duration_ms(record.get("started_at"), record.get("completed_at"))
            if span is not None:
                record["duration_ms"] = span
        invocations.append(record)
    return invocations


def build_recommendations(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Surface recommendation.created payloads (privacy-scanned at record time)."""
    recommendations: list[dict[str, Any]] = []
    for event in events:
        if event.get("event_type") != "recommendation.created":
            continue
        payload = event.get("payload") if isinstance(event.get("payload"), dict) else {}
        record: dict[str, Any] = {"recommendation_id": event.get("event_id")}
        record.update(payload)
        recommendations.append(record)
    return recommendations


# --- Governance scoring (#310) -------------------------------------------
# Deterministic implementation of docs/ai/AGENT_AUDIT_GOVERNANCE.md. The
# formulas and tables in that document are canonical; all inputs come from
# sanitized stored metadata only (no raw prompts, responses, or paths).

QUALITY_PENALTIES: dict[str, float] = {
    "missing_direct_answer": 3.0,
    "missing_evidence": 2.0,
    "missing_next_action": 1.5,
    "unsafe_detail": 4.0,
    "excessive_noise": 2.0,
    "unverified_conclusion": 1.5,
    "duplicated_report": 2.0,
    "contradictory_status": 2.0,
}

# Quality categories by score band: (inclusive_low, category, default_action).
QUALITY_BANDS: tuple[tuple[float, str, str], ...] = (
    (8.0, "accepted", "accept"),
    (6.0, "weak", "repair"),
    (3.0, "unusable", "retry_narrower"),
    (0.0, "failed", "reject"),
)

TIER_RANK: dict[str, int] = {"fast": 0, "standard": 1, "review": 2, "deep": 3}
HIGH_TIER_TASKS = {
    "security_review",
    "architecture_review",
    "pr_review",
    "code_review",
    "decision_bearing_investigation",
}
LOW_TIER_TASKS = {
    "formatting",
    "fixture_update",
    "mechanical_edit",
    "parse_validation",
}
HIGH_TIER_CATEGORIES = {"security", "architecture", "review", "code_review"}


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _as_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def target_report_tokens(
    audit: dict[str, Any] | None, events: list[dict[str, Any]]
) -> int | None:
    """Resolve the configured report-token target, or None when unavailable."""
    governance = {}
    if isinstance(audit, dict) and isinstance(audit.get("governance"), dict):
        governance = audit["governance"]
    candidate = governance.get("target_report_tokens")
    if candidate is None:
        candidate = find_payload_value(events, "target_report_tokens", None)
    if candidate is None:
        return None
    value = _as_int(candidate, 0)
    return value if value > 0 else None


def compute_noise_score(
    events: list[dict[str, Any]],
    invocations: list[dict[str, Any]],
    target_tokens: int | None,
) -> dict[str, Any]:
    """Deterministic 0-10 noise score; higher means more avoidable waste."""
    inputs: dict[str, Any] = {
        "repeated_read_count": _as_int(
            find_payload_value(events, "repeated_read_count", 0)
        ),
        "large_output_event_count": _as_int(
            find_payload_value(events, "large_output_event_count", 0)
        ),
        "truncated_output_count": _as_int(
            find_payload_value(events, "truncated_output_count", 0)
        ),
        "retry_count": event_count(events, "retry.requested"),
        "subagent_invocation_count": event_count(events, "agent.invoked"),
        "expected_subagent_count": _as_int(
            find_payload_value(events, "expected_subagent_count", 0)
        ),
        "report_tokens": find_payload_value(events, "report_tokens", None),
        "target_report_tokens": target_tokens,
        "scope_narrowing_count": _as_int(
            find_payload_value(events, "scope_narrowing_count", 0)
        ),
        "rework_detected": bool(find_payload_value(events, "rework_detected", False)),
    }

    components: dict[str, Any] = {
        "repeated_read_component": min(2.0, inputs["repeated_read_count"] * 0.4),
        "large_output_component": min(
            2.0,
            inputs["large_output_event_count"] * 0.7
            + inputs["truncated_output_count"] * 0.5,
        ),
        "retry_component": min(2.0, inputs["retry_count"] * 0.8),
        "subagent_component": min(
            1.5,
            max(0, inputs["subagent_invocation_count"] - inputs["expected_subagent_count"])
            * 0.5,
        ),
        "scope_churn_component": min(
            1.0,
            inputs["scope_narrowing_count"] * 0.5
            + (1 if inputs["rework_detected"] else 0) * 0.5,
        ),
    }

    report_tokens = inputs["report_tokens"]
    if target_tokens and report_tokens is not None:
        verbosity = min(
            1.5,
            max(0.0, (_as_float(report_tokens) - target_tokens) / target_tokens),
        )
        components["verbosity_component"] = round(verbosity, 4)
        verbosity_value = verbosity
    else:
        # Spec: record verbosity as unavailable rather than guessing.
        components["verbosity_component"] = None
        verbosity_value = 0.0

    total = verbosity_value + sum(
        value
        for key, value in components.items()
        if key != "verbosity_component" and isinstance(value, (int, float))
    )
    score = round(min(10.0, total), 1)
    level = "low" if score < 3.0 else "medium" if score < 6.0 else "high"
    return {
        "noise_score": score,
        "noise_level": level,
        "components": components,
        "inputs": inputs,
    }


def compute_quality_score(events: list[dict[str, Any]]) -> dict[str, Any]:
    """Deterministic 0-10 quality score from sanitized evidence flags."""
    next_action_expected = bool(
        find_payload_value(events, "next_action_expected", False)
    )
    checks: list[tuple[str, bool]] = [
        (
            "missing_direct_answer",
            not bool(find_payload_value(events, "answered_assigned_task", True)),
        ),
        (
            "missing_evidence",
            not bool(find_payload_value(events, "has_sanitized_evidence", True)),
        ),
        (
            "missing_next_action",
            next_action_expected
            and not bool(find_payload_value(events, "has_next_action", False)),
        ),
        (
            "unsafe_detail",
            bool(find_payload_value(events, "unsafe_detail_detected", False)),
        ),
        ("excessive_noise", bool(find_payload_value(events, "off_scope", False))),
        (
            "unverified_conclusion",
            bool(find_payload_value(events, "unverified_conclusion", False)),
        ),
        (
            "duplicated_report",
            bool(find_payload_value(events, "duplicated_report", False)),
        ),
        (
            "contradictory_status",
            bool(find_payload_value(events, "contradictory_status", False)),
        ),
    ]
    weaknesses = [code for code, hit in checks if hit]
    penalty = sum(QUALITY_PENALTIES[code] for code in weaknesses)
    score = round(max(0.0, 10.0 - penalty), 1)
    category, action = "failed", "reject"
    for low, cat, act in QUALITY_BANDS:
        if score >= low:
            category, action = cat, act
            break
    return {
        "quality_score": score,
        "quality_category": category,
        "default_action": action,
        "weaknesses": weaknesses,
    }


def expected_model_tier(
    task_type: str, risk_level: str, agent_category: str = "other"
) -> str:
    if (
        task_type in HIGH_TIER_TASKS
        or agent_category in HIGH_TIER_CATEGORIES
        or risk_level in {"high", "critical"}
    ):
        return "review"
    if task_type in LOW_TIER_TASKS:
        return "fast"
    return "standard"


def detect_model_fit(
    events: list[dict[str, Any]],
    task_type: str,
    risk_level: str,
    complexity: str,
    quality_category: str,
    retry_count: int,
    escalation_count: int,
) -> dict[str, Any]:
    """Advisory model-fit detection. Never hard-blocks a model choice."""
    observed = str(
        find_payload_value(
            events,
            "observed_model_tier",
            find_payload_value(events, "model_tier", "unknown"),
        )
    )
    agent_category = str(find_payload_value(events, "agent_category", "other"))
    expected = expected_model_tier(task_type, risk_level, agent_category)
    # Without any task or agent classification there is not enough evidence to
    # judge model fit; report appropriate rather than emit a false signal.
    if task_type == "other" and agent_category == "other":
        return {
            "model_fit": "appropriate",
            "confidence": "low",
            "evidence_strength": "weak",
            "observed_model_tier": observed,
            "expected_model_tier": expected,
        }
    if observed not in TIER_RANK:
        return {
            "model_fit": "unknown",
            "confidence": "low",
            "evidence_strength": "weak",
            "observed_model_tier": observed,
            "expected_model_tier": expected,
        }
    observed_rank, expected_rank = TIER_RANK[observed], TIER_RANK[expected]
    reasoning_failed = quality_category in {"unusable", "failed"}
    needed_recovery = retry_count > 0 or escalation_count > 0
    fit = "appropriate"
    confidence, strength = "medium", "moderate"
    if observed_rank < expected_rank and (reasoning_failed or needed_recovery):
        fit = "underpowered"
        if reasoning_failed and needed_recovery:
            confidence, strength = "high", "strong"
    elif (
        observed_rank > expected_rank
        and quality_category == "accepted"
        and not needed_recovery
        and (complexity in {"trivial", "small"} or risk_level == "low")
    ):
        fit = "overkill"
        confidence, strength = "medium", "moderate"
    return {
        "model_fit": fit,
        "confidence": confidence,
        "evidence_strength": strength,
        "observed_model_tier": observed,
        "expected_model_tier": expected,
    }


def build_governance(
    events: list[dict[str, Any]],
    invocations: list[dict[str, Any]],
    audit: dict[str, Any] | None,
    task_type: str,
    risk_level: str,
    complexity: str,
    validation_state: str,
) -> dict[str, Any]:
    """Compute report-quality, noise, model-fit, and recommendations."""
    retry_count = event_count(events, "retry.requested")
    escalation_count = event_count(events, "escalation.started")
    noise = compute_noise_score(
        events, invocations, target_report_tokens(audit, events)
    )
    quality = compute_quality_score(events)
    model_fit = detect_model_fit(
        events,
        task_type,
        risk_level,
        complexity,
        quality["quality_category"],
        retry_count,
        escalation_count,
    )

    report_quality = {
        "schema_version": SCHEMA_VERSION,
        "quality_score": quality["quality_score"],
        "quality_category": quality["quality_category"],
        "default_action": quality["default_action"],
        "weaknesses": quality["weaknesses"],
        "noise_score": noise["noise_score"],
        "noise_level": noise["noise_level"],
        "noise_components": noise["components"],
        "noise_inputs": noise["inputs"],
        "model_fit": model_fit["model_fit"],
        "evidence_strength": model_fit["evidence_strength"],
        "confidence": model_fit["confidence"],
        "validation_state": validation_state,
        "decision_log": [
            {
                "decision": quality["default_action"],
                "reason": (
                    "required_evidence_present"
                    if quality["quality_category"] == "accepted"
                    else "; ".join(quality["weaknesses"]) or "quality_below_threshold"
                ),
            }
        ],
        "warnings": (
            ["high_noise"] if noise["noise_level"] == "high" else []
        ),
    }

    recommendations = build_recommendations(events)
    recommendations.extend(
        derive_recommendations(noise, quality, model_fit, task_type)
    )
    return {
        "report_quality": report_quality,
        "recommendations": recommendations,
    }


def derive_recommendations(
    noise: dict[str, Any],
    quality: dict[str, Any],
    model_fit: dict[str, Any],
    task_type: str,
) -> list[dict[str, Any]]:
    """Generate machine-readable recommendations for documented triggers."""
    derived: list[dict[str, Any]] = []
    fit = model_fit["model_fit"]
    if fit in {"underpowered", "overkill"}:
        action = "raise_model_tier" if fit == "underpowered" else "lower_model_tier"
        strength = model_fit["evidence_strength"]
        confidence = model_fit["confidence"]
        should_open = (
            strength == "strong"
            or confidence == "high"
            or fit == "underpowered"  # model routing is policy-affecting
        )
        derived.append(
            {
                "recommendation_id": f"rec_model_fit_{fit}",
                "category": "model_routing",
                "summary_code": f"{fit}_model_for_{task_type}",
                "recommended_action": "review_policy" if should_open else "monitor",
                "evidence_strength": strength,
                "confidence": confidence,
                "human_review_required": True,
                "task_type": task_type,
                "observed_model_tier": model_fit["observed_model_tier"],
                "expected_model_tier": model_fit["expected_model_tier"],
                "observed_failures": quality["weaknesses"],
                "issue_candidate": {
                    "should_open_issue": should_open,
                    "reason": (
                        "high_risk_underpowered_model"
                        if fit == "underpowered"
                        else "possible_overkill_model"
                    ),
                    "suggested_action": action,
                },
            }
        )
    if noise["noise_level"] == "high":
        derived.append(
            {
                "recommendation_id": "rec_noise_high",
                "category": "prompt_scope",
                "summary_code": "high_noise_avoidable_context_waste",
                "recommended_action": "tighten_prompt",
                "evidence_strength": "moderate",
                "confidence": "medium",
                "human_review_required": False,
                "task_type": task_type,
                "issue_candidate": {
                    "should_open_issue": False,
                    "reason": "single_run_noise_signal",
                },
            }
        )
    return derived


def recommendations_markdown(recommendations: list[dict[str, Any]]) -> str:
    if not recommendations:
        return (
            "# Governance Recommendations\n\n"
            "No automated recommendation was generated for this run.\n"
        )
    lines = ["# Governance Recommendations", ""]
    for rec in recommendations:
        rec_id = rec.get("recommendation_id", "rec")
        category = rec.get("category", "unknown")
        action = rec.get("recommended_action", "monitor")
        confidence = rec.get("confidence", "low")
        strength = rec.get("evidence_strength", "weak")
        lines.append(
            f"- **{rec_id}** ({category}): `{action}` "
            f"— confidence {confidence}, evidence {strength}."
        )
    lines.append("")
    return "\n".join(lines)


# --- Session-metrics import (#327) ---------------------------------------
# Derive anonymized performance metrics (tokens, cache, speed, duration,
# context exhaustion) from a provider session transcript. ONLY numeric/enum
# metrics and the model id leave the parser — raw prompts, responses, file
# contents, cwd, branch names, and repo URLs are never read into the event.
# validate_event() runs privacy_scan on the result as a backstop.

# List price (USD per million tokens): (input, output). Cache reads are billed
# below input list price; this estimate bills cache reads at input price as a
# conservative upper bound. Source: platform.claude.com/docs/.../pricing.
MODEL_PRICING_USD: dict[str, tuple[float, float]] = {
    "claude-opus-4-8": (5.0, 25.0),
    "claude-opus-4-7": (5.0, 25.0),
    "claude-opus-4-6": (5.0, 25.0),
    "claude-sonnet-4-6": (3.0, 15.0),
    "claude-sonnet-4-5": (3.0, 15.0),
    "claude-haiku-4-5": (1.0, 5.0),
}


def _metric_int(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def parse_claude_transcript(path: pathlib.Path) -> dict[str, Any]:
    """Anonymized metric extraction from a Claude Code `.jsonl` transcript."""
    tok = {"input": 0, "output": 0, "cache_creation": 0, "cache_read": 0}
    speeds: list[float] = []
    timestamps: list[str] = []
    turns = {"user": 0, "assistant": 0, "tool_results": 0}
    tool_calls = 0
    compaction_count = 0
    tokens_before_first_compaction: int | None = None
    peak_request_input = 0
    sidechain_turns = 0
    sidechain_output = 0
    retries = 0
    api_errors = 0
    stop_reasons: dict[str, int] = {}
    models: dict[str, int] = {}

    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(entry, dict):
            continue
        etype = entry.get("type")
        ts = entry.get("timestamp")
        if isinstance(ts, str):
            timestamps.append(ts)
        if _metric_int(entry.get("retryAttempt")) > 0:
            retries += 1
        if entry.get("apiErrorStatus") or entry.get("isApiErrorMessage"):
            api_errors += 1
        if etype == "compact" or entry.get("subtype") == "compact_boundary" or entry.get("isCompactSummary"):
            compaction_count += 1
            if tokens_before_first_compaction is None:
                tokens_before_first_compaction = tok["input"] + tok["output"]
        is_sidechain = bool(entry.get("isSidechain"))
        if etype == "user":
            turns["user"] += 1
        elif etype == "assistant":
            turns["assistant"] += 1
            if is_sidechain:
                sidechain_turns += 1
        if entry.get("toolUseResult") is not None:
            turns["tool_results"] += 1
        if entry.get("toolUseID"):
            tool_calls += 1
        message = entry.get("message") if isinstance(entry.get("message"), dict) else {}
        usage = message.get("usage") if isinstance(message.get("usage"), dict) else None
        if usage:
            it = _metric_int(usage.get("input_tokens"))
            ot = _metric_int(usage.get("output_tokens"))
            cc = _metric_int(usage.get("cache_creation_input_tokens"))
            cr = _metric_int(usage.get("cache_read_input_tokens"))
            tok["input"] += it
            tok["output"] += ot
            tok["cache_creation"] += cc
            tok["cache_read"] += cr
            peak_request_input = max(peak_request_input, it + cc + cr)
            if is_sidechain:
                sidechain_output += ot
            spd = usage.get("speed")
            if isinstance(spd, (int, float)) and spd > 0:
                speeds.append(float(spd))
        model = message.get("model")
        if isinstance(model, str) and model and model != "<synthetic>":
            models[model] = models.get(model, 0) + 1
        stop = entry.get("stopReason") or message.get("stop_reason")
        if isinstance(stop, str) and stop:
            stop_reasons[stop] = stop_reasons.get(stop, 0) + 1

    parsed_times = sorted(t for t in (parse_timestamp(x) for x in timestamps) if t)
    duration = (
        int((parsed_times[-1] - parsed_times[0]).total_seconds())
        if len(parsed_times) >= 2
        else None
    )
    total = sum(tok.values())
    cache_base = tok["input"] + tok["cache_read"]
    cache_hit_ratio = round(tok["cache_read"] / cache_base, 4) if cache_base else 0.0
    model = max(models, key=lambda k: models[k]) if models else "unknown"
    avg_speed = round(sum(speeds) / len(speeds), 2) if speeds else None
    price = MODEL_PRICING_USD.get(model)
    cost = (
        round(
            (tok["input"] + tok["cache_creation"] + tok["cache_read"]) / 1_000_000 * price[0]
            + tok["output"] / 1_000_000 * price[1],
            4,
        )
        if price
        else None
    )
    return {
        "provider": "claude",
        "model": model,
        "tokens": {**tok, "total": total, "cache_hit_ratio": cache_hit_ratio},
        "speed": {"avg_tokens_per_sec": avg_speed, "samples": len(speeds)},
        "duration_seconds": duration,
        "turns": turns,
        "tool_calls": {"total": tool_calls},
        "compaction": {
            "count": compaction_count,
            "tokens_before_first": tokens_before_first_compaction,
        },
        "context": {"peak_request_input_tokens": peak_request_input},
        "subagent": {
            "sidechain_assistant_turns": sidechain_turns,
            "sidechain_output_tokens": sidechain_output,
        },
        "reliability": {
            "retries": retries,
            "api_errors": api_errors,
            "stop_reasons": stop_reasons,
        },
        "cost_estimate": {
            "currency": "USD",
            "amount": cost,
            "basis": "list-price-approximation",
        },
    }


TRANSCRIPT_PARSERS = {"claude": parse_claude_transcript}


def import_session_metrics(args: argparse.Namespace) -> int:
    """Parse a provider session transcript into one anonymized `session.metrics`
    event. Local CLI transcripts only; nothing is read into the event except
    numeric/enum metrics and the model id."""
    _, audit = load_config(args.config)
    source_root = resolve_path(args.source_root)
    run_id = args.run_id or os.environ.get("AAK_AUDIT_RUN_ID")
    if not run_id:
        raise AuditError("import-session-metrics requires --run-id or AAK_AUDIT_RUN_ID")
    parser = TRANSCRIPT_PARSERS.get(args.provider)
    if parser is None:
        raise AuditError(
            f"unsupported provider '{args.provider}'; supported: "
            + ", ".join(sorted(TRANSCRIPT_PARSERS))
        )
    transcript = resolve_path(args.transcript)
    if not transcript.is_file():
        raise AuditError(f"transcript not found: {transcript}")
    metrics = parser(transcript)
    sequence = int(dt.datetime.now(dt.UTC).timestamp() * 1_000_000)
    event = {
        "schema_version": SCHEMA_VERSION,
        "event_id": f"evt_metrics_{sequence}",
        "audit_run_id": run_id,
        "sequence": sequence,
        "occurred_at": utc_now(),
        "event_type": "session.metrics",
        "actor_kind": "system",
        "invocation_id": None,
        "payload": metrics,
    }
    validate_event(event)  # privacy_scan backstop against any leaked field
    output_path = runtime_events_path(audit, source_root, run_id)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(event, sort_keys=True, separators=(",", ":")))
        handle.write("\n")
    tokens = metrics["tokens"]
    print(
        f"imported session.metrics ({args.provider}, {metrics['model']}): "
        f"{tokens['total']} tokens, cache_hit={tokens['cache_hit_ratio']} -> {output_path}"
    )
    return 0


def session_metrics_payload(events: list[dict[str, Any]]) -> dict[str, Any] | None:
    """Latest session.metrics payload, or None."""
    for event in reversed(events):
        if event.get("event_type") == "session.metrics":
            payload = event.get("payload")
            return payload if isinstance(payload, dict) else None
    return None


def build_artifacts(
    events: list[dict[str, Any]],
    run_id: str,
    audit: dict[str, Any] | None = None,
) -> dict[str, Any]:
    generated_at = utc_now()
    invocations = build_invocations(events)
    session_metrics = session_metrics_payload(events)
    project_hash = str(
        find_payload_value(events, "project_hash", "hmac_sha256_unavailable")
    )
    status = str(find_payload_value(events, "status", "completed_with_warnings"))
    validation_state = str(
        find_payload_value(events, "validation_state", "unavailable")
    )
    task_type = str(find_payload_value(events, "task_type", "other"))
    risk_level = str(find_payload_value(events, "risk_level", "low"))
    complexity = str(find_payload_value(events, "complexity", "small"))
    technical_scopes = find_payload_value(events, "technical_scopes", ["unknown"])
    if not isinstance(technical_scopes, list):
        technical_scopes = ["unknown"]

    governance = build_governance(
        events, invocations, audit, task_type, risk_level, complexity, validation_state
    )
    recommendations = governance["recommendations"]

    summary = {
        "schema_version": SCHEMA_VERSION,
        "audit_run_id": run_id,
        "generated_at": generated_at,
        "project_ref": {
            "project_hash": project_hash,
            "hash_salt_scope": "local-only",
            "project_kind": "repository",
        },
        "task_profile": {
            "task_type": task_type,
            "technical_scopes": technical_scopes,
            "risk_level": risk_level,
            "complexity": complexity,
            "expected_outputs": find_payload_value(
                events, "expected_outputs", ["unknown"]
            ),
        },
        "status": status,
        "outcome": {
            "validation_state": validation_state,
            "recommendation_count": len(recommendations),
            "merged": bool(find_payload_value(events, "merged", False)),
        },
        "activity_summary": {
            "tool_call_count": event_count(events, "tool.observed"),
            "hook_event_count": event_count(events, "hook.observed")
            + event_count(events, "compact.observed"),
        },
        "friction_summary": {
            "retry_count": event_count(events, "retry.requested"),
            "blocker_count": event_count(events, "blocker.recorded"),
            "escalation_count": event_count(events, "escalation.started"),
        },
        "artifacts": {
            "events": "governance-events.ndjson",
            "token_context": "token-context.json",
            "invocations": "agent-invocations.json",
            "friction": "friction.json",
            "activity": "activity.json",
            "report_quality": "report-quality.json",
            "governance_recommendations": "governance-recommendations.json",
            "pricing": "pricing-estimate.json",
            "recommendations": "recommendations.md",
        },
        "privacy": {
            "redaction_status": "complete",
            "dropped_field_count": 0,
            "contains_raw_content": False,
            "exact_paths_allowed": False,
        },
    }

    artifacts = {
        "run-summary.json": summary,
        "token-context.json": (
            {
                "schema_version": SCHEMA_VERSION,
                "measurement_mode": "imported-transcript",
                "confidence": "measured",
                "provider_usage_available": True,
                "provider": session_metrics.get("provider"),
                "model": session_metrics.get("model"),
                "tokens": session_metrics.get("tokens"),
                "speed": session_metrics.get("speed"),
                "duration_seconds": session_metrics.get("duration_seconds"),
                "turns": session_metrics.get("turns"),
                "tool_calls": session_metrics.get("tool_calls"),
                "context": session_metrics.get("context"),
                "subagent": session_metrics.get("subagent"),
                "reliability": session_metrics.get("reliability"),
                "compression": {
                    "recommended_count": 0,
                    "executed_count": (session_metrics.get("compaction") or {}).get(
                        "count", event_count(events, "compact.observed")
                    ),
                },
            }
            if session_metrics
            else {
                "schema_version": SCHEMA_VERSION,
                "measurement_mode": "unavailable",
                "confidence": "unavailable",
                "provider_usage_available": False,
                "compression": {
                    "recommended_count": 0,
                    "executed_count": event_count(events, "compact.observed"),
                },
            }
        ),
        "agent-invocations.json": {
            "schema_version": SCHEMA_VERSION,
            "invocations": invocations,
        },
        "friction.json": {
            "schema_version": SCHEMA_VERSION,
            "retry_counters": {"total": event_count(events, "retry.requested")},
            "blockers": {"total": event_count(events, "blocker.recorded")},
            "escalations": {"total": event_count(events, "escalation.started")},
            "stop_reason": status,
        },
        "activity.json": {
            "schema_version": SCHEMA_VERSION,
            "tool_events": event_count(events, "tool.observed"),
            "hook_events": event_count(events, "hook.observed"),
            "compact_events": event_count(events, "compact.observed"),
            "event_count": len(events),
        },
        "report-quality.json": governance["report_quality"],
        "governance-recommendations.json": {
            "schema_version": SCHEMA_VERSION,
            "recommendation_count": len(recommendations),
            "recommendations": recommendations,
        },
        "pricing-estimate.json": (
            {
                "schema_version": SCHEMA_VERSION,
                "measurement_mode": "list-price-approximation",
                "currency": (session_metrics.get("cost_estimate") or {}).get("currency", "USD"),
                "amount": (session_metrics.get("cost_estimate") or {}).get("amount"),
                "model": session_metrics.get("model"),
                "basis": (session_metrics.get("cost_estimate") or {}).get("basis"),
                "generated_at": generated_at,
            }
            if session_metrics and (session_metrics.get("cost_estimate") or {}).get("amount") is not None
            else {
                "schema_version": SCHEMA_VERSION,
                "measurement_mode": "unavailable",
                "currency": "unavailable",
                "generated_at": generated_at,
            }
        ),
    }
    return artifacts


def write_run_folder(
    run_folder: pathlib.Path,
    events: list[dict[str, Any]],
    run_id: str,
    audit: dict[str, Any] | None = None,
) -> None:
    if run_folder.exists():
        raise AuditError(f"audit run folder already exists: {run_folder}")
    run_folder.mkdir(parents=True)
    artifacts = build_artifacts(events, run_id, audit)
    for name, value in artifacts.items():
        write_json(run_folder / name, value)
    events_path = run_folder / "governance-events.ndjson"
    with events_path.open("w", encoding="utf-8", newline="\n") as handle:
        for event in events:
            handle.write(json.dumps(event, sort_keys=True, separators=(",", ":")))
            handle.write("\n")
    readme = (
        f"# Agent Audit Run {run_id}\n\n"
        "This anonymized report was generated from sanitized event metadata.\n\n"
        f"- Events: {len(events)}\n"
        f"- Status: {artifacts['run-summary.json']['status']}\n"
        "- Privacy: raw prompts, responses, command output, file contents, exact paths, "
        "repository URLs, branch names, and issue titles are not emitted.\n"
    )
    write_text(run_folder / "README.md", readme)
    write_text(
        run_folder / "recommendations.md",
        recommendations_markdown(
            artifacts["governance-recommendations.json"]["recommendations"]
        ),
    )


def create_outbox(
    audit: dict[str, Any],
    source_root: pathlib.Path,
    run_folder: pathlib.Path,
    run_id: str,
) -> pathlib.Path:
    runtime = resolve_path(str(audit["runtime_path"]))
    assert_outside_source(runtime, source_root, "runtime_path")
    outbox = runtime / "outbox" / path_segment(run_id, "audit_run_id")
    if outbox.exists():
        shutil.rmtree(outbox)
    shutil.copytree(run_folder, outbox)
    return outbox


def commit_run(repo: pathlib.Path, run_id: str, sign: Any) -> str | None:
    """Commit the staged run folder. Return None on success or an error string.

    `sign` mirrors the audit config `push.sign` flag: True requires a signed
    commit, False forces `--no-gpg-sign`, and None (default) tries a normal
    commit then retries unsigned so finalize-run still works where commit
    signing is configured but unavailable (e.g. no signing key or server).
    """
    message = f"chore(agent-audit): add anonymized run {run_id}"
    commit_args = ["commit", "-m", message]
    if sign is False:
        commit_args = ["commit", "--no-gpg-sign", "-m", message]
    result = run_git(repo, *commit_args, check=False)
    if result.returncode == 0:
        return None
    if sign is None:
        retry = run_git(repo, "commit", "--no-gpg-sign", "-m", message, check=False)
        if retry.returncode == 0:
            return None
        result = retry
    return (result.stderr or result.stdout).strip()


def maybe_commit_and_push(
    args: argparse.Namespace,
    audit: dict[str, Any],
    source_root: pathlib.Path,
    central: pathlib.Path,
    run_folder: pathlib.Path,
    run_id: str,
    branch: str,
) -> None:
    push_config = audit.get("push") if isinstance(audit.get("push"), dict) else {}
    commit_enabled = bool(args.commit or push_config.get("commit"))
    push_enabled = bool(args.push or push_config.get("mode") == "authorized")
    sign = push_config.get("sign")
    rel = run_folder.relative_to(central).as_posix()
    if commit_enabled:
        run_git(central, "add", "--", rel)
        status = run_git(central, "status", "--porcelain", "--", rel).stdout.strip()
        if status:
            error = commit_run(central, run_id, sign)
            if error is not None:
                outbox = create_outbox(audit, source_root, run_folder, run_id)
                raise AuditError(
                    f"commit failed; sanitized audit data was kept in local outbox: {outbox}. Git said: {error}",
                    4,
                )
    if push_enabled:
        result = run_git(central, "push", "origin", branch, check=False)
        if result.returncode != 0:
            outbox = create_outbox(audit, source_root, run_folder, run_id)
            detail = (result.stderr or result.stdout).strip()
            raise AuditError(
                f"push failed; sanitized audit data was kept in local outbox: {outbox}. Git said: {detail}",
                4,
            )


def finalize_run(args: argparse.Namespace) -> int:
    _, audit = load_config(args.config)
    source_root = resolve_path(args.source_root)
    run_id = args.run_id
    events_path = runtime_events_path(audit, source_root, run_id)
    events = load_events(events_path)
    central = ensure_central_repo(audit, source_root)
    branch = ensure_audit_branch(central, audit)
    year, month = run_period(events)
    project_hash = path_segment(
        str(find_payload_value(events, "project_hash", "hmac_sha256_unavailable")),
        "project_hash",
    )
    run_folder = (
        central
        / "agent-audit"
        / "runs"
        / year
        / month
        / project_hash
        / path_segment(run_id, "audit_run_id")
    )
    write_run_folder(run_folder, events, run_id, audit)
    maybe_commit_and_push(args, audit, source_root, central, run_folder, run_id, branch)
    print(f"finalized audit run: {run_folder}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="ai-agent-kit anonymized audit runtime"
    )
    sub = parser.add_subparsers(dest="command", required=True)

    record = sub.add_parser(
        "record-event", help="append one sanitized event to the local runtime"
    )
    record.add_argument("--config")
    record.add_argument("--event-file")
    record.add_argument("--source-root", default=".")
    record.set_defaults(func=record_event)

    emit = sub.add_parser(
        "emit-event",
        help="build and record one governance event (run.*, agent.*, etc.)",
    )
    emit.add_argument("--config")
    emit.add_argument("--source-root", default=".")
    emit.add_argument("--type", dest="event_type", required=True)
    emit.add_argument("--actor", dest="actor_kind", default="main_agent")
    emit.add_argument("--payload", default="")
    emit.add_argument("--payload-b64", dest="payload_b64")
    emit.add_argument("--invocation-id", dest="invocation_id")
    emit.add_argument("--run-id")
    emit.add_argument("--event-id")
    emit.set_defaults(func=emit_event)

    metrics = sub.add_parser(
        "import-session-metrics",
        help="parse a provider transcript into one anonymized session.metrics event",
    )
    metrics.add_argument("--config")
    metrics.add_argument("--source-root", default=".")
    metrics.add_argument("--provider", required=True)
    metrics.add_argument("--transcript", required=True)
    metrics.add_argument("--run-id")
    metrics.set_defaults(func=import_session_metrics)

    finalize = sub.add_parser(
        "finalize-run", help="generate a central audit run folder"
    )
    finalize.add_argument("--config")
    finalize.add_argument("--source-root", default=".")
    finalize.add_argument("--run-id", required=True)
    finalize.add_argument("--commit", action="store_true")
    finalize.add_argument("--push", action="store_true")
    finalize.set_defaults(func=finalize_run)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except AuditError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return exc.code


if __name__ == "__main__":
    raise SystemExit(main())

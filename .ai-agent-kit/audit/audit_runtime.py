#!/usr/bin/env python3
from __future__ import annotations

import argparse
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
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


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


def assert_outside_source(candidate: pathlib.Path, source_root: pathlib.Path, label: str) -> None:
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


def runtime_events_path(audit: dict[str, Any], source_root: pathlib.Path, run_id: str) -> pathlib.Path:
    runtime = resolve_path(str(audit["runtime_path"]))
    assert_outside_source(runtime, source_root, "runtime_path")
    return runtime / "runs" / path_segment(run_id, "audit_run_id") / "events.ndjson"


def read_event_input(event_file: str | None) -> dict[str, Any]:
    if event_file:
        return read_json_file(resolve_path(event_file), "audit event")
    text = sys.stdin.read()
    if not text.strip():
        raise AuditError("audit event JSON must be passed on stdin or with --event-file")
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


def run_git(repo: pathlib.Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
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


def ensure_central_repo(audit: dict[str, Any], source_root: pathlib.Path) -> pathlib.Path:
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
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
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
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_text(path: pathlib.Path, value: str) -> None:
    privacy_scan({"markdown": value})
    path.write_text(value, encoding="utf-8")


def build_artifacts(events: list[dict[str, Any]], run_id: str) -> dict[str, Any]:
    generated_at = utc_now()
    project_hash = str(find_payload_value(events, "project_hash", "hmac_sha256_unavailable"))
    status = str(find_payload_value(events, "status", "completed_with_warnings"))
    validation_state = str(find_payload_value(events, "validation_state", "unavailable"))
    task_type = str(find_payload_value(events, "task_type", "other"))
    technical_scopes = find_payload_value(events, "technical_scopes", ["unknown"])
    if not isinstance(technical_scopes, list):
        technical_scopes = ["unknown"]

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
            "risk_level": str(find_payload_value(events, "risk_level", "low")),
            "complexity": str(find_payload_value(events, "complexity", "small")),
            "expected_outputs": find_payload_value(events, "expected_outputs", ["unknown"]),
        },
        "status": status,
        "outcome": {
            "validation_state": validation_state,
            "recommendation_count": event_count(events, "recommendation.created"),
            "merged": bool(find_payload_value(events, "merged", False)),
        },
        "activity_summary": {
            "tool_call_count": event_count(events, "tool.observed"),
            "hook_event_count": event_count(events, "hook.observed") + event_count(events, "compact.observed"),
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
        "token-context.json": {
            "schema_version": SCHEMA_VERSION,
            "measurement_mode": "unavailable",
            "confidence": "unavailable",
            "provider_usage_available": False,
        },
        "agent-invocations.json": {
            "schema_version": SCHEMA_VERSION,
            "invocations": [],
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
        "report-quality.json": {
            "schema_version": SCHEMA_VERSION,
            "quality_score": find_payload_value(events, "quality_score", None),
            "quality_category": str(find_payload_value(events, "quality_category", "unavailable")),
            "validation_state": validation_state,
        },
        "governance-recommendations.json": {
            "schema_version": SCHEMA_VERSION,
            "recommendation_count": event_count(events, "recommendation.created"),
            "recommendations": [],
        },
        "pricing-estimate.json": {
            "schema_version": SCHEMA_VERSION,
            "measurement_mode": "unavailable",
            "currency": "unavailable",
            "generated_at": generated_at,
        },
    }
    return artifacts


def write_run_folder(run_folder: pathlib.Path, events: list[dict[str, Any]], run_id: str) -> None:
    if run_folder.exists():
        raise AuditError(f"audit run folder already exists: {run_folder}")
    run_folder.mkdir(parents=True)
    artifacts = build_artifacts(events, run_id)
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
        "# Governance Recommendations\n\nNo automated recommendation was generated for this run.\n",
    )


def create_outbox(audit: dict[str, Any], source_root: pathlib.Path, run_folder: pathlib.Path, run_id: str) -> pathlib.Path:
    runtime = resolve_path(str(audit["runtime_path"]))
    assert_outside_source(runtime, source_root, "runtime_path")
    outbox = runtime / "outbox" / path_segment(run_id, "audit_run_id")
    if outbox.exists():
        shutil.rmtree(outbox)
    shutil.copytree(run_folder, outbox)
    return outbox


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
    rel = run_folder.relative_to(central).as_posix()
    if commit_enabled:
        run_git(central, "add", "--", rel)
        status = run_git(central, "status", "--porcelain", "--", rel).stdout.strip()
        if status:
            run_git(central, "commit", "-m", f"chore(agent-audit): add anonymized run {run_id}")
    if push_enabled:
        result = run_git(central, "push", "origin", branch, check=False)
        if result.returncode != 0:
            outbox = create_outbox(audit, source_root, run_folder, run_id)
            detail = (result.stderr or result.stdout).strip()
            raise AuditError(f"push failed; sanitized audit data was kept in local outbox: {outbox}. Git said: {detail}", 4)


def finalize_run(args: argparse.Namespace) -> int:
    _, audit = load_config(args.config)
    source_root = resolve_path(args.source_root)
    run_id = args.run_id
    events_path = runtime_events_path(audit, source_root, run_id)
    events = load_events(events_path)
    central = ensure_central_repo(audit, source_root)
    branch = ensure_audit_branch(central, audit)
    year, month = run_period(events)
    project_hash = path_segment(str(find_payload_value(events, "project_hash", "hmac_sha256_unavailable")), "project_hash")
    run_folder = central / "agent-audit" / "runs" / year / month / project_hash / path_segment(run_id, "audit_run_id")
    write_run_folder(run_folder, events, run_id)
    maybe_commit_and_push(args, audit, source_root, central, run_folder, run_id, branch)
    print(f"finalized audit run: {run_folder}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="ai-agent-kit anonymized audit runtime")
    sub = parser.add_subparsers(dest="command", required=True)

    record = sub.add_parser("record-event", help="append one sanitized event to the local runtime")
    record.add_argument("--config")
    record.add_argument("--event-file")
    record.add_argument("--source-root", default=".")
    record.set_defaults(func=record_event)

    finalize = sub.add_parser("finalize-run", help="generate a central audit run folder")
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

#!/usr/bin/env python3
"""Cross-tool delegation adapter (issue #339, Phase 2).

A narrow, opt-in adapter that lets an orchestrator (Claude) delegate a single
scoped task to another provider's CLI (Codex or Antigravity) and choose the
model strength from the task type and risk. This is the narrow adapter
ADR-018/ADR-020 explicitly leave room for — NOT a cross-tool orchestration
platform.

Design constraints (all enforced here):
  - The provider CLI invocation via ``subprocess.run`` is the ONLY mockable
    boundary. Model routing, brief/summary sanitization, and audit-event
    emission all run in-process so they are unit-tested without a live CLI.
  - The brief is privacy-scanned BEFORE it is sent to the provider, and the
    returned summary is privacy-scanned BEFORE it enters any audit event or is
    printed. Sanitization reuses the audit runtime's ``privacy_scan`` so the
    rules never drift from the audit boundary.
  - Fail-open: a privacy rejection, a missing/failing provider CLI, or an audit
    emission failure never raises out of the adapter. Delegation is optional, so
    a failure leaves the orchestrator's default behavior unchanged.
  - The orchestrator stays the verifier. This adapter only runs the provider and
    emits ``agent.selected``/``agent.invoked``/``agent.completed`` events with a
    ``provider`` field (feeding the #330 rollup and #331 findings). The mandatory
    ``report.evaluated`` checkpoint is still the orchestrator's job before it
    trusts the result.

The provider answer (sanitized) is printed to stdout for the orchestrator to
consume; the audit events carry only numeric/enum metrics, never the raw answer.
"""
from __future__ import annotations

import argparse
import datetime as dt
import itertools
import os
import pathlib
import shutil
import subprocess
import sys
from typing import Any

# --- Audit runtime reuse --------------------------------------------------
# The adapter reuses the audit runtime for config loading, path resolution,
# privacy scanning, and event validation so its privacy and storage rules stay
# identical to the audit boundary. The runtime lives in a sibling directory:
# ``../agent-audit`` in the source tree, ``../audit`` once installed under
# ``.ai-agent-kit``. Locate whichever exists and import it.
_HERE = pathlib.Path(__file__).resolve().parent
for _sibling in ("agent-audit", "audit"):
    _candidate = _HERE.parent / _sibling
    if (_candidate / "audit_runtime.py").is_file():
        sys.path.insert(0, str(_candidate))
        break
try:
    import audit_runtime as audit  # noqa: E402
except ImportError as exc:  # pragma: no cover - environment wiring failure
    sys.stderr.write(
        "delegate: could not import audit_runtime from a sibling "
        "agent-audit/ or audit/ directory: %s\n" % exc
    )
    raise SystemExit(3) from exc


SCHEMA_VERSION = audit.SCHEMA_VERSION
DEFAULT_TIMEOUT_SECONDS = 600

# Codex runs every profile on one model id; the differentiator is the reasoning
# effort. See docs/ai/MODEL_ROUTING.md (Codex CLI section).
CODEX_MODEL = os.environ.get("AAK_DELEGATE_CODEX_MODEL", "gpt-5.5")

# Routing depth → Codex reasoning effort. The three depths come from the task
# type and risk (see route_depth); the mapping is the one documented in #339:
# deep→high, standard→medium, readonly→low.
CODEX_EFFORT_BY_DEPTH = {"deep": "high", "standard": "medium", "readonly": "low"}

# Antigravity (agy) has a fixed picker model set, not a verified per-call model
# flag, so the adapter passes a non-secret model HINT via the environment rather
# than invent a `--model` flag. See docs/ai/MODEL_ROUTING.md (Antigravity CLI).
ANTIGRAVITY_MODEL_BY_DEPTH = {
    "deep": "gemini-3.1-pro",
    "standard": "gemini-3-flash",
    "readonly": "gemini-3-flash",
}
# The non-secret env var the hint is exported under. Configurable so a future
# agy that reads a specific variable (or none) does not require a code change.
ANTIGRAVITY_MODEL_ENV = os.environ.get(
    "AAK_DELEGATE_AGY_MODEL_ENV", "ANTIGRAVITY_MODEL"
)

# Routing depth → audit model tier, so emitted events line up with the audit
# scorer's tier vocabulary (fast/standard/review/deep).
TIER_BY_DEPTH = {"deep": "review", "standard": "standard", "readonly": "fast"}

# Task types that warrant the strongest reasoning regardless of risk. Mirrors
# audit_runtime.HIGH_TIER_TASKS plus the planning/investigation variants a
# delegating orchestrator is likely to hand off.
DEEP_TASK_TYPES = {
    "security_review",
    "architecture_review",
    "pr_review",
    "code_review",
    "decision_bearing_investigation",
    "refactor_planning",
    "investigation",
}

# Task types that are mechanical / read-only enough for the cheapest tier.
READONLY_TASK_TYPES = {
    "formatting",
    "fixture_update",
    "mechanical_edit",
    "parse_validation",
    "exploration",
    "readonly",
    "lookup",
}

HIGH_RISK = {"high", "critical"}
VALID_RISK = {"low", "medium", "high", "critical"}

_sequence_counter = itertools.count()


class DelegateError(Exception):
    """A usage/configuration error that should stop the adapter (exit 2).

    Distinct from fail-open conditions (privacy rejection, provider failure,
    audit failure), which are warned about and swallowed so the orchestrator's
    default behavior is unchanged.
    """


def warn(message: str) -> None:
    sys.stderr.write(f"delegate: {message}\n")


def route_depth(task_type: str, risk: str) -> str:
    """Map a task type and risk level to a routing depth.

    deep → strongest reasoning (security/architecture/review/high-risk),
    readonly → cheapest (mechanical/exploration), standard → everything else.
    """
    task = task_type.strip().lower()
    risk_level = risk.strip().lower()
    if task in DEEP_TASK_TYPES or risk_level in HIGH_RISK:
        return "deep"
    if task in READONLY_TASK_TYPES:
        return "readonly"
    return "standard"


def build_codex_argv(brief: str, depth: str) -> list[str]:
    """Build the verified non-interactive Codex invocation.

    codex exec -m <model> -c model_reasoning_effort=<low|medium|high>
               -s read-only --json "<brief>"

    ``-s read-only`` sandboxes the delegated run; ``--json`` yields JSON-Lines
    output we can parse for a summary. Verified against
    developers.openai.com/codex/noninteractive and /config-reference.
    """
    effort = CODEX_EFFORT_BY_DEPTH[depth]
    return [
        "codex",
        "exec",
        "-m",
        CODEX_MODEL,
        "-c",
        f"model_reasoning_effort={effort}",
        "-s",
        "read-only",
        "--json",
        brief,
    ]


def extract_codex_summary(stdout: str) -> str:
    """Best-effort extraction of the assistant answer from Codex JSON-Lines.

    Codex ``exec --json`` emits one JSON object per line. The exact event schema
    is not pinned here (it is verified end-to-end in the user's environment), so
    this is tolerant: it collects text from objects that look like an assistant /
    agent message, and falls back to the raw stdout when nothing parses. The
    result is privacy-scanned by the caller before it is used.
    """
    import json

    texts: list[str] = []
    for line in stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(obj, dict):
            continue
        texts.extend(_collect_message_text(obj))
    if texts:
        return "\n".join(texts).strip()
    return stdout.strip()


def _collect_message_text(obj: dict[str, Any]) -> list[str]:
    """Pull assistant/agent message text out of one Codex JSON event object."""
    type_hint = str(obj.get("type") or obj.get("msg") or "").lower()
    looks_like_message = "message" in type_hint or "agent" in type_hint
    found: list[str] = []
    # The text may sit at the top level or nested under "item"/"message".
    for container in (obj, obj.get("item"), obj.get("message")):
        if not isinstance(container, dict):
            continue
        for key in ("text", "content", "message"):
            value = container.get(key)
            if isinstance(value, str) and value.strip():
                if looks_like_message or key == "text":
                    found.append(value.strip())
    return found


def build_antigravity_argv(brief: str, depth: str) -> list[str]:
    """Build the non-interactive Antigravity invocation.

    agy -p "<brief>" --sandbox --dangerously-skip-permissions

    ``-p`` (``--print``) runs a single prompt non-interactively and prints the
    response; ``--sandbox`` restricts terminal access for the delegated run; and
    ``--dangerously-skip-permissions`` auto-approves tool prompts for unattended
    use. Verified against the installed CLI (``agy --help``, v1.0.3): there is no
    ``--output-format`` or per-call model flag, so the model is selected via the
    Antigravity settings and passed as a non-secret env hint by ``provider_env``.
    """
    return [
        "agy",
        "-p",
        brief,
        "--sandbox",
        "--dangerously-skip-permissions",
    ]


def extract_antigravity_summary(stdout: str) -> str:
    """Extract the answer from Antigravity print-mode output.

    ``agy -p`` prints the response as plain text, so the common path is to return
    the trimmed stdout. The function stays tolerant of a JSON object (pulling the
    first string answer field) in case a future version emits one. The result is
    privacy-scanned by the caller before it is used.
    """
    import json

    text = stdout.strip()
    if not text:
        return ""
    try:
        obj = json.loads(text)
    except json.JSONDecodeError:
        return text
    if isinstance(obj, dict):
        for key in ("response", "output", "text", "message", "result", "content"):
            value = obj.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
    return text


def provider_env(provider: str, depth: str) -> dict[str, str] | None:
    """Extra process environment for the provider call, or None to inherit.

    For Antigravity, export a non-secret model hint (Pro for deep work, Flash
    otherwise). Returns a FULL environment copy because passing ``env`` to
    ``subprocess.run`` replaces — not augments — the child's environment, and the
    CLI still needs PATH and its own credentials from the inherited environment.
    """
    if provider == "antigravity":
        model = ANTIGRAVITY_MODEL_BY_DEPTH[depth]
        return {**os.environ, ANTIGRAVITY_MODEL_ENV: model}
    return None


def safe_text(value: str) -> bool:
    """True when the text passes the audit privacy scan (no path/URL/secret)."""
    try:
        audit.privacy_scan(value)
        return True
    except audit.AuditError:
        return False


def load_audit_config(config_path: str | None):
    """Load the audit config, returning None when audit is unavailable.

    Audit emission is best-effort: if the global config is missing or audit is
    disabled, the adapter still runs the provider and prints the summary; it just
    skips the events. Never let a config problem stop a delegation.
    """
    try:
        _, audit_cfg = audit.load_config(config_path)
        return audit_cfg
    except audit.AuditError as exc:
        warn(f"audit disabled or unavailable, events will be skipped: {exc}")
        return None


def emit(
    audit_cfg: dict[str, Any] | None,
    source_root: pathlib.Path,
    run_id: str | None,
    event_type: str,
    actor_kind: str,
    payload: dict[str, Any],
    invocation_id: str | None,
) -> None:
    """Record one governance event in-process. Fail-open.

    Reuses the audit runtime's validation and storage so the event matches what
    the hook-emitted events produce; any failure is warned about and swallowed.
    """
    if audit_cfg is None or not run_id:
        return
    try:
        sequence = int(dt.datetime.now(dt.UTC).timestamp() * 1_000_000) + next(
            _sequence_counter
        )
        event = {
            "schema_version": SCHEMA_VERSION,
            "event_id": f"evt_delegate_{sequence}",
            "audit_run_id": run_id,
            "sequence": sequence,
            "occurred_at": audit.utc_now(),
            "event_type": event_type,
            "actor_kind": actor_kind,
            "invocation_id": invocation_id,
            "payload": payload,
        }
        audit.validate_event(event)  # privacy_scan backstop runs here
        output_path = audit.runtime_events_path(audit_cfg, source_root, run_id)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        import json

        with output_path.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(event, sort_keys=True, separators=(",", ":")))
            handle.write("\n")
    except (audit.AuditError, OSError) as exc:
        warn(f"audit event {event_type} skipped (fail-open): {exc}")


def run_provider(
    argv: list[str], timeout: int, env: dict[str, str] | None = None
) -> tuple[int, str, str]:
    """Invoke the provider CLI — the single mockable boundary. Fail-open.

    Returns (exit_code, stdout, stderr). A missing CLI or a timeout is reported
    as a non-zero code with an empty stdout rather than raising.

    The executable is resolved with ``shutil.which`` first so the call honors
    Windows PATHEXT: the real Codex CLI installs as ``codex.cmd`` on Windows,
    which a bare ``subprocess.run(["codex", ...])`` would not find (and could
    hang on). Resolving to None means the CLI is absent — short-circuit to 127
    instead of invoking anything. ``env`` (when given) fully replaces the child's
    environment, so callers pass a complete copy (see ``provider_env``).
    """
    resolved = shutil.which(argv[0])
    if resolved is None:
        return 127, "", f"{argv[0]}: command not found"
    try:
        result = subprocess.run(
            [resolved, *argv[1:]],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            stdin=subprocess.DEVNULL,
            timeout=timeout,
            env=env,
            check=False,
        )
        return result.returncode, result.stdout or "", result.stderr or ""
    except FileNotFoundError:
        return 127, "", f"{argv[0]}: command not found"
    except subprocess.TimeoutExpired:
        return 124, "", f"{argv[0]}: timed out after {timeout}s"


def delegate(args: argparse.Namespace) -> int:
    provider = args.provider
    risk = args.risk.strip().lower()
    if risk not in VALID_RISK:
        raise DelegateError(
            f"--risk must be one of {sorted(VALID_RISK)}, got '{args.risk}'"
        )

    brief_path = pathlib.Path(
        os.path.expanduser(os.path.expandvars(args.brief_file))
    )
    try:
        brief = brief_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise DelegateError(f"could not read --brief-file: {exc}") from exc
    if not brief.strip():
        raise DelegateError("--brief-file is empty")

    # Sanitize the brief BEFORE it ever reaches the external CLI. A failure here
    # is fail-open: we refuse to send the brief but do not disturb the
    # orchestrator (it can retry with a sanitized brief).
    if not safe_text(brief):
        warn(
            "brief failed the privacy scan (path/URL/secret-like content); "
            "delegation skipped, nothing was sent to the provider"
        )
        return 0

    depth = route_depth(args.task_type, risk)
    model_tier = TIER_BY_DEPTH[depth]
    source_root = audit.resolve_path(args.source_root)
    run_id = args.run_id or os.environ.get("AAK_AUDIT_RUN_ID")
    invocation_id = args.invocation_id or f"inv_delegate_{provider}_{next(_sequence_counter)}"
    audit_cfg = load_audit_config(args.config)

    selection_payload = {
        "provider": provider,
        "agent_category": "delegated",
        "agent_key": f"{provider}:{depth}",
        "model_tier": model_tier,
        "task_type": args.task_type,
        "risk_level": risk,
        "selection_reason": f"routed {args.task_type}/{risk} to {depth} depth",
    }
    emit(
        audit_cfg, source_root, run_id, "agent.selected", "main_agent",
        selection_payload, invocation_id,
    )

    if provider == "codex":
        argv = build_codex_argv(brief, depth)
    elif provider == "antigravity":
        argv = build_antigravity_argv(brief, depth)
    else:  # pragma: no cover - argparse restricts the choices
        raise DelegateError(f"unsupported provider: {provider}")

    emit(
        audit_cfg, source_root, run_id, "agent.invoked", "main_agent",
        {"provider": provider}, invocation_id,
    )

    exit_code, stdout, stderr = run_provider(
        argv, args.timeout, provider_env(provider, depth)
    )

    if exit_code != 0:
        warn(
            f"provider '{provider}' exited {exit_code} (fail-open); "
            f"{stderr.strip()[:200]}"
        )
        emit(
            audit_cfg, source_root, run_id, "agent.completed", "subagent",
            {
                "provider": provider,
                "status": "error",
                "result_summary": {"exit_code": exit_code},
            },
            invocation_id,
        )
        return 0

    if provider == "codex":
        summary = extract_codex_summary(stdout)
    elif provider == "antigravity":
        summary = extract_antigravity_summary(stdout)
    else:  # pragma: no cover - argparse restricts the choices
        summary = stdout.strip()

    # Sanitize the summary BEFORE it is printed or recorded. If it carries
    # path/URL/secret-like content, redact it rather than leak it.
    redacted = not safe_text(summary)
    if redacted:
        warn("provider summary failed the privacy scan; redacting it")
        emitted_summary = "[redacted: summary failed privacy scan]"
    else:
        emitted_summary = summary

    emit(
        audit_cfg, source_root, run_id, "agent.completed", "subagent",
        {
            "provider": provider,
            "status": "success",
            "result_summary": {
                "summary_chars": len(summary),
                "summary_redacted": redacted,
            },
        },
        invocation_id,
    )

    # The (sanitized) provider answer goes to stdout for the orchestrator to
    # read and verify at its mandatory checkpoint.
    print(emitted_summary)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="delegate",
        description=(
            "Delegate a scoped task to another provider's CLI, choosing the "
            "model strength from task type and risk. Opt-in and fail-open."
        ),
    )
    # argparse rejects any provider outside the wired set with a clear message.
    parser.add_argument(
        "--provider", required=True, choices=["codex", "antigravity"]
    )
    parser.add_argument("--task-type", dest="task_type", default="other")
    parser.add_argument("--risk", default="medium")
    parser.add_argument("--brief-file", dest="brief_file", required=True)
    parser.add_argument("--config")
    parser.add_argument("--source-root", dest="source_root", default=".")
    parser.add_argument("--run-id", dest="run_id")
    parser.add_argument("--invocation-id", dest="invocation_id")
    parser.add_argument(
        "--timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS,
        help="provider CLI timeout in seconds (default: %(default)s)",
    )
    parser.set_defaults(func=delegate)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except DelegateError as exc:
        sys.stderr.write(f"Error: {exc}\n")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

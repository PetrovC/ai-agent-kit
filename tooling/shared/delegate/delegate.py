#!/usr/bin/env python3
"""Cross-tool delegation adapter (issue #339, Phase 2; #420, Phase 5).

A narrow, opt-in adapter that lets any of the three supported agents (Claude
Code, Codex, Antigravity) delegate a single scoped task to either of the other
two, choosing the model strength from the task type and risk. This is the
narrow adapter ADR-018/ADR-020 explicitly leave room for — NOT a cross-tool
orchestration platform.

Delegation is symmetrical: Claude can delegate to Codex or Antigravity, Codex
can delegate to Claude or Antigravity, and Antigravity can delegate to Claude
or Codex. Provider-specific behavior lives in thin adapter functions; shared
policy (routing depth, privacy scan, fail-open contract) is never duplicated.

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

_DELEGATE_DIR = pathlib.Path(__file__).resolve().parent
if str(_DELEGATE_DIR) not in sys.path:
    sys.path.insert(0, str(_DELEGATE_DIR))

try:
    from sanitize_patterns import is_safe, redact_text
except ImportError:
    def redact_text(value: str) -> tuple[str, int]:
        """Fallback redaction when the canonical module is unavailable."""
        return _UNSAFE_PATTERNS.subn("[REDACTED_SENSITIVE_VALUE]", value)

    def is_safe(value: str) -> bool:
        """Fallback check when the canonical module is unavailable."""
        return _UNSAFE_PATTERNS.search(value) is None

# --- Audit runtime removed ------------------------------------------------
SCHEMA_VERSION = "0.1.0"
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
# Available models (agy 1.0.4): Gemini 3.5 Flash (Medium/High/Low),
# Gemini 3.1 Pro (Low/High), Claude Sonnet 4.6 (Thinking),
# Claude Opus 4.6 (Thinking), GPT-OSS 120B (Medium).
# Claude models are on a separate Anthropic quota from the linked Gemini pool.
ANTIGRAVITY_MODEL_BY_DEPTH = {
    "deep": "claude-opus-4-6",
    "standard": "claude-sonnet-4-6",
    "readonly": "claude-sonnet-4-6",
}
# Fallback models for Antigravity when the primary model's quota is exhausted.
# deep:     Opus exhausted → Sonnet (still Anthropic quota, one tier down).
# standard: Sonnet exhausted → Gemini 3.1 Pro (High) — separate Gemini quota.
# readonly: same as standard.
ANTIGRAVITY_FALLBACK_BY_DEPTH = {
    "deep": "claude-sonnet-4-6",
    "standard": "gemini-3.1-pro",
    "readonly": "gemini-3.1-pro",
}

# Claude Code CLI — per-call model flag is --model.
# deep → Opus (architecture/security/review), standard → Sonnet (daily work),
# readonly → Haiku (mechanical, exploration).
# Verified against platform.claude.com/docs/en/about-claude/models/overview
# (accessed 2026-06-05).
CLAUDE_MODEL_BY_DEPTH = {
    "deep": "claude-opus-4-8",
    "standard": "claude-sonnet-4-6",
    "readonly": "claude-haiku-4-5",
}

# Substrings (lowercased) in provider stderr/stdout that signal quota exhaustion
# and should trigger a fallback retry. Matches common API rate-limit messages
# from Anthropic, Google, and OpenAI.
QUOTA_EXHAUSTED_PATTERNS = (
    "quota",
    "rate limit",
    "ratelimit",
    "resource_exhausted",
    "resource exhausted",
    "too many requests",
    "429",
    "limit exceeded",
)

# The non-secret env var the hint is exported under. Configurable so a future
# agy that reads a specific variable (or none) does not require a code change.
ANTIGRAVITY_MODEL_ENV = os.environ.get(
    "AAK_DELEGATE_AGY_MODEL_ENV", "ANTIGRAVITY_MODEL"
)

# Routing depth → audit model tier, so emitted events line up with the audit
# scorer's tier vocabulary (fast/standard/review/deep).
TIER_BY_DEPTH = {"deep": "review", "standard": "standard", "readonly": "fast"}

# Task types that warrant the strongest reasoning regardless of risk.
# Includes planning/investigation variants a delegating orchestrator is
# likely to hand off.
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

# Task types that require write access to the workspace (implementing features,
# fixing bugs, adding CI, writing docs). When a task type appears in this set
# the adapter uses Codex workspace-write sandbox and drops agy --sandbox so the
# provider can write files, run git, and create pull-requests.
IMPLEMENTATION_TASK_TYPES = {
    "implementation",
    "feat",
    "fix",
    "refactor",
    "feature",
    "bugfix",
    "ci",
    "docs_write",
    "script",
    "chore",
}

HIGH_RISK = {"high", "critical"}
VALID_RISK = {"low", "medium", "high", "critical"}

_sequence_counter = itertools.count()


def is_implementation(task_type: str) -> bool:
    """True for task types that require write access to the workspace."""
    return task_type.strip().lower() in IMPLEMENTATION_TASK_TYPES


def is_quota_exhausted(exit_code: int, stderr: str, stdout: str) -> bool:
    """True when a non-zero provider exit looks like a quota / rate-limit error.

    Checks stderr and stdout (combined, lowercased) for any of the strings in
    QUOTA_EXHAUSTED_PATTERNS. Only fires on non-zero exit so a successful run
    that happens to mention "quota" in its output does not trigger a retry.
    """
    if exit_code == 0:
        return False
    combined = (stderr + stdout).lower()
    return any(p in combined for p in QUOTA_EXHAUSTED_PATTERNS)


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


def build_codex_argv(brief: str, depth: str, write_mode: bool = False) -> list[str]:
    """Build the verified non-interactive Codex invocation.

    codex exec -m <model> -c model_reasoning_effort=<low|medium|high>
               -s <workspace-write|read-only> --json "<brief>"

    ``write_mode=True`` uses ``workspace-write`` so Codex can write files,
    run git, and create pull-requests (implementation tasks). ``False`` keeps
    ``read-only`` for analysis/review tasks. ``--json`` yields JSON-Lines
    output we can parse for a summary. Verified against
    developers.openai.com/codex/noninteractive and /config-reference.
    """
    effort = CODEX_EFFORT_BY_DEPTH[depth]
    sandbox = "workspace-write" if write_mode else "read-only"
    return [
        "codex",
        "exec",
        "-m",
        CODEX_MODEL,
        "-c",
        f"model_reasoning_effort={effort}",
        "-s",
        sandbox,
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


def build_antigravity_argv(brief: str, depth: str, write_mode: bool = False) -> list[str]:
    """Build the non-interactive Antigravity invocation.

    agy -p "<brief>" [--sandbox] --dangerously-skip-permissions

    ``-p`` (``--print``) runs a single prompt non-interactively and prints the
    response; ``--dangerously-skip-permissions`` auto-approves tool prompts for
    unattended use. ``--sandbox`` restricts terminal access — it is included for
    analysis/review tasks but dropped when ``write_mode=True`` so the provider
    can write files, run git, and create pull-requests. Verified against the
    installed CLI (``agy --help``, v1.0.4): there is no per-call model flag; the
    model is selected via Antigravity settings and passed as a non-secret env
    hint by ``provider_env``.
    """
    argv = ["agy", "-p", brief]
    if not write_mode:
        argv.append("--sandbox")
    argv.append("--dangerously-skip-permissions")
    return argv


def build_claude_argv(brief: str, depth: str, write_mode: bool = False) -> list[str]:
    """Build the non-interactive Claude Code invocation.

    claude --print "<brief>" --model <model> [--dangerously-skip-permissions]

    ``--print`` runs a single prompt non-interactively and prints the response
    as plain text.  ``--dangerously-skip-permissions`` auto-approves tool
    prompts for unattended use and is added only for implementation tasks
    (``write_mode=True``) to keep read-only delegations from writing files.
    Verified against code.claude.com/docs (accessed 2026-06-05).
    """
    model = CLAUDE_MODEL_BY_DEPTH[depth]
    argv = ["claude", "--print", brief, "--model", model]
    if write_mode:
        argv.append("--dangerously-skip-permissions")
    return argv


def extract_claude_summary(stdout: str) -> str:
    """Extract the answer from Claude Code print-mode output.

    ``claude --print`` emits plain text, so return the trimmed stdout.
    The function is tolerant of an optional JSON wrapper in case a future
    version adds one.  The result is privacy-scanned by the caller.
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


def provider_env(
    provider: str,
    depth: str,
    model_override: str | None = None,
) -> dict[str, str] | None:
    """Extra process environment for the provider call, or None to inherit.

    For Antigravity, export a non-secret model hint (Pro for deep work, Flash
    otherwise). ``model_override`` replaces the depth-derived primary model —
    used by the quota-fallback retry path to switch to a cheaper model.
    Returns a FULL environment copy because passing ``env`` to
    ``subprocess.run`` replaces — not augments — the child's environment, and
    the CLI still needs PATH and its own credentials from the inherited env.
    """
    if provider == "antigravity":
        model = model_override if model_override else ANTIGRAVITY_MODEL_BY_DEPTH[depth]
        return {**os.environ, ANTIGRAVITY_MODEL_ENV: model}
    return None  # claude and codex inherit the environment as-is


import re as _re

# Patterns that indicate a brief may contain sensitive material.
# Blocks the most obvious secret/path leaks without requiring audit_runtime.
_UNSAFE_PATTERNS = _re.compile(
    r"""
    sk-[A-Za-z0-9]{20,}       # OpenAI / Anthropic API key
    | ghp_[A-Za-z0-9]{30,}    # GitHub personal token
    | ghs_[A-Za-z0-9]{20,}    # GitHub Actions secret
    | glpat-[A-Za-z0-9-]{20,} # GitLab PAT
    | [A-Z]:[/\\\\]            # Windows absolute path  (C:\, D:\, etc.)
    | /[Uu]sers/[^/\s]{2,}    # macOS / Unix user path (/Users/name, /users/name)
    | /home/[^/\s]{2,}         # Linux home path
    """,
    _re.VERBOSE,
)


def safe_text(value: str) -> bool:
    """True when the text contains no obvious secrets or absolute paths."""
    return is_safe(value)


def load_audit_config(config_path: str | None):
    """Audit removed, always returns None."""
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
    """Audit removed, no-op."""
    return


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

    # Sanitize the brief BEFORE it ever reaches the external CLI.
    brief, brief_substitutions = redact_text(brief)
    if brief_substitutions:
        warn(
            f"brief contained {brief_substitutions} sensitive value(s); "
            "redacted before delegation"
        )

    depth = route_depth(args.task_type, risk)
    model_tier = TIER_BY_DEPTH[depth]
    source_root = pathlib.Path(args.source_root).resolve()
    run_id = args.run_id  # audit removed; run_id retained for API compatibility only
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

    write_mode = is_implementation(args.task_type)
    if provider == "codex":
        argv = build_codex_argv(brief, depth, write_mode)
    elif provider == "antigravity":
        argv = build_antigravity_argv(brief, depth, write_mode)
    elif provider == "claude":
        argv = build_claude_argv(brief, depth, write_mode)
    else:  # pragma: no cover - argparse restricts the choices
        raise DelegateError(f"unsupported provider: {provider}")

    emit(
        audit_cfg, source_root, run_id, "agent.invoked", "main_agent",
        {"provider": provider}, invocation_id,
    )

    exit_code, stdout, stderr = run_provider(
        argv, args.timeout, provider_env(provider, depth)
    )

    # Quota fallback: when Antigravity's primary model quota is exhausted,
    # retry once with the depth's fallback model (e.g. Sonnet → Gemini 3.1 Pro
    # for standard tasks). Codex has no per-model quota to fall back from, so
    # only the antigravity provider gets this retry path.
    fallback_used = False
    fallback_model: str | None = None
    if provider == "antigravity" and is_quota_exhausted(exit_code, stderr, stdout):
        fallback_model = ANTIGRAVITY_FALLBACK_BY_DEPTH.get(depth)
        if fallback_model:
            warn(
                f"primary model quota exhausted; retrying with fallback "
                f"'{fallback_model}'"
            )
            exit_code, stdout, stderr = run_provider(
                argv, args.timeout, provider_env(provider, depth, model_override=fallback_model)
            )
            fallback_used = True

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
                "result_summary": {
                    "exit_code": exit_code,
                    "fallback_used": fallback_used,
                    **({"fallback_model": fallback_model} if fallback_model else {}),
                },
            },
            invocation_id,
        )
        return 0

    if provider == "codex":
        summary = extract_codex_summary(stdout)
    elif provider == "antigravity":
        summary = extract_antigravity_summary(stdout)
    elif provider == "claude":
        summary = extract_claude_summary(stdout)
    else:  # pragma: no cover - argparse restricts the choices
        summary = stdout.strip()

    # Sanitize the summary BEFORE it is printed or recorded.
    emitted_summary, summary_substitutions = redact_text(summary)
    redacted = summary_substitutions > 0
    if redacted:
        warn(
            f"provider summary contained {summary_substitutions} sensitive "
            "value(s); redacted"
        )

    emit(
        audit_cfg, source_root, run_id, "agent.completed", "subagent",
        {
            "provider": provider,
            "status": "success",
            "result_summary": {
                "summary_chars": len(summary),
                "summary_redacted": redacted,
                "fallback_used": fallback_used,
                **({"fallback_model": fallback_model} if fallback_model else {}),
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
        "--provider", required=True, choices=["claude", "codex", "antigravity"]
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

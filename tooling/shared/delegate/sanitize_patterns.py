"""Canonical egress redaction source of truth.

Kept in parity with scripts/sanitize.sh by tests/bats/sanitize_parity.bats.
"""
from __future__ import annotations

import re


REDACTION_RULES: list[tuple[re.Pattern[str], str]] = [
    (
        re.compile(r"(https?://)[^/@\s]+:[^/@\s]+@"),
        r"\1[REDACTED_CREDENTIALS]@",
    ),
    (
        re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
        "[REDACTED_EMAIL]",
    ),
    (
        re.compile(
            r"\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|"
            r"github_pat_[A-Za-z0-9_]{20,})\b"
        ),
        "[REDACTED_GITHUB_TOKEN]",
    ),
    (
        re.compile(r"\b(Bearer\s+)[A-Za-z0-9._-]{10,}"),
        r"\1[REDACTED_BEARER_TOKEN]",
    ),
    (
        re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
        "[REDACTED_AWS_ACCESS_KEY]",
    ),
    (
        re.compile(
            r"\b(?:10(?:\.[0-9]{1,3}){3}|192\.168(?:\.[0-9]{1,3}){2}|"
            r"172\.(?:1[6-9]|2[0-9]|3[0-1])(?:\.[0-9]{1,3}){2})\b"
        ),
        "[REDACTED_PRIVATE_IP]",
    ),
    (
        re.compile(r"\b(?:[A-Za-z0-9-]+\.)+(?:internal|corp|localdomain)\b"),
        "[REDACTED_INTERNAL_HOST]",
    ),
    (
        re.compile(r"sk-[A-Za-z0-9]{20,}"),
        "[REDACTED_API_KEY]",
    ),
    (
        re.compile(r"glpat-[A-Za-z0-9-]{20,}"),
        "[REDACTED_GITLAB_TOKEN]",
    ),
    (
        re.compile(r"[A-Z]:[/\\]"),
        "[REDACTED_PATH]",
    ),
    (
        re.compile(r"/[Uu]sers/[^/\s]{2,}|/home/[^/\s]{2,}"),
        "[REDACTED_PATH]",
    ),
    (
        re.compile(
            r'("?(?:password|secret|token|api[_-]?key)"?\s*:\s*)"[^"]*"'
        ),
        r'\1"[REDACTED_SECRET]"',
    ),
    (
        re.compile(
            r"\b([A-Za-z0-9_]*(?:TOKEN|SECRET|PASSWORD|API_KEY)"
            r"[A-Za-z0-9_]*\s*[:=]\s*)[^\s]+",
            re.IGNORECASE,
        ),
        r"\1[REDACTED_SECRET]",
    ),
]


def redact_text(value: str) -> tuple[str, int]:
    """Return redacted text and the total number of substitutions."""
    redacted = value
    total_substitutions = 0
    for pattern, replacement in REDACTION_RULES:
        redacted, substitutions = pattern.subn(replacement, redacted)
        total_substitutions += substitutions
    return redacted, total_substitutions


def is_safe(value: str) -> bool:
    """True when applying the canonical rules makes no substitutions."""
    _, substitutions = redact_text(value)
    return substitutions == 0

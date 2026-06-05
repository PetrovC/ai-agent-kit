#!/usr/bin/env python3
"""Model selection CLI for the ai-agent-kit (#421, #422).

Reads ``config/model-policy.yaml`` and recommends the smallest model tier
that can safely handle a task, based on task intent, risk level, and context
size.  Pure Python 3 stdlib — no third-party packages required.

Usage
-----
    python3 scripts/select-model.py --task "TEXT" [OPTIONS]

Options
-------
    --task TEXT          Task description (required)
    --risk LEVEL         low | medium | high | critical  (default: medium)
    --context-size SIZE  small | medium | large           (default: medium)
    --provider PROV      claude | codex | antigravity | any  (default: any)
    --json               Output JSON instead of plain text
    --debug              Print scoring details to stderr
    --dry-run            Alias for --json

Policy file
-----------
Searched in order:
  1. ``<CWD>/config/model-policy.yaml``
  2. ``<script_parent>/../config/model-policy.yaml``

Algorithm
---------
  1. Classify intent: iterate intents in policy order; first intent whose
     keyword list has any case-insensitive substring match in --task wins.
     Fallback: ``implementation`` (balanced tier).
  2. Apply risk bump: look up ``risk_bumps[risk]`` (0 if absent), add to
     tier index, clamp to last tier.
  3. Apply context-size bump: look up ``context_size_bumps[context_size]``
     (0 if absent), add, clamp.
  4. Select model from ``providers[provider][tiers][final_tier]``.
  5. Check ``confirmation_policy[final_tier]`` for the confirm flag.
  6. Build fallbacks: same tier, other providers in ``fallback_order``.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


# ---------------------------------------------------------------------------
# Minimal YAML parser
# ---------------------------------------------------------------------------
# The policy file uses a constrained YAML subset (no anchors, no block
# scalars, no multi-document).  We parse it with a hand-written line scanner
# rather than pulling PyYAML.
#
# Supported constructs:
#   - Top-level and nested mapping keys at any indent level
#   - Scalar values: double-quoted strings, bare strings, integers
#   - Inline flow lists: [item1, item2, ...]
#   - Block sequence items: "  - value" and "  - key: value" (inline mapping)
#   - Comments: # ... stripped from line end or whole line
# ---------------------------------------------------------------------------

def _strip_comment(line: str) -> str:
    """Remove inline comments, respecting double-quoted strings."""
    in_quote = False
    for i, ch in enumerate(line):
        if ch == '"' and (i == 0 or line[i - 1] != "\\"):
            in_quote = not in_quote
        if ch == "#" and not in_quote:
            return line[:i].rstrip()
    return line.rstrip()


def _parse_scalar(raw: str) -> Any:
    """Parse a YAML scalar string to a Python value."""
    s = raw.strip()
    if not s:
        return None
    # Double-quoted string
    if s.startswith('"') and s.endswith('"'):
        return s[1:-1]
    # Single-quoted string
    if s.startswith("'") and s.endswith("'"):
        return s[1:-1]
    # Boolean
    if s.lower() == "true":
        return True
    if s.lower() == "false":
        return False
    # Integer
    try:
        return int(s)
    except ValueError:
        pass
    # Bare string
    return s


def _parse_flow_list(s: str) -> list[Any]:
    """Parse a YAML flow list like [a, "b c", d]."""
    inner = s.strip()
    if inner.startswith("[") and inner.endswith("]"):
        inner = inner[1:-1]
    if not inner.strip():
        return []
    parts = []
    buf = ""
    in_quote = False
    for ch in inner:
        if ch == '"' and not in_quote:
            in_quote = True
            buf += ch
        elif ch == '"' and in_quote:
            in_quote = False
            buf += ch
        elif ch == "," and not in_quote:
            parts.append(_parse_scalar(buf.strip()))
            buf = ""
        else:
            buf += ch
    if buf.strip():
        parts.append(_parse_scalar(buf.strip()))
    return parts


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip())


def _parse_yaml(text: str) -> dict[str, Any]:
    """Parse the model-policy.yaml into a nested Python dict / list."""
    lines = text.splitlines()

    def parse_block(start: int, base_indent: int) -> tuple[Any, int]:
        """Parse a block starting at line *start* with parent indent *base_indent*.

        Returns (value, next_line_index).
        """
        i = start
        # Peek: is this a sequence or a mapping?
        # Skip blank / comment lines first
        while i < len(lines) and (not lines[i].strip() or lines[i].lstrip().startswith("#")):
            i += 1
        if i >= len(lines):
            return {}, i

        cur_indent = _indent(lines[i])
        if cur_indent <= base_indent:
            return {}, i

        stripped = lines[i].lstrip()
        if stripped.startswith("- ") or stripped == "-":
            # Sequence
            result: list[Any] = []
            while i < len(lines):
                line = lines[i]
                if not line.strip() or line.lstrip().startswith("#"):
                    i += 1
                    continue
                ind = _indent(line)
                if ind < cur_indent:
                    break
                if ind == cur_indent and line.lstrip().startswith("- "):
                    item_raw = line.lstrip()[2:].strip()
                    if ":" in item_raw and not item_raw.startswith('"'):
                        # Inline mapping: "- key: value"
                        k, _, v = item_raw.partition(":")
                        item: dict[str, Any] = {k.strip(): _parse_scalar(v.strip())}
                        i += 1
                        # Gather additional keys at deeper indent
                        while i < len(lines):
                            sub = lines[i]
                            if not sub.strip() or sub.lstrip().startswith("#"):
                                i += 1
                                continue
                            if _indent(sub) <= cur_indent:
                                break
                            sub_stripped = sub.lstrip()
                            if ":" in sub_stripped and not sub_stripped.startswith("-"):
                                sk, _, sv = sub_stripped.partition(":")
                                sv = sv.strip()
                                if sv.startswith("["):
                                    item[sk.strip()] = _parse_flow_list(sv)
                                elif sv == "" or sv.startswith("#"):
                                    # nested block under this key
                                    nested, i = parse_block(i + 1, _indent(sub))
                                    item[sk.strip()] = nested
                                    continue
                                else:
                                    item[sk.strip()] = _parse_scalar(sv)
                            i += 1
                        result.append(item)
                    elif item_raw.startswith("["):
                        result.append(_parse_flow_list(item_raw))
                        i += 1
                    elif item_raw:
                        result.append(_parse_scalar(item_raw))
                        i += 1
                    else:
                        i += 1
                else:
                    break
            return result, i
        else:
            # Mapping
            result_map: dict[str, Any] = {}
            while i < len(lines):
                line = lines[i]
                if not line.strip() or line.lstrip().startswith("#"):
                    i += 1
                    continue
                ind = _indent(line)
                if ind < cur_indent:
                    break
                stripped2 = line.lstrip()
                if ":" in stripped2 and not stripped2.startswith("-"):
                    k, _, v = stripped2.partition(":")
                    v = v.strip()
                    if v.startswith("["):
                        result_map[k.strip()] = _parse_flow_list(v)
                        i += 1
                    elif v == "" or v.startswith("#"):
                        nested2, i = parse_block(i + 1, ind)
                        result_map[k.strip()] = nested2
                    else:
                        result_map[k.strip()] = _parse_scalar(_strip_comment(v))
                        i += 1
                else:
                    i += 1
            return result_map, i

    policy, _ = parse_block(0, -1)
    return policy  # type: ignore[return-value]


# ---------------------------------------------------------------------------
# Policy loading
# ---------------------------------------------------------------------------

def find_policy_file() -> Path:
    """Find config/model-policy.yaml relative to CWD or script location."""
    candidates = [
        Path.cwd() / "config" / "model-policy.yaml",
        Path(__file__).parent.parent / "config" / "model-policy.yaml",
    ]
    for c in candidates:
        if c.is_file():
            return c
    paths = "\n  ".join(str(c) for c in candidates)
    sys.stderr.write(
        f"select-model: config/model-policy.yaml not found.\nSearched:\n  {paths}\n"
    )
    sys.exit(1)


def load_policy() -> dict[str, Any]:
    path = find_policy_file()
    text = path.read_text(encoding="utf-8")
    return _parse_yaml(text)


# ---------------------------------------------------------------------------
# Intent classification
# ---------------------------------------------------------------------------

def classify_intent(task: str, policy: dict[str, Any]) -> dict[str, Any]:
    """Return the first intent whose keywords match the task text.

    Matching is case-insensitive substring.  Returns the intent dict from the
    policy (with ``name``, ``tier``, ``keywords``, ``description`` keys).
    Falls back to a synthetic ``implementation`` intent at ``balanced`` tier.
    """
    task_lower = task.lower()
    for intent in policy.get("intents", []):
        for kw in intent.get("keywords", []):
            if kw.lower() in task_lower:
                return intent
    # Fallback
    return {"name": "implementation", "tier": "balanced", "keywords": [], "description": "Default fallback."}


# ---------------------------------------------------------------------------
# Tier bump logic
# ---------------------------------------------------------------------------

def bump_tier(base_tier: str, bumps: int, tier_order: list[str]) -> str:
    """Add *bumps* levels to *base_tier*, clamping at the last tier."""
    if base_tier not in tier_order:
        return base_tier
    idx = tier_order.index(base_tier)
    new_idx = min(idx + bumps, len(tier_order) - 1)
    return tier_order[new_idx]


def compute_final_tier(
    base_tier: str,
    risk: str,
    context_size: str,
    policy: dict[str, Any],
    debug: bool = False,
) -> tuple[str, int, int]:
    """Return (final_tier, risk_bump_applied, context_bump_applied)."""
    tier_order = policy.get("tier_order", ["fast", "balanced", "high_reasoning"])

    risk_bumps: dict[str, int] = policy.get("risk_bumps", {})
    r_bump = risk_bumps.get(risk, 0)

    ctx_bumps: dict[str, int] = policy.get("context_size_bumps", {})
    c_bump = ctx_bumps.get(context_size, 0)

    after_risk = bump_tier(base_tier, r_bump, tier_order)
    final = bump_tier(after_risk, c_bump, tier_order)

    if debug:
        sys.stderr.write(
            f"[debug] base={base_tier} risk_bump={r_bump} after_risk={after_risk} "
            f"ctx_bump={c_bump} final={final}\n"
        )
    return final, r_bump, c_bump


# ---------------------------------------------------------------------------
# Model resolution
# ---------------------------------------------------------------------------

def resolve_model(provider: str, tier: str, policy: dict[str, Any]) -> dict[str, Any]:
    """Return a dict describing the model for a provider+tier combination."""
    providers = policy.get("providers", {})
    prov_data = providers.get(provider, {})
    tiers = prov_data.get("tiers", {})
    model_raw = tiers.get(tier, "unknown")

    if isinstance(model_raw, str) and "/" in model_raw:
        # Codex format: "gpt-5.5/low"
        model_name, _, effort = model_raw.partition("/")
        return {"provider": provider, "tier": tier, "model": model_name, "reasoning_effort": effort}
    return {"provider": provider, "tier": tier, "model": str(model_raw)}


def build_fallbacks(
    primary_provider: str,
    final_tier: str,
    policy: dict[str, Any],
) -> list[dict[str, Any]]:
    """Build the fallback list: other providers at the same tier."""
    fallback_order = policy.get("fallback_order", ["claude", "codex", "antigravity"])
    result = []
    for prov in fallback_order:
        if prov != primary_provider:
            result.append(resolve_model(prov, final_tier, policy))
    return result


# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------

def _tier_label(tier: str, r_bump: int, c_bump: int, risk: str, ctx: str) -> str:
    parts = []
    if r_bump:
        parts.append(f"risk={risk} +{r_bump}")
    if c_bump:
        parts.append(f"context={ctx} +{c_bump}")
    return f"{tier}" + (f" ({', '.join(parts)})" if parts else "")


def format_plain(
    intent: dict[str, Any],
    risk: str,
    context_size: str,
    base_tier: str,
    final_tier: str,
    r_bump: int,
    c_bump: int,
    recommended: dict[str, Any],
    requires_confirmation: bool,
    fallbacks: list[dict[str, Any]],
) -> str:
    lines = [
        f"Task intent:  {intent['name']}",
        f"Base tier:    {base_tier}",
        f"Risk bump:    {'none' if not r_bump else f'+{r_bump} (risk={risk})'}",
        f"Context bump: {'none' if not c_bump else f'+{c_bump} (context={context_size})'}",
        f"Final tier:   {final_tier}",
        "",
        "Recommended:",
        f"  Provider:  {recommended['provider']}",
        f"  Model:     {recommended['model']}"
        + (f" / effort={recommended['reasoning_effort']}" if "reasoning_effort" in recommended else ""),
        f"  Tier:      {final_tier}",
        f"  Confirm:   {'yes' if requires_confirmation else 'no'}",
    ]
    if fallbacks:
        lines.append("")
        lines.append("Fallbacks:")
        for fb in fallbacks:
            effort_str = f" / effort={fb['reasoning_effort']}" if "reasoning_effort" in fb else ""
            lines.append(f"  {fb['provider']:<14} {fb['tier']:<14} {fb['model']}{effort_str}")
    return "\n".join(lines)


def build_reason(intent_name: str, final_tier: str, r_bump: int, c_bump: int) -> str:
    parts = [f"{intent_name} task", f"{final_tier} tier"]
    if not r_bump and not c_bump:
        parts.append("no risk/context bumps")
    else:
        if r_bump:
            parts.append(f"risk bump +{r_bump}")
        if c_bump:
            parts.append(f"context bump +{c_bump}")
    return "; ".join(parts)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="select-model",
        description=(
            "Recommend the smallest model tier for a task based on intent, "
            "risk, and context size.  Reads config/model-policy.yaml."
        ),
    )
    p.add_argument("--task", required=True, help="Task description text")
    p.add_argument(
        "--risk",
        default="medium",
        choices=["low", "medium", "high", "critical"],
        help="Risk level (default: medium)",
    )
    p.add_argument(
        "--context-size",
        dest="context_size",
        default="medium",
        choices=["small", "medium", "large"],
        help="Context size (default: medium)",
    )
    p.add_argument(
        "--provider",
        default="any",
        choices=["any", "claude", "codex", "antigravity"],
        help="Target provider, or 'any' for the default fallback order (default: any)",
    )
    p.add_argument("--json", action="store_true", help="Output JSON")
    p.add_argument("--dry-run", dest="json", action="store_true", help="Alias for --json")
    p.add_argument("--debug", action="store_true", help="Print scoring details to stderr")
    return p.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    policy = load_policy()

    tier_order: list[str] = policy.get("tier_order", ["fast", "balanced", "high_reasoning"])
    fallback_order: list[str] = policy.get("fallback_order", ["claude", "codex", "antigravity"])

    intent = classify_intent(args.task, policy)
    base_tier: str = intent.get("tier", "balanced")  # type: ignore[assignment]

    if args.debug:
        sys.stderr.write(f"[debug] task={repr(args.task)}\n")
        sys.stderr.write(f"[debug] matched intent={intent['name']} base_tier={base_tier}\n")

    final_tier, r_bump, c_bump = compute_final_tier(
        base_tier, args.risk, args.context_size, policy, debug=args.debug
    )

    conf_policy: dict[str, bool] = policy.get("confirmation_policy", {})
    requires_confirmation: bool = bool(conf_policy.get(final_tier, False))

    primary_provider = fallback_order[0] if args.provider == "any" else args.provider
    recommended = resolve_model(primary_provider, final_tier, policy)
    fallbacks = build_fallbacks(primary_provider, final_tier, policy)

    if args.json:
        out: dict[str, Any] = {
            "intent": intent["name"],
            "risk": args.risk,
            "context_size": args.context_size,
            "base_tier": base_tier,
            "final_tier": final_tier,
            "recommended_model": recommended,
            "reason": build_reason(intent["name"], final_tier, r_bump, c_bump),
            "requires_confirmation": requires_confirmation,
            "fallbacks": fallbacks,
        }
        print(json.dumps(out, indent=2))
    else:
        print(format_plain(
            intent, args.risk, args.context_size, base_tier, final_tier,
            r_bump, c_bump, recommended, requires_confirmation, fallbacks,
        ))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

# Threat Model

This document captures the current threat model for the runtime surfaces shipped
by `ai-agent-kit`:

1. Hook scripts (`tooling/claude/hooks/`, `tooling/codex/hooks/`)
2. MCP example configuration (`.mcp.example.jsonc`, MCP guidance docs)
3. Lifecycle scripts (`scripts/install.*`, `scripts/update.*`, `scripts/uninstall.*`, `scripts/validate.*`, `scripts/new-skill.*`)

It is a design-time model for engineering decisions, not a penetration test.

## Method

Each surface uses a STRIDE-style table:

- `S` Spoofing identity
- `T` Tampering
- `R` Repudiation
- `I` Information disclosure
- `D` Denial of service
- `E` Elevation of privilege

Each row lists realistic threats, current mitigations in this repository, and
known gaps.

## Assumed Boundaries

| Boundary | Assumption | Implication |
|---|---|---|
| Host shell and OS account | User account and local shell are trusted relative to untrusted external input. | If host is already compromised, kit guardrails cannot provide strong containment. |
| Network and remote services | External servers (MCP endpoints, package mirrors, GitHub APIs) are untrusted by default. | Prefer least privilege and pinned versions for external integrations. |
| Secrets handling | Secrets may exist in target projects but are not required for kit operation. | Scripts and docs must avoid reading or logging secrets unless explicitly requested. |
| Agent runtime | Provider runtimes (Claude/Codex/Gemini) are out of scope for patching here. | Kit can only add guardrails and policy, not enforce runtime isolation. |

## Surface 1: Hook scripts

Scope: hook scripts under `tooling/claude/hooks/` and `tooling/codex/hooks/`
plus their installed dogfood copies.

| STRIDE | Threat scenario | Current mitigations | Gaps / residual risk |
|---|---|---|---|
| S | A malicious command disguises intent to bypass simple pattern matching. | `pre-bash-guard.sh` blocks known dangerous forms (force push, hard reset, unsafe recursive delete, SQL DROP without approval marker). | Pattern denylist is best effort; obfuscation variants may still bypass checks. |
| T | Hook files are modified locally to weaken checks. | Source-controlled canonical hooks in `tooling/`; drift checks in `scripts/validate.*` for dogfood content and executable mode. | Target projects may alter installed hooks intentionally or accidentally; no signature verification of hook content. |
| R | A risky action occurs without traceability of why it was allowed. | Hook output provides immediate command-time feedback; repo workflow expects PR traceability. | No tamper-evident audit log of hook decisions by default. |
| I | Hook output leaks sensitive command arguments or environment values. | Guard focuses on command shape; project guidance discourages exposing secrets. | Hooks can still observe command text; misuse could leak data if extended carelessly. |
| D | Over-broad hook matching blocks legitimate commands and stalls workflows. | Rules are scoped to high-risk patterns and known destructive commands. | False positives remain possible; users may disable hooks entirely, reducing protection. |
| E | A process with user privileges uses hooks as a trust signal and runs unsafe follow-up actions. | Security policy states hooks are guardrails, not sandbox isolation. | No privilege boundary: hook and agent run with same user rights. |

## Surface 2: MCP example configuration and guidance

Scope: `.mcp.example.jsonc`, `docs/ai/MCP_POLICY.md`, and related README/agent
guidance about MCP usage.

| STRIDE | Threat scenario | Current mitigations | Gaps / residual risk |
|---|---|---|---|
| S | An attacker presents a fake MCP server or endpoint that appears legitimate. | Policy requires explicit enablement, least privilege, and pinned/reviewable configuration where possible. | Trust bootstrapping is manual; no built-in identity attestation workflow in kit scripts. |
| T | MCP config is altered to grant broader access than intended. | `.mcp.json` is project-owned after bootstrap; policy warns against broad permissions and mutable tags. | No automatic enforcement for permission scope or endpoint integrity after local edits. |
| R | Unsafe MCP calls occur without clear ownership or review trail. | Workflow guidance requires issue/PR discipline and documenting MCP usage. | No standard machine-readable audit trail for MCP tool invocations. |
| I | MCP server access exposes secrets, internal data, or production records. | Default position is no MCP enabled by default; read-only and least privilege guidance. | Misconfigured third-party MCP servers remain a major disclosure risk outside kit control. |
| D | MCP outage or latency blocks tasks and increases noisy retries/context. | Guidance suggests deterministic local search first and enabling MCP only when needed. | No runtime fallback automation; service instability can still interrupt workflows. |
| E | MCP server permissions exceed intended authority and can perform privileged actions. | Policy explicitly warns against production write access and broad filesystem/database scopes. | Enforcement depends on user/provider settings; kit does not centrally constrain all MCP permissions. |

## Surface 3: Lifecycle scripts

Scope: install/update/uninstall/validate/new-skill scripts in Bash and
PowerShell.

| STRIDE | Threat scenario | Current mitigations | Gaps / residual risk |
|---|---|---|---|
| S | Script execution in the wrong directory or against an unexpected target. | Explicit target arguments required; validation checks expected structure and managed files. | User can still provide an unsafe target path; scripts rely on caller judgment. |
| T | Managed files are silently modified or drift from canonical sources. | Manifest tracking (`.kit-manifest`), update semantics, repo-local drift checks in `validate.*`, and parity checks across shells. | Drift checks are strongest in this repo dogfood mode; target repos can diverge intentionally. |
| R | Changes applied by scripts are difficult to attribute after the fact. | Scripts print explicit operations and dry-run support for update/uninstall paths. | No signed operation log; attribution relies on shell history and git commits. |
| I | Scripts read or expose secret material from target projects. | Security rules and script scope avoid reading `.env` by default; project-owned files (`docs/ai`, `.mcp.json`) are not overwritten. | Targets may contain sensitive paths not covered by simple conventions; human review still needed. |
| D | Script failure or strict validation blocks normal project workflows. | `validate.*` provides actionable errors; update/uninstall support dry-run to preview impact. | Environment differences (shell availability, permissions, missing tools) can still cause friction. |
| E | Script behavior performs actions with broader rights than intended. | No default release/publish operations in lifecycle scripts; guardrails in workflow docs. | Scripts run with caller privileges; misused elevated shells can magnify impact. |

## Existing Mitigation Summary

- Least-privilege defaults in MCP policy and workflow docs.
- Hook denylist for high-risk destructive commands.
- Validation scripts for structure, drift, and metadata consistency.
- Manifest-based install/update/uninstall boundaries.
- Issue-first, PR-first governance with explicit review checkpoints.

## Known Gaps

- Hooks are not a sandbox and cannot provide process isolation.
- No built-in signed integrity verification for installed hook/script assets.
- No universal audit log writer exists yet for hook decisions or MCP invocation
  history; the anonymized data contract is defined in
  [AGENT_AUDIT_SCHEMA.md](./AGENT_AUDIT_SCHEMA.md).
- Permission hardening depends on provider/runtime configuration in target repos.

## Review Cadence

Revisit this model when:

- a new runtime surface is added (for example new hook types, new lifecycle script behavior, or installable shared governance assets);
- provider capability changes alter trust assumptions (hooks, permissions, MCP model);
- a security incident, near miss, or high-severity audit finding is reported.

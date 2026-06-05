# Model Selection Policy

Use the **smallest model that can safely do the job.** A strong model does not
compensate for a vague prompt or a broad scope. A well-scoped task with a
focused prompt often produces better results on a balanced model than a
high-reasoning model with a sprawling instruction.

For the per-subagent model table and provider-specific notes, see
[MODEL_ROUTING.md](./MODEL_ROUTING.md). This document covers the task-intent
→ model-tier decision layer that sits above the subagent table.

The machine-readable policy lives in [`config/model-policy.yaml`](../../config/model-policy.yaml)
and is consumed by [`scripts/select-model.py`](#using-select-modelpy).

---

## Intent buckets and base tiers

| Intent | Base tier | Example tasks |
|---|---|---|
| `docs_typo` | **fast** | Fix typo in README, fix spacing in docs |
| `small_fix` | **fast** | Update a constant, rename a variable, update env config |
| `ci` | **fast** | Add a GitHub Actions workflow, update an existing CI job |
| `test_update` | **balanced** | Add unit tests, update integration test fixtures |
| `implementation` | **balanced** | Implement a new endpoint, add a feature, write a script |
| `debugging` | **balanced** | Fix a bug, trace an error, fix a regression |
| `refactor` | **balanced** | Extract a function, reorganize a module, clean up code |
| `architecture_review` | **high_reasoning** | Review service layer boundaries, broad cross-module refactor |
| `security_review` | **high_reasoning** | Auth/authz audit, threat model, vulnerability scan |
| `investigation` | **high_reasoning** | Root-cause a production incident, plan a cross-repo migration |
| `planning` | **high_reasoning** | Release planning, ADR, tech-debt triage, technical decision |

If no intent keyword matches, `implementation` (balanced) is the fallback.

---

## Risk bumps

Risk level can bump the base tier upward (never downward). Bumps are additive:
each level adds one step in `[fast, balanced, high_reasoning]`, clamped at
`high_reasoning`.

| Risk | Bump |
|---|---|
| `low` | none |
| `medium` | none |
| `high` | +1 level |
| `critical` | +2 levels |

**Examples:**
- `small_fix` (fast) + `risk=high` → balanced (+1)
- `docs_typo` (fast) + `risk=critical` → high_reasoning (+2)
- `refactor` (balanced) + `risk=high` → high_reasoning (+1)
- `implementation` (balanced) + `risk=critical` → high_reasoning (+2, clamped)

---

## Context-size bumps

Large context bumps the tier by one level (clamped at `high_reasoning`).

| Context size | Bump |
|---|---|
| `small` | none |
| `medium` | none |
| `large` | +1 level |

**Example:** `debugging` (balanced) + `context_size=large` → high_reasoning.

Risk bumps and context bumps stack: `small_fix` + `risk=high` +
`context_size=large` → fast +1 +1 = high_reasoning.

---

## Confirmation policy

| Tier | Requires confirmation |
|---|---|
| `fast` | no |
| `balanced` | no |
| `high_reasoning` | **yes** |

`high_reasoning` requires user confirmation (or an explicit opt-in to
auto-switching) before an agent escalates model cost. This is the cost-control
gate: never use the strongest tier by default.

---

## Provider tier mapping

| Tier | Claude | Codex | Antigravity |
|---|---|---|---|
| `fast` | `claude-haiku-4-5` | `gpt-5.5` / effort=`low` | `claude-sonnet-4-6` |
| `balanced` | `claude-sonnet-4-6` | `gpt-5.5` / effort=`medium` | `claude-sonnet-4-6` |
| `high_reasoning` | `claude-opus-4-8` | `gpt-5.5` / effort=`high` | `claude-opus-4-8` |

Model names are defined in `config/model-policy.yaml` — update them there when
provider model names change. Scripts read them from the policy file; nothing
hardcodes model names.

---

## Fallback rules

When the preferred provider is unavailable, fall back in this order:
`claude → codex → antigravity`. Fallbacks use the **same tier**.

Example: architecture review (high_reasoning) with claude unavailable →
Codex `gpt-5.5 / effort=high` → Antigravity `claude-opus-4-8`.

---

## Cost-control guidance

**Prefer fast for:**
- Documentation typo cleanup and simple formatting
- Small isolated script or config fixes
- CI workflow additions that do not touch application logic
- Fixture generation and repetitive low-risk mechanical edits

**Prefer balanced for:**
- Normal daily coding (features, tests, bugfixes, refactors)
- Tasks with well-defined scope and verifiable output
- Any task where the output is a small, reviewable patch

**Prefer high_reasoning for:**
- Architecture reviews and cross-module design
- Security-sensitive code paths (auth, authz, CORS, CSRF)
- Production incident investigation (ambiguous root cause)
- Broad refactors touching many components
- Release planning, ADR, and high-stakes technical decisions

**Remember:** a precise prompt + narrow scope matters more than the model tier.
An expensive model with a vague instruction will underperform a cheaper model
with a tight brief.

---

## Using `select-model.py`

```bash
# Basic usage
python3 scripts/select-model.py --task "implement user login endpoint"

# With risk and context-size signals
python3 scripts/select-model.py \
  --task "security review of the authentication module" \
  --risk high \
  --context-size medium

# JSON output (for scripting)
python3 scripts/select-model.py \
  --task "architecture review of the service layer" \
  --json

# Target a specific provider
python3 scripts/select-model.py \
  --task "fix typo in README" \
  --provider codex
```

**Example plain-text output:**

```
Task intent:  docs_typo
Base tier:    fast
Risk bump:    none (risk=low)
Context bump: none (context=small)
Final tier:   fast

Recommended:
  Provider:  claude
  Model:     claude-haiku-4-5
  Tier:      fast
  Confirm:   no

Fallbacks:
  codex        fast  gpt-5.5 / effort=low
  antigravity  fast  claude-sonnet-4-6
```

**Example JSON output:**

```json
{
  "intent": "docs_typo",
  "risk": "low",
  "context_size": "small",
  "base_tier": "fast",
  "final_tier": "fast",
  "recommended_model": {
    "provider": "claude",
    "tier": "fast",
    "model": "claude-haiku-4-5"
  },
  "reason": "docs_typo task; fast tier; no risk/context bumps",
  "requires_confirmation": false,
  "fallbacks": [
    {"provider": "codex", "tier": "fast", "model": "gpt-5.5", "reasoning_effort": "low"},
    {"provider": "antigravity", "tier": "fast", "model": "claude-sonnet-4-6"}
  ]
}
```

For the selector's scoring algorithm and full CLI reference, see the docstring
at the top of `scripts/select-model.py`.

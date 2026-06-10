# Provider Feature Parity

A single matrix comparing the three providers the kit configures —
**Claude Code**, **Codex CLI**, and **Antigravity** (`agy`) — so configurations don't
restart from scratch. "Kit uses?" is whether *this kit* wires the feature, not
whether the provider merely supports it.

> **Migration note (2026-05-29):** Gemini is no longer a direct provider — it was
> replaced by **Antigravity** (`.agy/` · `AGY.md` · `tooling/agy/`). The third
> column is Antigravity; "Gemini" appears only as the *model family* Antigravity
> invokes (`gemini-3.1-pro` / `gemini-3-flash`).

**Accurate as of June 2026** (kit v1.21+). Refresh cadence: **every 90 days, or
after any provider's major release** — whichever comes first.

## Matrix

| Feature | Claude Code | Codex CLI | Antigravity (`agy`) | Kit uses? |
|---|---|---|---|---|
| **Hooks** | ✅ `settings.json` `hooks` | ✅ `.codex/hooks.json` | ✅ `settings.json` `hooks` | ✅ all three |
| **Session lifecycle events** | `SessionStart/End`, `Stop`, `PreCompact`, `SubagentStop` | `SessionStart`, `Stop`, `SubagentStart/Stop` | `Session{Start,End}`, `Before/AfterAgent` | ✅ (see [§ Hook events](#hook-events)) |
| **Tool events** | `Pre/PostToolUse` | `Pre/PostToolUse` | `Before/AfterTool` | ✅ all three |
| **Subagents** | ✅ `Task` + `tooling/claude/agents/*` | ✅ `features.multi_agent` (ADR-019) | ✅ `tooling/agy/agents/*` + `Before/AfterAgent` | ✅ all three |
| **Skills** | ✅ `.claude/skills/` | ✅ `.agents/skills/` | ✅ `.agy/skills/` | ✅ one source `skills/`, installed per tool |
| **MCP** | ✅ `.mcp.json` (strict JSON) | ✅ `config.toml [mcp_servers]` | ✅ via settings | ⚠️ ships Claude `.mcp.example.jsonc` + Codex commented example |
| **Sandbox** | ❌ (uses permissions) | ✅ `sandbox_mode` (`workspace-write`) | ✅ `tools.sandbox` / `--approval-mode yolo` | ⚠️ Codex `workspace-write`; agy default off |
| **Permissions / approval** | ✅ `allow`/`deny`(/`ask`) | ✅ `approval_policy` (`on-request`) | ✅ `--approval-mode` (`default`/`auto_edit`/`yolo`) | ✅ all three |
| **Web search** | ✅ `WebSearch` + `WebFetch` allowlist | ✅ `web_search` (`cached`) | ✅ built-in (Gemini grounding) | ⚠️ Claude domain allowlist; Codex `cached` |
| **Cross-tool delegation** | orchestrator (`delegate.*`) | ✅ target (`codex exec`) | ✅ target (`agy -p`) | ✅ opt-in adapter (ADR-020) |
| **Debug trace** | ✅ `AAK_DEBUG` (hooks) | ✅ `AAK_DEBUG` (hooks) | ✅ `AAK_DEBUG` (hooks) | ✅ all three (#305); `delegate.py` prints the resolved provider/depth/model (and Codex effort) before exec (#477) |
| **Plugins / extensions** | ✅ plugin marketplace (`.claude-plugin/`) | ❌ no marketplace | ✅ `agy plugin …` | ⚠️ Claude-only marketplace (skills slice) |
| **Output styles** | ✅ supported | ❌ | ❌ | ❌ not used (invalid `outputStyle:"default"` — omit) |
| **Statusline** | ✅ `statusLine` | ❌ | ❌ | ❌ not used |
| **Env redaction / safety** | `permissions.deny` + `pre-bash-guard` | `shell_environment_policy` + `pre-bash-guard` | policies + `pre-bash-guard` | ✅ via pre-bash-guard |

✅ supported & wired · ⚠️ supported, partially/conditionally wired · ❌ not
supported or not used.

## Hook events

The exact hook events each provider exposes that the kit wires:

| Provider | Events wired (`tooling/<tool>/…`) |
|---|---|
| Claude | `PreToolUse`, `PostToolUse`, `PreCompact`, `SessionStart`, `SessionEnd`, `Stop`, `SubagentStop` |
| Codex | `PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, `SubagentStart`, `SubagentStop` |
| Antigravity | `BeforeTool`, `AfterTool`, `BeforeAgent`, `AfterAgent`, `SessionStart`, `SessionEnd` |

Names differ but the coverage is equivalent: a pre/post tool guard, a session
boundary, and a subagent/agent boundary.

## Notes per row

- **Subagents** — all three invoke the kit's five subagent definitions
  (architect, code-reviewer, codebase-investigator, security-reviewer,
  test-runner). Codex's `features.multi_agent` was the one deliberately-disabled
  toggle until ADR-019 turned it on.
- **MCP** — `.mcp.json` must be strict JSON (Claude rejects JSONC); the kit ships
  `.mcp.example.jsonc` as the commented reference and a commented
  `[mcp_servers]` block in `config.toml`. Antigravity reads MCP from its
  settings; the kit's `agy` policies (`rm-rf.toml`, `destructive-git.toml`) cover
  the MCP supply-chain layer with `decision = "ask_user"`.
- **Permissions** — different vocabularies, same intent: Claude `allow`/`deny`
  (+ `ask`), Codex `approval_policy` (`untrusted`/`on-request`/`never`),
  Antigravity `--approval-mode` (`default`/`auto_edit`/`yolo`). `yolo` ≈
  Claude `--dangerously-skip-permissions` ≈ Codex `never`.
- **Web search** — Claude's allowlist is trimmed to high-signal domains
  (`tooling/claude/settings*.json`); Codex `web_search = "cached"` (not
  `enabled`); Antigravity uses native Gemini grounding.
- **Cross-tool delegation** — Claude orchestrates and delegates to Codex/
  Antigravity via the opt-in adapter (`tooling/shared/delegate/`, ADR-020);
  routing and model strength come from `MODEL_ROUTING.md`.
- **Output styles / statusline** — Claude-only capabilities the kit does **not**
  use; `outputStyle: "default"` is invalid and must be omitted (see ADR notes).

## Maintenance

Re-verify this matrix against the live provider docs (linked from
`MODEL_ROUTING.md`) **every 90 days or on any provider major release**, and after
any change under `tooling/<tool>/`. When a row changes, update the cell and the
"Accurate as of" date above.

See also: [ARCHITECTURE.md](./ARCHITECTURE.md) · [ROADMAP.md](./ROADMAP.md) ·
[DECISIONS.md](./DECISIONS.md) (ADR-018/019/020) · [MODEL_ROUTING.md](./MODEL_ROUTING.md).

#!/usr/bin/env bash
# install.sh — Install ai-agent-kit into a target project.
#
# Semantics:
#   - Kit files (skills, tooling, agents, root .md) are ALWAYS overwritten.
#     Re-running install gives you a clean baseline.
#   - docs/ai/ is NEVER overwritten — it holds project-specific content filled by you.
#     Delete docs/ai/ manually if you want a fresh template set.
#
# Use update.sh instead when you only want to refresh what changed.
#
# Usage:
#   ./install.sh --target /path/to/project
#   ./install.sh --target /path/to/project --tools codex,claude
#
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIT_VERSION="1.19.13"
TARGET=""
TOOLS="codex,claude,gemini"

# ── Parse args ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --tools)  TOOLS="$2";  shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 --target /path/to/project [--tools codex,claude,gemini]"
    exit 1
fi

if [[ ! -d "$TARGET" ]]; then
    echo "Error: Target directory does not exist: $TARGET"
    exit 1
fi

IFS=',' read -ra TOOL_LIST <<< "$TOOLS"

VALID_TOOLS=("codex" "claude" "gemini")
for t in "${TOOL_LIST[@]}"; do
    valid=false
    for v in "${VALID_TOOLS[@]}"; do [[ "$t" == "$v" ]] && valid=true && break; done
    if [[ "$valid" == "false" ]]; then
        echo "Error: unknown tool '$t'. Valid options: codex, claude, gemini"
        exit 1
    fi
done

# ── Helpers ────────────────────────────────────────────────────────────────
step() { echo -e "\n\033[36m> $1\033[0m"; }
ok()   { echo -e "  \033[32m[ok] $1\033[0m"; }
skip() { echo -e "  \033[33m[skip] $1 (project content - preserved)\033[0m"; }

MANAGED=()   # kit-managed rel paths, written to .kit-manifest for update GC

# Map a kit-managed rel path to its owning tool, or "" if it is NOT a kit
# artifact (docs/ai, .kit-version) — keeps non-kit paths out of the manifest.
owning_tool() {
    case "$1" in
        AGENTS.md|.codex/*|.agents/skills/*)             echo codex  ;;
        CLAUDE.md|.mcp.json|.mcp.example.jsonc|.claude/*) echo claude ;;
        GEMINI.md|.geminiignore|.gemini/*)               echo gemini ;;
        *)                                               echo ""     ;;
    esac
}

copy_file() {
    local src="$1"
    local dst="$2"
    local dst_dir
    dst_dir="$(dirname "$dst")"

    mkdir -p "$dst_dir"
    cp "$src" "$dst"
    local rel="${dst#$TARGET/}"
    MANAGED+=("$rel")
    ok "$rel"
}

copy_dir() {
    local src_dir="$1"
    local dst_dir="$2"

    [[ -d "$src_dir" ]] || return 0

    # Process substitution (not `find | while`) so MANAGED accumulates in this
    # shell, not a lost pipe subshell.
    local src_file relative
    while IFS= read -r -d '' src_file; do
        relative="${src_file#$src_dir/}"
        copy_file "$src_file" "$dst_dir/$relative"
    done < <(find "$src_dir" -type f -print0)
}

contains() {
    local needle="$1"
    for item in "${TOOL_LIST[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# ── Header ─────────────────────────────────────────────────────────────────
echo ""
echo "+--------------------------------------+"
echo "|        ai-agent-kit installer        |"
echo "+--------------------------------------+"
echo "  Target : $TARGET"
echo "  Tools  : $TOOLS"
echo "  Version: $KIT_VERSION"
echo "  Mode   : OVERWRITE (kit files only; docs/ai/ preserved)"

# ── Skills ─────────────────────────────────────────────────────────────────
if contains "codex"; then
    step "Installing skills -> .agents/skills/"
    copy_dir "$KIT_ROOT/skills" "$TARGET/.agents/skills"
fi

if contains "claude"; then
    step "Installing skills -> .claude/skills/"
    copy_dir "$KIT_ROOT/skills" "$TARGET/.claude/skills"
fi

if contains "gemini"; then
    step "Installing skills -> .gemini/skills/"
    copy_dir "$KIT_ROOT/skills" "$TARGET/.gemini/skills"
fi

# ── Codex ──────────────────────────────────────────────────────────────────
if contains "codex"; then
    step "Installing Codex tooling"
    copy_file "$KIT_ROOT/tooling/codex/AGENTS.md"   "$TARGET/AGENTS.md"
    copy_file "$KIT_ROOT/tooling/codex/config.toml" "$TARGET/.codex/config.toml"
    copy_file "$KIT_ROOT/tooling/codex/hooks.json"  "$TARGET/.codex/hooks.json"
    copy_dir  "$KIT_ROOT/tooling/codex/hooks"       "$TARGET/.codex/hooks"
    # Codex-specific skills (the 5 subagents) merge into the shared .agents/skills/
    # directory alongside the tool-agnostic skills already installed above.
    copy_dir  "$KIT_ROOT/tooling/codex/skills"      "$TARGET/.agents/skills"
    # Make hook scripts executable
    find "$TARGET/.codex/hooks" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
fi

# ── Claude ─────────────────────────────────────────────────────────────────
if contains "claude"; then
    step "Installing Claude Code tooling"
    copy_file "$KIT_ROOT/tooling/claude/CLAUDE.md"      "$TARGET/CLAUDE.md"
    copy_file "$KIT_ROOT/tooling/claude/settings.json"  "$TARGET/.claude/settings.json"
    copy_file "$KIT_ROOT/tooling/claude/.mcp.json"          "$TARGET/.mcp.json"
    copy_file "$KIT_ROOT/tooling/claude/.mcp.example.jsonc" "$TARGET/.mcp.example.jsonc"
    copy_dir  "$KIT_ROOT/tooling/claude/agents"         "$TARGET/.claude/agents"
    copy_dir  "$KIT_ROOT/tooling/claude/commands"       "$TARGET/.claude/commands"
    copy_dir  "$KIT_ROOT/tooling/claude/hooks"          "$TARGET/.claude/hooks"
    copy_dir  "$KIT_ROOT/tooling/claude/rules"          "$TARGET/.claude/rules"
    # Make hook scripts executable
    find "$TARGET/.claude/hooks" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
fi

# ── Gemini ─────────────────────────────────────────────────────────────────
if contains "gemini"; then
    step "Installing Gemini CLI tooling"
    copy_file "$KIT_ROOT/tooling/gemini/GEMINI.md"      "$TARGET/GEMINI.md"
    copy_file "$KIT_ROOT/tooling/gemini/.geminiignore"  "$TARGET/.geminiignore"
    copy_file "$KIT_ROOT/tooling/gemini/settings.json"  "$TARGET/.gemini/settings.json"
    copy_dir  "$KIT_ROOT/tooling/gemini/agents"         "$TARGET/.gemini/agents"
    copy_dir  "$KIT_ROOT/tooling/gemini/commands"       "$TARGET/.gemini/commands"
fi

# ── Project template (docs/ai/) — preserved if it exists ───────────────────
step "Installing project template -> docs/ai/"
mkdir -p "$TARGET/docs/ai"

find "$KIT_ROOT/project-template" -maxdepth 1 -type f | while read -r src_file; do
    file_name="$(basename "$src_file")"
    dst="$TARGET/docs/ai/$file_name"
    if [[ -f "$dst" ]]; then
        skip "docs/ai/$file_name"
    else
        copy_file "$src_file" "$dst"
    fi
done

# ── .kit-version + .kit-manifest ───────────────────────────────────────────
step "Writing .kit-version + .kit-manifest"
echo "ai-agent-kit@$KIT_VERSION - installed $(date +%Y-%m-%d) - tools: $TOOLS" > "$TARGET/.kit-version"
ok ".kit-version"
# Baseline manifest: every kit artifact just installed (docs/ai excluded via
# owning_tool). update.sh diffs against this to prune files later versions
# stop shipping.
for rel in "${MANAGED[@]}"; do
    # `if` (not `[[ ]] && echo`) so the loop never ends on a failing test —
    # under set -o pipefail that would fail the `| sort` pipeline + set -e.
    if [[ -n "$(owning_tool "$rel")" ]]; then echo "$rel"; fi
done | LC_ALL=C sort -u > "$TARGET/.kit-manifest"
ok ".kit-manifest"

# ── .gitignore hint ────────────────────────────────────────────────────────
GITIGNORE="$TARGET/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
    MISSING=()
    for entry in ".claude/settings.local.json" "CLAUDE.local.md" ".env" ".env.*"; do
        grep -qF "$entry" "$GITIGNORE" || MISSING+=("$entry")
    done
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        step ".gitignore - add these entries if not already present:"
        for e in "${MISSING[@]}"; do echo "  $e"; done
    fi
fi

# ── Done ───────────────────────────────────────────────────────────────────
echo ""
echo "+--------------------------------------+"
echo "|           Installation done!         |"
echo "+--------------------------------------+"
echo ""
echo "Next steps:"
echo "  1. Fill in docs/ai/PROJECT.md      <- describe your product"
echo "  2. Fill in docs/ai/COMMANDS.md     <- add your build/test commands"
echo "  3. Fill in docs/ai/ARCHITECTURE.md"
echo "  4. Run validate.sh to confirm all templates are filled"
echo "  5. Commit everything (except .claude/settings.local.json and secrets)"
echo ""
echo "Starter prompts (open in the kit, paste into your agent):"
echo "  prompts/daily-ticket.md     <- start a GitHub issue"
echo "  prompts/feature-planning.md <- plan a multi-file feature"
echo "  prompts/bug-fix.md          <- reproduce and fix a bug"
echo "  prompts/code-review.md      <- triage-style PR review"
echo "  prompts/security-audit.md   <- targeted security pass"
echo ""
echo "To pull in kit updates without overwriting your local edits:"
echo "  ./scripts/update.sh --target $TARGET"

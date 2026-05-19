#!/usr/bin/env bash
# uninstall.sh — Remove ai-agent-kit files from a target project.
#
# Removes (for each tool requested) only kit-installed files:
#   - Root files: AGENTS.md, CLAUDE.md, GEMINI.md, .geminiignore,
#     .mcp.json, .mcp.example.jsonc.
#   - Codex:  .codex/config.toml, .codex/hooks.json, .codex/hooks/,
#             .codex/agents/, .agents/skills/.
#   - Claude: .claude/settings.json, .claude/agents/, .claude/commands/,
#             .claude/hooks/, .claude/rules/, .claude/skills/.
#   - Gemini: .gemini/settings.json, .gemini/agents/, .gemini/commands/,
#             .gemini/skills/.
#   - Parent directories (.codex/, .claude/, .gemini/, .agents/) only if empty after removal.
#   - .kit-version file (only if all installed tools are being removed).
#
# Preserves:
#   - docs/ai/  (your project content — never touched)
#   - Anything outside the kit layout.
#
# Usage:
#   ./uninstall.sh --target /path/to/project [--tools codex,claude,gemini] [--dry-run]
#
set -euo pipefail

TARGET=""
TOOLS=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)  TARGET="$2"; shift 2 ;;
        --tools)   TOOLS="$2";  shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 --target /path/to/project [--tools codex,claude,gemini] [--dry-run]"
    exit 1
fi

if [[ ! -d "$TARGET" ]]; then
    echo "Error: Target directory does not exist: $TARGET"
    exit 1
fi

# If no --tools given, read from .kit-version (or default to all three).
if [[ -z "$TOOLS" ]]; then
    if [[ -f "$TARGET/.kit-version" ]]; then
        VERSION_LINE="$(cat "$TARGET/.kit-version")"
        if [[ "$VERSION_LINE" =~ tools:\ ([^[:space:]]+) ]]; then
            TOOLS="${BASH_REMATCH[1]}"
        fi
    fi
    [[ -z "$TOOLS" ]] && TOOLS="codex,claude,gemini"
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
step()   { echo -e "\n\033[36m> $1\033[0m"; }
removed(){ echo -e "  \033[31m[removed]\033[0m $1"; }
absent() { echo -e "  \033[37m[absent]\033[0m $1"; }
dryrun() { echo -e "  \033[33m[would-remove]\033[0m $1"; }

remove_path() {
    local path="$1"
    local rel="${path#$TARGET/}"
    if [[ -e "$path" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            dryrun "$rel"
        else
            rm -rf "$path"
            removed "$rel"
        fi
    else
        absent "$rel"
    fi
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
echo "|       ai-agent-kit uninstaller       |"
echo "+--------------------------------------+"
echo "  Target: $TARGET"
echo "  Tools : $TOOLS"
[[ "$DRY_RUN" == "true" ]] && echo -e "  Mode  : \033[33mDRY RUN (no files removed)\033[0m"
echo ""
echo "  NOTE: docs/ai/ is preserved. Remove it manually if you want a clean slate."

if contains "codex"; then
    step "Removing Codex tooling"
    remove_path "$TARGET/AGENTS.md"
    remove_path "$TARGET/.codex/config.toml"
    remove_path "$TARGET/.codex/hooks.json"
    remove_path "$TARGET/.codex/hooks"
    remove_path "$TARGET/.codex/agents"
    remove_path "$TARGET/.agents/skills"
    # Clean up empty directories
    for d in "$TARGET/.codex" "$TARGET/.agents"; do
        if [[ -d "$d" ]] && [[ -z "$(ls -A "$d" 2>/dev/null)" ]]; then
            remove_path "$d"
        fi
    done
fi

if contains "claude"; then
    step "Removing Claude Code tooling"
    remove_path "$TARGET/CLAUDE.md"
    remove_path "$TARGET/.mcp.json"
    remove_path "$TARGET/.mcp.example.jsonc"
    remove_path "$TARGET/.claude/settings.json"
    remove_path "$TARGET/.claude/agents"
    remove_path "$TARGET/.claude/commands"
    remove_path "$TARGET/.claude/hooks"
    remove_path "$TARGET/.claude/rules"
    remove_path "$TARGET/.claude/skills"
    # Clean up .claude/ only if nothing else remains (preserves settings.local.json, etc.)
    if [[ -d "$TARGET/.claude" ]] && [[ -z "$(ls -A "$TARGET/.claude" 2>/dev/null)" ]]; then
        remove_path "$TARGET/.claude"
    fi
fi

if contains "gemini"; then
    step "Removing Gemini CLI tooling"
    remove_path "$TARGET/GEMINI.md"
    remove_path "$TARGET/.geminiignore"
    remove_path "$TARGET/.gemini/settings.json"
    remove_path "$TARGET/.gemini/agents"
    remove_path "$TARGET/.gemini/commands"
    remove_path "$TARGET/.gemini/skills"
    # Clean up empty .gemini/
    if [[ -d "$TARGET/.gemini" ]] && [[ -z "$(ls -A "$TARGET/.gemini" 2>/dev/null)" ]]; then
        remove_path "$TARGET/.gemini"
    fi
fi

# Remove .kit-version only if ALL installed tools are being removed.
if [[ -f "$TARGET/.kit-version" ]]; then
    VERSION_LINE="$(cat "$TARGET/.kit-version")"
    INSTALLED=""
    if [[ "$VERSION_LINE" =~ tools:\ ([^[:space:]]+) ]]; then
        INSTALLED="${BASH_REMATCH[1]}"
    fi
    all_removed=true
    IFS=',' read -ra INSTALLED_LIST <<< "$INSTALLED"
    for t in "${INSTALLED_LIST[@]}"; do
        contains "$t" || all_removed=false
    done
    if [[ "$all_removed" == "true" ]]; then
        step "Removing .kit-version"
        remove_path "$TARGET/.kit-version"
    else
        step "Keeping .kit-version"
        echo "  (some tools still installed: $INSTALLED minus $TOOLS)"
    fi
fi

echo ""
echo "+--------------------------------------+"
echo "|         Uninstall complete           |"
echo "+--------------------------------------+"

#!/usr/bin/env bash
# update.sh — Update ai-agent-kit files in a target project.
#
# Only files that are missing or whose content differs (by MD5) are touched.
# Project docs (docs/ai/) are NEVER overwritten — they contain project-specific content.
#
# Usage:
#   ./update.sh --target /path/to/project
#   ./update.sh --target /path/to/project --tools codex,claude
#   ./update.sh --target /path/to/project --dry-run
#
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KIT_VERSION="1.2.0"
TARGET=""
TOOLS=""
DRY_RUN=false

# ── Parse args ─────────────────────────────────────────────────────────────
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

# ── Read installed version ─────────────────────────────────────────────────
VERSION_FILE="$TARGET/.kit-version"
INSTALLED_TOOLS="codex,claude,gemini"
INSTALLED_VERSION=""

if [[ -f "$VERSION_FILE" ]]; then
    VERSION_LINE="$(cat "$VERSION_FILE")"
    echo "Installed: ${VERSION_LINE}"
    if [[ "$VERSION_LINE" =~ ai-agent-kit@([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        INSTALLED_VERSION="${BASH_REMATCH[1]}"
    fi
    if [[ "$VERSION_LINE" =~ tools:\ ([^[:space:]]+) ]]; then
        INSTALLED_TOOLS="${BASH_REMATCH[1]}"
    fi
else
    echo "No .kit-version found — treating as fresh install."
fi

# Warn on version drift
if [[ -n "$INSTALLED_VERSION" && "$INSTALLED_VERSION" != "$KIT_VERSION" ]]; then
    echo ""
    echo -e "  \033[33mWARNING: installed kit version ($INSTALLED_VERSION) differs from source ($KIT_VERSION).\033[0m"
    echo -e "  \033[33m         Review the CHANGELOG before applying.\033[0m"
    echo ""
fi

if [[ -z "$TOOLS" ]]; then
    TOOLS="$INSTALLED_TOOLS"
fi

IFS=',' read -ra TOOL_LIST <<< "$TOOLS"

echo "Kit version: $KIT_VERSION"
echo "Target     : $TARGET"
echo "Tools      : $TOOLS"
[[ "$DRY_RUN" == "true" ]] && echo -e "Mode       : \033[33mDRY RUN (no files written)\033[0m"

# ── Helpers ────────────────────────────────────────────────────────────────
CHANGES=()

# md5 helper — Linux uses md5sum, macOS uses md5 -q. Git Bash on Windows has md5sum.
md5_of() {
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$1" | awk '{print $1}'
    else
        md5 -q "$1"
    fi
}

contains() {
    local needle="$1"
    for item in "${TOOL_LIST[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

compare_and_update() {
    local src="$1"
    local dst="$2"

    [[ -f "$src" ]] || return 0

    local rel="${dst#$TARGET/}"

    if [[ ! -f "$dst" ]]; then
        CHANGES+=("NEW      $rel")
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
        fi
        return 0
    fi

    local src_hash dst_hash
    src_hash="$(md5_of "$src")"
    dst_hash="$(md5_of "$dst")"

    if [[ "$src_hash" != "$dst_hash" ]]; then
        CHANGES+=("UPDATED  $rel")
        if [[ "$DRY_RUN" == "false" ]]; then
            cp "$src" "$dst"
        fi
    fi
}

update_dir() {
    local src_dir="$1"
    local dst_dir="$2"
    [[ -d "$src_dir" ]] || return 0
    while IFS= read -r -d '' src_file; do
        local relative="${src_file#$src_dir/}"
        compare_and_update "$src_file" "$dst_dir/$relative"
    done < <(find "$src_dir" -type f -print0)
}

# ── Update skills ──────────────────────────────────────────────────────────
contains "codex"  && update_dir "$KIT_ROOT/skills" "$TARGET/.agents/skills"
contains "claude" && update_dir "$KIT_ROOT/skills" "$TARGET/.claude/skills"
contains "gemini" && update_dir "$KIT_ROOT/skills" "$TARGET/.gemini/skills"

# ── Update Codex tooling ───────────────────────────────────────────────────
if contains "codex"; then
    compare_and_update "$KIT_ROOT/tooling/codex/AGENTS.md"   "$TARGET/AGENTS.md"
    compare_and_update "$KIT_ROOT/tooling/codex/config.toml" "$TARGET/.codex/config.toml"
    update_dir         "$KIT_ROOT/tooling/codex/agents"      "$TARGET/.codex/agents"
fi

# ── Update Claude tooling ──────────────────────────────────────────────────
if contains "claude"; then
    compare_and_update "$KIT_ROOT/tooling/claude/CLAUDE.md"     "$TARGET/CLAUDE.md"
    compare_and_update "$KIT_ROOT/tooling/claude/settings.json" "$TARGET/.claude/settings.json"
    update_dir         "$KIT_ROOT/tooling/claude/agents"        "$TARGET/.claude/agents"
fi

# ── Update Gemini tooling ──────────────────────────────────────────────────
if contains "gemini"; then
    compare_and_update "$KIT_ROOT/tooling/gemini/GEMINI.md"      "$TARGET/GEMINI.md"
    compare_and_update "$KIT_ROOT/tooling/gemini/.geminiignore"  "$TARGET/.geminiignore"
    compare_and_update "$KIT_ROOT/tooling/gemini/settings.json"  "$TARGET/.gemini/settings.json"
    update_dir         "$KIT_ROOT/tooling/gemini/agents"         "$TARGET/.gemini/agents"
fi

# NOTE: docs/ai/ is intentionally NOT updated — it contains project-specific content.

# ── Update .kit-version ────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "false" ]]; then
    echo "ai-agent-kit@$KIT_VERSION - updated $(date +%Y-%m-%d) - tools: $TOOLS" > "$VERSION_FILE"
fi

# ── Report ─────────────────────────────────────────────────────────────────
echo ""
if [[ ${#CHANGES[@]} -eq 0 ]]; then
    echo -e "\033[32mEverything is up to date.\033[0m"
else
    echo -e "\033[36mChanges:\033[0m"
    for c in "${CHANGES[@]}"; do echo "  $c"; done
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo -e "\033[33mRun without --dry-run to apply these changes.\033[0m"
    else
        echo ""
        echo -e "\033[32m${#CHANGES[@]} file(s) updated.\033[0m"
    fi
fi

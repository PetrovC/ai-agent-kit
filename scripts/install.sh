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
VERSION_FILE="$KIT_ROOT/VERSION"
if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Error: VERSION file not found at $VERSION_FILE" >&2
    exit 1
fi
KIT_VERSION="$(tr -d '\r' < "$VERSION_FILE")"
if [[ ! "$KIT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: VERSION must contain a single semver value, got '$KIT_VERSION'" >&2
    exit 1
fi
TARGET=""
TOOLS="codex,claude,gemini"

# Validate that a flag's value argument is present and is not another flag.
# Without this, `--target` with no further args trips `set -u` on `$2` with a
# noisy shell error, and `--target --tools codex` silently sets TARGET=--tools.
# Empty strings are allowed (callers that forbid empty values check downstream).
require_value() {
    local opt="$1" value="$2" remaining="$3"
    if (( remaining < 2 )); then
        echo "Error: $opt requires a value" >&2
        exit 1
    fi
    if [[ "$value" == --* ]]; then
        echo "Error: $opt requires a value, got '$value'" >&2
        exit 1
    fi
}

# Normalize a comma-separated --tools list: trim each entry, lowercase, drop
# empties. Mirrors install.ps1's `$Tools -split "," | ForEach-Object {
# $_.Trim().ToLower() }` so --tools "Codex, Claude" behaves identically on
# Bash and PowerShell. Populates the global TOOL_LIST array.
normalize_tools() {
    local raw="$1" item
    local -a parts
    TOOL_LIST=()
    IFS=',' read -ra parts <<< "$raw"
    for item in "${parts[@]}"; do
        item="$(printf '%s' "$item" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')"
        [[ -n "$item" ]] && TOOL_LIST+=("$item")
    done
    # Loops on a `[[ ]] &&` test inherit the final test's exit status. When
    # every entry is empty/whitespace, the last iteration ends on a false
    # test and `set -e` silently aborts the caller — return 0 to neutralize.
    return 0
}

# ── Parse args ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) require_value "$1" "${2-}" "$#"; TARGET="$2"; shift 2 ;;
        --tools)  require_value "$1" "${2-}" "$#"; TOOLS="$2";  shift 2 ;;
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

normalize_tools "$TOOLS"
# Rebuild TOOLS as the canonical form so .kit-version, the header, and any
# downstream consumer see the same lowercase comma-joined string regardless of
# how the user typed --tools.
TOOLS="$(IFS=,; echo "${TOOL_LIST[*]}")"

if [[ ${#TOOL_LIST[@]} -eq 0 ]]; then
    echo "Error: --tools list is empty"
    exit 1
fi

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
# artifact (docs/ai, .kit-version, .mcp.json) — keeps non-kit paths out of
# the manifest. `.mcp.json` is initialized once but owned by the project
# afterwards; the kit ships `.mcp.example.jsonc` as the versioned reference.
owning_tool() {
    case "$1" in
        AGENTS.md|.codex/*|.agents/skills/*)             echo codex  ;;
        CLAUDE.md|.mcp.example.jsonc|.claude/*)          echo claude ;;
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
    # .mcp.json is initialized once and then OWNED BY THE PROJECT — install
    # bootstraps an empty file only when missing, update never overwrites it.
    # The versioned reference users copy server blocks from is .mcp.example.jsonc.
    if [[ -f "$TARGET/.mcp.json" ]]; then
        skip ".mcp.json"
    else
        mkdir -p "$TARGET"
        cp "$KIT_ROOT/tooling/claude/.mcp.json" "$TARGET/.mcp.json"
        ok ".mcp.json"
    fi
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
    copy_dir  "$KIT_ROOT/tooling/gemini/hooks"          "$TARGET/.gemini/hooks"
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
# A partial install (`--tools gemini` on top of a codex+claude install) must
# UNION its --tools with the already-installed set in .kit-version, never
# shrink it; and must MERGE the new manifest entries with the manifest
# entries of tools NOT in this run, never overwrite them. The previous
# `>` redirect did the second wrong half — every partial install silently
# orphaned the other tools' manifest entries, breaking later pruning by
# update.sh.
step "Writing .kit-version + .kit-manifest"

# Read the prior installed-tool set so we can preserve it across a partial run.
INSTALLED_TOOLS_OLD=""
if [[ -f "$TARGET/.kit-version" ]]; then
    if [[ "$(cat "$TARGET/.kit-version")" =~ tools:\ ([^[:space:]]+) ]]; then
        INSTALLED_TOOLS_OLD="${BASH_REMATCH[1]}"
    fi
fi
# FULL_TOOLS = union(installed_old, --tools) in canonical codex,claude,gemini order.
FULL_TOOLS=()
for ref in codex claude gemini; do
    keep=false
    if [[ -n "$INSTALLED_TOOLS_OLD" ]]; then
        IFS=',' read -ra OLD_LIST <<< "$INSTALLED_TOOLS_OLD"
        for x in "${OLD_LIST[@]}"; do [[ "$x" == "$ref" ]] && keep=true && break; done
    fi
    contains "$ref" && keep=true
    [[ "$keep" == "true" ]] && FULL_TOOLS+=("$ref")
done
FULL_TOOLS_STR="$(IFS=,; echo "${FULL_TOOLS[*]}")"
echo "ai-agent-kit@$KIT_VERSION - installed $(date +%Y-%m-%d) - tools: $FULL_TOOLS_STR" > "$TARGET/.kit-version"
ok ".kit-version (tools: $FULL_TOOLS_STR)"

# Manifest merge: keep entries from the old .kit-manifest whose owning tool
# is NOT in this run's --tools (other tools' artifacts survive a partial run),
# plus the entries we just installed. update.sh's manifest-diff GC relies on
# the manifest representing the FULL installed set, not just the latest scope.
MANIFEST_KEEP_FROM_OLD=()
if [[ -f "$TARGET/.kit-manifest" ]]; then
    while IFS= read -r p || [[ -n "$p" ]]; do
        [[ -z "$p" ]] && continue
        otool="$(owning_tool "$p")"
        [[ -z "$otool" ]] && continue
        if ! contains "$otool"; then
            MANIFEST_KEEP_FROM_OLD+=("$p")
        fi
    done < "$TARGET/.kit-manifest"
fi
{
    for rel in "${MANAGED[@]}"; do
        # `if` (not `[[ ]] && echo`) so the loop never ends on a failing test —
        # under set -o pipefail that would fail the `| sort` pipeline + set -e.
        if [[ -n "$(owning_tool "$rel")" ]]; then echo "$rel"; fi
    done
    if [[ ${#MANIFEST_KEEP_FROM_OLD[@]} -gt 0 ]]; then
        printf '%s\n' "${MANIFEST_KEEP_FROM_OLD[@]}"
    fi
} | LC_ALL=C sort -u | sed '/^$/d' > "$TARGET/.kit-manifest"
ok ".kit-manifest"

# ── .gitignore hint ────────────────────────────────────────────────────────
# Order matters: `.env.*` is a deny pattern that catches `.env.example` too,
# so the `!.env.example` / `!.env.*.example` whitelist entries MUST follow it.
# `.claude/session-log/` is the PreCompact snapshot dir written by session-summary.sh.
RECOMMENDED_GITIGNORE=(
    ".claude/settings.local.json"
    ".claude/session-log/"
    "CLAUDE.local.md"
    ".env"
    ".env.*"
    "!.env.example"
    "!.env.*.example"
)
GITIGNORE="$TARGET/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
    MISSING=()
    for entry in "${RECOMMENDED_GITIGNORE[@]}"; do
        grep -qF -- "$entry" "$GITIGNORE" || MISSING+=("$entry")
    done
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        step ".gitignore - add these entries if not already present:"
        for e in "${MISSING[@]}"; do echo "  $e"; done
    fi
else
    step ".gitignore not found - create it with at least:"
    for e in "${RECOMMENDED_GITIGNORE[@]}"; do echo "  $e"; done
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
echo "  5. Commit everything except local/runtime files (.claude/settings.local.json, .claude/session-log/, CLAUDE.local.md) and secrets"
echo ""
echo "Starter prompts (open in the kit, paste into your agent):"
echo "  prompts/daily-ticket.md     <- start a GitHub issue"
echo "  prompts/feature-planning.md <- plan a multi-file feature"
echo "  prompts/bug-fix.md          <- reproduce and fix a bug"
echo "  prompts/code-review.md      <- triage-style PR review"
echo "  prompts/security-audit.md   <- targeted security pass"
echo ""
echo "To refresh kit-managed files while preserving docs/ai/ and .mcp.json:"
echo "  ./scripts/update.sh --target $TARGET"
echo ""
echo "  Note: update.sh refreshes managed kit files (CLAUDE.md, AGENTS.md, GEMINI.md,"
echo "        skills/, hooks/, settings.json, …) byte-compared against the kit source."
echo "        Local edits to those files WILL be overwritten when they differ."
echo "        docs/ai/ and .mcp.json are project-owned and never touched."

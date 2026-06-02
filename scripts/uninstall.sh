#!/usr/bin/env bash
# uninstall.sh — Remove ai-agent-kit files from a target project.
#
# Removes only files the kit installed:
#   - .kit-manifest is the source of truth: every kit-installed file is listed,
#     scoped by tool (codex / claude / agy). Only manifest entries whose
#     owning tool is in --tools are removed.
#   - If .kit-manifest is missing (very old installs), the script reconstructs
#     the kit's installed file list from the running kit sources (KIT_ROOT) and
#     removes only those exact paths. Anything else inside managed dirs is left
#     in place.
#
# Empty parent dirs under .agents/, .claude/, .codex/, .agy/ are pruned
# after removal so a fully-uninstalled tool leaves no empty shell behind, while
# user files inside those dirs survive untouched.
#
# Preserves:
#   - docs/ai/  (your project content — never touched)
#   - User-added files inside managed dirs (e.g. .claude/agents/my-agent.md).
#   - Anything outside the kit layout.
#
# Usage:
#   ./uninstall.sh --target /path/to/project [--tools codex,claude,agy] [--dry-run]
#
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=""
TOOLS=""
DRY_RUN=false

# Validate that a flag's value argument is present and is not another flag.
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

# Normalize a comma-separated --tools list: trim, lowercase, drop empties.
normalize_tools() {
    local raw="$1" item
    local -a parts
    TOOL_LIST=()
    IFS=',' read -ra parts <<< "$raw"
    for item in "${parts[@]}"; do
        item="$(printf '%s' "$item" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')"
        [[ -n "$item" ]] && TOOL_LIST+=("$item")
    done
    return 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)  require_value "$1" "${2-}" "$#"; TARGET="$2"; shift 2 ;;
        --tools)   require_value "$1" "${2-}" "$#"; TOOLS="$2";  shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 --target /path/to/project [--tools codex,claude,agy] [--dry-run]"
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
    [[ -z "$TOOLS" ]] && TOOLS="codex,claude,agy"
fi

normalize_tools "$TOOLS"
TOOLS="$(IFS=,; echo "${TOOL_LIST[*]}")"

if [[ ${#TOOL_LIST[@]} -eq 0 ]]; then
    echo "Error: --tools list is empty"
    exit 1
fi

VALID_TOOLS=("codex" "claude" "agy")
for t in "${TOOL_LIST[@]}"; do
    valid=false
    for v in "${VALID_TOOLS[@]}"; do [[ "$t" == "$v" ]] && valid=true && break; done
    if [[ "$valid" == "false" ]]; then
        echo "Error: unknown tool '$t'. Valid options: codex, claude, agy"
        exit 1
    fi
done

# ── Helpers ────────────────────────────────────────────────────────────────
step()   { echo -e "\n\033[36m> $1\033[0m"; }
removed(){ echo -e "  \033[31m[removed]\033[0m $1"; }
absent() { echo -e "  \033[37m[absent]\033[0m $1"; }
dryrun() { echo -e "  \033[33m[would-remove]\033[0m $1"; }
warn()   { echo -e "  \033[33m! $1\033[0m"; }
ok()     { echo -e "  \033[32m[ok]\033[0m $1"; }

contains() {
    local needle="$1"
    for item in "${TOOL_LIST[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

INSTALLED_FOR_SCOPE="codex,claude,agy"
if [[ -f "$TARGET/.kit-version" ]]; then
    VERSION_LINE_FOR_SCOPE="$(cat "$TARGET/.kit-version")"
    if [[ "$VERSION_LINE_FOR_SCOPE" =~ tools:\ ([^[:space:]]+) ]]; then
        INSTALLED_FOR_SCOPE="${BASH_REMATCH[1]}"
    fi
fi
IFS=',' read -ra INSTALLED_SCOPE_LIST <<< "$INSTALLED_FOR_SCOPE"
remaining_scope=()
for t in "${INSTALLED_SCOPE_LIST[@]}"; do
    contains "$t" || remaining_scope+=("$t")
done
REMOVE_SHARED_AUDIT=false
if [[ ${#remaining_scope[@]} -eq 0 ]]; then
    REMOVE_SHARED_AUDIT=true
fi

# Map a kit-managed rel path to its owning tool, or "" if not a kit artifact.
# Mirrors install.sh / update.sh so the manifest and uninstall agree exactly.
# `.mcp.json` is project-owned after install and is never tracked or removed.
owning_tool() {
    case "$1" in
        AGENTS.md|.codex/*|.agents/skills/*)             echo codex  ;;
        .ai-agent-kit/audit/*)                           echo shared ;;
        .ai-agent-kit/delegate/*)                        echo shared ;;
        CLAUDE.md|.mcp.example.jsonc|.claude/*)          echo claude ;;
        AGY.md|.agyignore|.agy/*)               echo agy ;;
        *)                                               echo ""     ;;
    esac
}

# Reconstruct the kit's installed file list for a tool when no manifest is
# present. Only enumerates files that the running kit sources actually ship,
# mirroring install.sh's copy_file/copy_dir invocations.
reconstruct_codex() {
    echo "AGENTS.md"
    echo ".codex/config.toml"
    echo ".codex/hooks.json"
    [[ -d "$KIT_ROOT/tooling/codex/hooks" ]] && \
        find "$KIT_ROOT/tooling/codex/hooks" -type f \
             -printf '.codex/hooks/%P\n'
    [[ -d "$KIT_ROOT/tooling/codex/skills" ]] && \
        find "$KIT_ROOT/tooling/codex/skills" -type f \
             -printf '.agents/skills/%P\n'
    [[ -d "$KIT_ROOT/skills" ]] && \
        find "$KIT_ROOT/skills" -type f \
             -printf '.agents/skills/%P\n'
}

reconstruct_claude() {
    echo "CLAUDE.md"
    echo ".mcp.example.jsonc"
    echo ".claude/settings.json"
    for sub in agents commands hooks rules; do
        [[ -d "$KIT_ROOT/tooling/claude/$sub" ]] && \
            find "$KIT_ROOT/tooling/claude/$sub" -type f \
                 -printf ".claude/$sub/%P\n"
    done
    [[ -d "$KIT_ROOT/skills" ]] && \
        find "$KIT_ROOT/skills" -type f \
             -printf '.claude/skills/%P\n'
}

reconstruct_agy() {
    echo "AGY.md"
    echo ".agyignore"

    echo ".agy/settings.json"
    for sub in agents commands hooks policies; do
        [[ -d "$KIT_ROOT/tooling/agy/$sub" ]] && \
            find "$KIT_ROOT/tooling/agy/$sub" -type f \
                 -printf ".agy/$sub/%P\n"
    done
    [[ -d "$KIT_ROOT/skills" ]] && \
        find "$KIT_ROOT/skills" -type f \
             -printf '.agy/skills/%P\n'
}

reconstruct_shared() {
    [[ -d "$KIT_ROOT/tooling/shared/agent-audit" ]] && \
        find "$KIT_ROOT/tooling/shared/agent-audit" -type f \
             -printf '.ai-agent-kit/audit/%P\n'
    [[ -d "$KIT_ROOT/tooling/shared/delegate" ]] && \
        find "$KIT_ROOT/tooling/shared/delegate" -type f \
             -printf '.ai-agent-kit/delegate/%P\n'
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
echo "  NOTE: docs/ai/ and any file not installed by the kit are preserved."
echo "        Remove docs/ai/ manually if you want a clean slate."

# ── Build the removal list ────────────────────────────────────────────────
MANIFEST_FILE="$TARGET/.kit-manifest"
TO_REMOVE=()

if [[ -f "$MANIFEST_FILE" ]]; then
    while IFS= read -r p || [[ -n "$p" ]]; do
        [[ -z "$p" ]] && continue
        otool="$(owning_tool "$p")"
        [[ -z "$otool" ]] && continue
        if contains "$otool" || [[ "$otool" == "shared" && "$REMOVE_SHARED_AUDIT" == "true" ]]; then
            TO_REMOVE+=("$p")
        fi
    done < "$MANIFEST_FILE"
else
    step "No .kit-manifest found — reconstructing from kit sources"
    warn "Without a manifest, only files this kit version still ships are removed."
    warn "User-added files inside managed dirs are preserved by design."
    contains "codex"  && while IFS= read -r p; do TO_REMOVE+=("$p"); done < <(reconstruct_codex)
    contains "claude" && while IFS= read -r p; do TO_REMOVE+=("$p"); done < <(reconstruct_claude)
    contains "agy" && while IFS= read -r p; do TO_REMOVE+=("$p"); done < <(reconstruct_agy)
    [[ "$REMOVE_SHARED_AUDIT" == "true" ]] && while IFS= read -r p; do TO_REMOVE+=("$p"); done < <(reconstruct_shared)
fi

# Sort + dedupe (a path can be listed twice if two tools share a parent dir).
if [[ ${#TO_REMOVE[@]} -gt 0 ]]; then
    mapfile -t TO_REMOVE < <(printf '%s\n' "${TO_REMOVE[@]}" | LC_ALL=C sort -u)
fi

# ── Remove files (kit-owned only) ─────────────────────────────────────────
for tool in "${TOOL_LIST[@]}"; do
    case "$tool" in
        codex)  step "Removing Codex tooling"      ;;
        claude) step "Removing Claude Code tooling";;
        agy) step "Removing Antigravity CLI tooling" ;;
    esac
    any=false
    for rel in "${TO_REMOVE[@]}"; do
        otool="$(owning_tool "$rel")"
        [[ "$otool" == "$tool" ]] || continue
        any=true
        path="$TARGET/$rel"
        if [[ -e "$path" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                dryrun "$rel"
            else
                rm -f "$path"
                removed "$rel"
            fi
        else
            absent "$rel"
        fi
    done
    [[ "$any" == "false" ]] && echo "  (no files to remove for $tool)"
done

if [[ "$REMOVE_SHARED_AUDIT" == "true" ]]; then
    step "Removing shared audit runtime"
    any=false
    for rel in "${TO_REMOVE[@]}"; do
        otool="$(owning_tool "$rel")"
        [[ "$otool" == "shared" ]] || continue
        any=true
        path="$TARGET/$rel"
        if [[ -e "$path" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                dryrun "$rel"
            else
                rm -f "$path"
                removed "$rel"
            fi
        else
            absent "$rel"
        fi
    done
    [[ "$any" == "false" ]] && echo "  (no files to remove for shared audit runtime)"
fi

# ── Prune empty kit directories ───────────────────────────────────────────
# Walk children before parents and delete empty dirs inline. `-delete` evaluates
# at visit time (after `-depth` ordering), so removing a leaf lets its parent
# pass `-empty` on the next visit — `-exec rmdir {} +` cannot do that because
# it batches removals after the whole traversal completes.
if [[ "$DRY_RUN" == "false" ]]; then
    for top in .agents .claude .codex .agy .ai-agent-kit; do
        dir="$TARGET/$top"
        [[ -d "$dir" ]] || continue
        find "$dir" -depth -type d -empty -delete 2>/dev/null || true
    done
fi

# ── .kit-version + .kit-manifest ──────────────────────────────────────────
# Partial uninstall must rewrite both metadata files to reflect the REMAINING
# tools — leaving the stale "tools: codex,claude,agy" line after
# `uninstall --tools codex` makes the next default update think Codex is still
# installed and silently re-install its files. Similarly, manifest entries
# belonging to removed tools must be dropped so update's manifest-diff GC
# doesn't keep trying to track files we just deleted.
if [[ -f "$TARGET/.kit-version" ]]; then
    VERSION_LINE="$(cat "$TARGET/.kit-version")"
    INSTALLED=""
    INSTALLED_VERSION=""
    if [[ "$VERSION_LINE" =~ tools:\ ([^[:space:]]+) ]]; then
        INSTALLED="${BASH_REMATCH[1]}"
    fi
    if [[ "$VERSION_LINE" =~ ai-agent-kit@([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        INSTALLED_VERSION="${BASH_REMATCH[1]}"
    fi
    [[ -z "$INSTALLED_VERSION" ]] && INSTALLED_VERSION="unknown"

    IFS=',' read -ra INSTALLED_LIST <<< "$INSTALLED"
    remaining=()
    for t in "${INSTALLED_LIST[@]}"; do
        contains "$t" || remaining+=("$t")
    done

    if [[ ${#remaining[@]} -eq 0 ]]; then
        step "Removing .kit-version + .kit-manifest"
        for meta in .kit-version .kit-manifest; do
            path="$TARGET/$meta"
            if [[ -e "$path" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    dryrun "$meta"
                else
                    rm -f "$path"
                    removed "$meta"
                fi
            fi
        done
    else
        REMAINING_STR="$(IFS=,; echo "${remaining[*]}")"
        step "Updating .kit-version to remaining tools: $REMAINING_STR"
        if [[ "$DRY_RUN" == "true" ]]; then
            dryrun ".kit-version"
        else
            echo "ai-agent-kit@$INSTALLED_VERSION - updated $(date +%Y-%m-%d) - tools: $REMAINING_STR" > "$TARGET/.kit-version"
            ok ".kit-version"
        fi
        # Filter the manifest: keep only entries whose owning tool is still installed.
        if [[ -f "$TARGET/.kit-manifest" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                dryrun ".kit-manifest (filter)"
            else
                tmp="$(mktemp)"
                while IFS= read -r p || [[ -n "$p" ]]; do
                    [[ -z "$p" ]] && continue
                    otool="$(owning_tool "$p")"
                    [[ -z "$otool" ]] && continue
                    # Drop entries belonging to tools we just uninstalled.
                    contains "$otool" && continue
                    echo "$p"
                done < "$TARGET/.kit-manifest" | LC_ALL=C sort -u | sed '/^$/d' > "$tmp"
                mv "$tmp" "$TARGET/.kit-manifest"
                ok ".kit-manifest (filtered)"
            fi
        fi
    fi
fi

echo ""
echo "+--------------------------------------+"
echo "|         Uninstall complete           |"
echo "+--------------------------------------+"

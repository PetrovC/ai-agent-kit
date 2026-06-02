#!/usr/bin/env bash
if [[ -n "${AAK_DEBUG:-}" && "${AAK_DEBUG}" != "0" && "${AAK_DEBUG}" != "false" ]]; then set -x; fi  # AAK_DEBUG: opt-in trace (#305)
# update.sh — Update ai-agent-kit files in a target project.
#
# Only files that are missing or whose content differs (byte compare) are
# touched. Files the kit no longer ships are pruned via a manifest diff
# (.kit-manifest). Project docs (docs/ai/) are NEVER overwritten or pruned —
# they contain project-specific content.
#
# Usage:
#   ./update.sh --target /path/to/project
#   ./update.sh --target /path/to/project --tools codex,claude
#   ./update.sh --target /path/to/project --dry-run
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
TOOLS=""
DRY_RUN=false

# Validate that a flag's value argument is present and is not another flag.
# Without this, `--target` with no further args trips `set -u` on `$2` and
# `--target --tools codex` silently sets TARGET=--tools.
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
# Mirrors update.ps1's PowerShell split-trim-lowercase pipeline so the two
# entry points accept the same grammar.
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

# ── Parse args ─────────────────────────────────────────────────────────────
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

# ── Read installed version ─────────────────────────────────────────────────
VERSION_FILE="$TARGET/.kit-version"
MANIFEST_FILE="$TARGET/.kit-manifest"
INSTALLED_TOOLS="codex,claude,agy"
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

normalize_tools "$TOOLS"
# Canonical form for .kit-version + display + manifest GC scope checks.
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

echo "Kit version: $KIT_VERSION"
echo "Target     : $TARGET"
echo "Tools      : $TOOLS"
[[ "$DRY_RUN" == "true" ]] && echo -e "Mode       : \033[33mDRY RUN (no files written)\033[0m"

# ── Helpers ────────────────────────────────────────────────────────────────
CHANGES=()
NOTES=()
RECORD_ACTIONS=()  # "<added|updated|pruned|skipped> <rel>" per touched path, for the install audit (#313)

# Append one NDJSON line describing what this lifecycle run changed (#313).
# Local, parseable record under .ai-agent-kit/; never pushed and not tracked
# in .kit-manifest. Mirrors the writer in install.sh.
write_lifecycle_audit() {
    local lifecycle="$1"  # install | update
    local record_dir="$TARGET/.ai-agent-kit"
    local record_file="$record_dir/install-audit.ndjson"
    mkdir -p "$record_dir"
    local added=0 updated=0 pruned=0 skipped=0
    local changes="" sep="" entry action rel
    for entry in "${RECORD_ACTIONS[@]+"${RECORD_ACTIONS[@]}"}"; do
        action="${entry%% *}"
        rel="${entry#* }"
        case "$action" in
            added)   added=$((added + 1)) ;;
            updated) updated=$((updated + 1)) ;;
            pruned)  pruned=$((pruned + 1)) ;;
            skipped) skipped=$((skipped + 1)) ;;
        esac
        changes="${changes}${sep}{\"path\":\"${rel}\",\"action\":\"${action}\"}"
        sep=","
    done
    printf '{"schema_version":"0.1.0","kit_version":"%s","action":"%s","occurred_at":"%s","changes":[%s],"summary":{"added":%d,"updated":%d,"pruned":%d,"skipped":%d}}\n' \
        "$KIT_VERSION" "$lifecycle" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$changes" "$added" "$updated" "$pruned" "$skipped" >> "$record_file"
    if [[ -n "${AAK_DEBUG:-}" && "${AAK_DEBUG}" != "0" && "${AAK_DEBUG}" != "false" ]]; then
        echo "  [debug] lifecycle audit appended to $record_file" >&2
    fi
}
MANAGED=()          # every kit-managed rel path touched this run (any tool in scope)
KEEP_FROM_OLD=()    # old-manifest entries for tools NOT in this run (preserved as-is)

contains() {
    local needle="$1"
    for item in "${TOOL_LIST[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

owner_in_manifest_scope() {
    local owner="$1"
    [[ "$owner" == "shared" ]] && return 0
    contains "$owner"
}

# Map a kit-managed rel path to its owning tool. Returns "" for anything that
# is NOT a kit-managed artifact (docs/ai, .kit-version, .kit-manifest, user
# files, .mcp.json) — those are never pruned and never carried in the
# manifest. `.mcp.json` is initialized by install and then owned by the
# project; `.mcp.example.jsonc` remains the kit's versioned reference.
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

in_managed() {
    local x="$1" m
    for m in "${MANAGED[@]}"; do [[ "$m" == "$x" ]] && return 0; done
    return 1
}

manifest_has() {
    local x="$1"
    [[ -f "$MANIFEST_FILE" ]] || return 1
    grep -Fxq "$x" "$MANIFEST_FILE"
}

compare_and_update() {
    local src="$1"
    local dst="$2"

    # Closes #68: every direct caller below is a REQUIRED kit source
    # (AGENTS.md, CLAUDE.md, settings.json, …). A silent `return 0` here
    # masked packaging accidents — a missing source produced
    # "Everything is up to date" while leaving the target out of sync with
    # the kit. Treat absence as a fatal release-safety error. Directories
    # walked via update_dir below are optional by nature and use a
    # separate `[[ -d "$src_dir" ]] || return 0` guard.
    if [[ ! -f "$src" ]]; then
        echo "Error: required kit source missing: $src" >&2
        echo "       (release packaging is incomplete; cannot continue)" >&2
        exit 1
    fi

    local rel="${dst#$TARGET/}"
    MANAGED+=("$rel")

    if [[ ! -f "$dst" ]]; then
        CHANGES+=("NEW      $rel")
        RECORD_ACTIONS+=("added $rel")
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
        fi
        return 0
    fi

    # cmp -s short-circuits on the first differing byte (and on size diff) —
    # cheaper and more portable than hashing both whole files with md5sum/md5.
    if ! cmp -s "$src" "$dst"; then
        CHANGES+=("UPDATED  $rel")
        RECORD_ACTIONS+=("updated $rel")
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
contains "agy" && update_dir "$KIT_ROOT/skills" "$TARGET/.agy/skills"

# ── Update Codex tooling ───────────────────────────────────────────────────
if contains "codex"; then
    compare_and_update "$KIT_ROOT/tooling/codex/AGENTS.md"   "$TARGET/AGENTS.md"
    compare_and_update "$KIT_ROOT/tooling/codex/config.toml" "$TARGET/.codex/config.toml"
    compare_and_update "$KIT_ROOT/tooling/codex/hooks.json"  "$TARGET/.codex/hooks.json"
    update_dir         "$KIT_ROOT/tooling/codex/hooks"       "$TARGET/.codex/hooks"
    # Newly added hook scripts must be executable (mirrors install.sh) —
    # otherwise a hook added in a later version lands non-exec and the
    # PreToolUse guard silently never runs on the update path.
    [[ "$DRY_RUN" == "false" && -d "$TARGET/.codex/hooks" ]] && \
        find "$TARGET/.codex/hooks" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
    # Codex skills (5 subagents) merge into shared .agents/skills/
    update_dir         "$KIT_ROOT/tooling/codex/skills"      "$TARGET/.agents/skills"

    # ── v1.14 migration: legacy .codex/agents/*.toml ─────────────────────
    # The Rust Codex CLI does not read this directory. Files are leftover from
    # pre-1.14 kit versions that used custom TOML subagents. The manifest GC
    # removes them only when .kit-manifest proves kit ownership.
    LEGACY_CODEX_AGENTS_DIR="$TARGET/.codex/agents"
    if [[ -d "$LEGACY_CODEX_AGENTS_DIR" ]]; then
        for legacy in architect code-reviewer codebase-investigator security-reviewer test-runner; do
            legacy_file="$LEGACY_CODEX_AGENTS_DIR/$legacy.toml"
            if [[ -f "$legacy_file" ]] && ! manifest_has ".codex/agents/$legacy.toml"; then
                NOTES+=("SKIPPED  .codex/agents/$legacy.toml (legacy; ownership unknown)")
                RECORD_ACTIONS+=("skipped .codex/agents/$legacy.toml")
            fi
        done
    fi
fi

# ── Update Claude tooling ──────────────────────────────────────────────────
if contains "claude"; then
    compare_and_update "$KIT_ROOT/tooling/claude/CLAUDE.md"     "$TARGET/CLAUDE.md"
    compare_and_update "$KIT_ROOT/tooling/claude/settings.json" "$TARGET/.claude/settings.json"
    # .mcp.json is project-owned after install (configured by the user). Update
    # only refreshes the versioned reference; the live file is never touched.
    compare_and_update "$KIT_ROOT/tooling/claude/.mcp.example.jsonc" "$TARGET/.mcp.example.jsonc"
    update_dir         "$KIT_ROOT/tooling/claude/agents"        "$TARGET/.claude/agents"
    update_dir         "$KIT_ROOT/tooling/claude/commands"      "$TARGET/.claude/commands"
    update_dir         "$KIT_ROOT/tooling/claude/hooks"         "$TARGET/.claude/hooks"
    update_dir         "$KIT_ROOT/tooling/claude/rules"         "$TARGET/.claude/rules"
    # Newly added hook scripts must be executable (mirrors install.sh) —
    # otherwise a hook added in a later version lands non-exec and the
    # PreToolUse guard silently never runs on the update path.
    [[ "$DRY_RUN" == "false" && -d "$TARGET/.claude/hooks" ]] && \
        find "$TARGET/.claude/hooks" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
fi

# ── Update Antigravity tooling ──────────────────────────────────────────────────
if contains "agy"; then
    compare_and_update "$KIT_ROOT/tooling/agy/AGY.md"      "$TARGET/AGY.md"
    compare_and_update "$KIT_ROOT/tooling/agy/.agyignore"  "$TARGET/.agyignore"

    compare_and_update "$KIT_ROOT/tooling/agy/settings.json"  "$TARGET/.agy/settings.json"
    update_dir         "$KIT_ROOT/tooling/agy/agents"         "$TARGET/.agy/agents"
    update_dir         "$KIT_ROOT/tooling/agy/commands"       "$TARGET/.agy/commands"
    update_dir         "$KIT_ROOT/tooling/agy/hooks"          "$TARGET/.agy/hooks"
    update_dir         "$KIT_ROOT/tooling/agy/policies"       "$TARGET/.agy/policies"
fi

# -- Update shared audit runtime ------------------------------------------
update_dir "$KIT_ROOT/tooling/shared/agent-audit" "$TARGET/.ai-agent-kit/audit"
[[ "$DRY_RUN" == "false" && -d "$TARGET/.ai-agent-kit/audit" ]] && \
    find "$TARGET/.ai-agent-kit/audit" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true

# -- Update shared delegation adapter -------------------------------------
update_dir "$KIT_ROOT/tooling/shared/delegate" "$TARGET/.ai-agent-kit/delegate"
[[ "$DRY_RUN" == "false" && -d "$TARGET/.ai-agent-kit/delegate" ]] && \
    find "$TARGET/.ai-agent-kit/delegate" -name "*.sh" -exec chmod +x {} + 2>/dev/null || true

# NOTE: docs/ai/ is intentionally NOT updated — it contains project-specific content.

# ── Garbage-collect files the kit no longer ships ──────────────────────────
# Manifest diff: anything in the OLD .kit-manifest that is no longer shipped
# AND whose owning tool is in this run's --tools scope is pruned. Conservative:
#   - only paths under a known kit root are ever touched (owning_tool != "");
#     docs/ai/, .kit-version, .kit-manifest and user files can never match;
#   - first run (no manifest) prunes nothing — it only writes the baseline;
#   - a partial --tools run never prunes another tool's files, and preserves
#     that tool's manifest entries (KEEP_FROM_OLD) so a later full run is sane.
if [[ -f "$MANIFEST_FILE" && ${#MANAGED[@]} -gt 0 ]]; then
    while IFS= read -r p || [[ -n "$p" ]]; do
        [[ -z "$p" ]] && continue
        otool="$(owning_tool "$p")"
        [[ -z "$otool" ]] && continue                 # not a kit artifact → ignore
        if ! owner_in_manifest_scope "$otool"; then
            KEEP_FROM_OLD+=("$p")                      # other tool, out of scope
            continue
        fi
        if ! in_managed "$p" && [[ -e "$TARGET/$p" ]]; then
            CHANGES+=("PRUNED   $p (no longer shipped)")
            RECORD_ACTIONS+=("pruned $p")
            [[ "$DRY_RUN" == "false" ]] && rm -f "$TARGET/$p"
        fi
    done < "$MANIFEST_FILE"
fi

# ── Update .kit-version + .kit-manifest ────────────────────────────────────
if [[ "$DRY_RUN" == "false" ]]; then
    # The installed tool set is independent of this run's --tools scope:
    # `update --tools agy` refreshes only Antigravity files but must NOT shrink
    # the recorded installed set if codex/claude were also installed before.
    # Preserve INSTALLED_TOOLS read at the top of the script.
    echo "ai-agent-kit@$KIT_VERSION - updated $(date +%Y-%m-%d) - tools: $INSTALLED_TOOLS" > "$VERSION_FILE"
    # NOTE: the group must not END on a failing test — under `set -o pipefail`
    # a non-zero group exit fails the whole pipeline and `set -e` aborts. Use
    # `if` (a false `if` with no else exits 0), never a trailing `[[ ]] &&`.
    {
        printf '%s\n' "${MANAGED[@]}"
        if [[ ${#KEEP_FROM_OLD[@]} -gt 0 ]]; then
            printf '%s\n' "${KEEP_FROM_OLD[@]}"
        fi
    } | LC_ALL=C sort -u | sed '/^$/d' > "$MANIFEST_FILE"
fi

# ── Install audit record (#313) ────────────────────────────────────────────
# Only on a real run — a dry-run must not mutate the target.
if [[ "$DRY_RUN" == "false" ]]; then
    write_lifecycle_audit update
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

if [[ ${#NOTES[@]} -gt 0 ]]; then
    echo ""
    echo -e "\033[33mNotes:\033[0m"
    for n in "${NOTES[@]}"; do echo "  $n"; done
fi

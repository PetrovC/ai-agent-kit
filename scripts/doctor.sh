#!/usr/bin/env bash
if [[ -n "${AAK_DEBUG:-}" && "${AAK_DEBUG}" != "0" && "${AAK_DEBUG}" != "false" ]]; then set -x; fi  # AAK_DEBUG: opt-in trace (#305)

set -euo pipefail

TARGET=""

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

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) require_value "$1" "${2-}" "$#"; TARGET="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 --target /path/to/project" >&2
    exit 1
fi

if [[ ! -d "$TARGET" ]]; then
    echo "Error: Target directory '$TARGET' does not exist" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize status flags
has_error=0
has_warning=0

# Color helpers
if [[ -t 1 ]]; then
    COLOR_OK="\033[32m"
    COLOR_WARN="\033[33m"
    COLOR_ERROR="\033[31m"
    COLOR_RESET="\033[0m"
else
    COLOR_OK=""
    COLOR_WARN=""
    COLOR_ERROR=""
    COLOR_RESET=""
fi

ok() {
    echo -e "${COLOR_OK}[OK]${COLOR_RESET} $1"
}

warn() {
    echo -e "${COLOR_WARN}[WARN]${COLOR_RESET} $1" >&2
    has_warning=1
}

error() {
    echo -e "${COLOR_ERROR}[ERROR]${COLOR_RESET} $1" >&2
    has_error=1
}

echo ""
echo "+--------------------------------------+"
echo "|          ai-agent-kit doctor         |"
echo "+--------------------------------------+"
echo "  Target: $TARGET"
echo ""

# a. Version check: read VERSION file from the kit root (one directory up from scripts/); report if target has no .kit-manifest
KIT_VERSION=""
KIT_VERSION_FILE="$SCRIPT_DIR/../VERSION"
if [[ -f "$KIT_VERSION_FILE" ]]; then
    KIT_VERSION=$(cat "$KIT_VERSION_FILE" | tr -d '[:space:]')
fi

if [[ -z "$KIT_VERSION" ]]; then
    error "Version check: Could not read VERSION file from kit root ($KIT_VERSION_FILE)"
else
    # Read target version from .kit-version or VERSION
    TARGET_VERSION=""
    if [[ -f "$TARGET/.kit-version" ]]; then
        VERSION_LINE=$(cat "$TARGET/.kit-version")
        if [[ "$VERSION_LINE" =~ ai-agent-kit@([0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)*) ]]; then
            TARGET_VERSION="${BASH_REMATCH[1]}"
        else
            TARGET_VERSION=$(echo "$VERSION_LINE" | tr -d '[:space:]')
        fi
    elif [[ -f "$TARGET/VERSION" ]]; then
        TARGET_VERSION=$(cat "$TARGET/VERSION" | tr -d '[:space:]')
    fi

    if [[ -z "$TARGET_VERSION" ]]; then
        warn "Version check: Could not determine target kit version (no .kit-version or VERSION file)"
    else
        TARGET_VERSION_CLEAN="${TARGET_VERSION#v}"
        KIT_VERSION_CLEAN="${KIT_VERSION#v}"
        if [[ "$TARGET_VERSION_CLEAN" != "$KIT_VERSION_CLEAN" ]]; then
            warn "Version check: Target version ($TARGET_VERSION) does not match kit version ($KIT_VERSION)"
        else
            ok "Version check: Target version matches kit version ($TARGET_VERSION)"
        fi
    fi
fi

if [[ ! -f "$TARGET/.kit-manifest" ]]; then
    warn "Version check: Target has no .kit-manifest file"
fi

# b. Manifest integrity: verify every file in .kit-manifest exists at target
if [[ ! -f "$TARGET/.kit-manifest" ]]; then
    error "Manifest integrity: .kit-manifest is missing at target"
else
    manifest_drift=0
    while IFS= read -r rel || [[ -n "$rel" ]]; do
        rel="${rel//$'\r'/}"
        rel="${rel#"${rel%%[![:space:]]*}"}"
        rel="${rel%"${rel##*[![:space:]]}"}"
        [[ -n "$rel" ]] || continue
        if [[ ! -f "$TARGET/$rel" ]]; then
            error "Manifest integrity: Missing file -> $rel"
            manifest_drift=1
        fi
    done < "$TARGET/.kit-manifest"
    if [[ $manifest_drift -eq 0 ]]; then
        ok "Manifest integrity: All files in .kit-manifest exist at target"
    fi
fi

# c. Hook executability: .claude/hooks/*.sh and .codex/hooks/*.sh must be executable
hooks_checked=0
hooks_failed=0
for dir in ".claude/hooks" ".codex/hooks"; do
    if [[ -d "$TARGET/$dir" ]]; then
        while IFS= read -r -d '' f; do
            if [[ -f "$f" ]]; then
                hooks_checked=$((hooks_checked+1))
                is_executable=1
                if [[ -n "${AAK_TEST_FORCE_NON_EXECUTABLE:-}" ]]; then
                    is_executable=0
                elif [[ ! -x "$f" ]]; then
                    is_executable=0
                fi

                if [[ $is_executable -eq 0 ]]; then
                    warn "Hook executability: Hook is not executable -> ${f#"$TARGET/"}"
                    hooks_failed=$((hooks_failed+1))
                fi
            fi
        done < <(find "$TARGET/$dir" -maxdepth 1 -type f -name "*.sh" -print0 2>/dev/null)
    fi
done
if [[ $hooks_checked -eq 0 ]]; then
    ok "Hook executability: No hooks found to verify"
elif [[ $hooks_failed -eq 0 ]]; then
    ok "Hook executability: All $hooks_checked hooks are executable"
fi

# d. MCP file: .mcp.example.jsonc must exist
if [[ ! -f "$TARGET/.mcp.example.jsonc" ]]; then
    error "MCP file: .mcp.example.jsonc is missing"
else
    ok "MCP file: .mcp.example.jsonc is present"
fi

# e. docs/ai presence: docs/ai/PROJECT.md, docs/ai/ARCHITECTURE.md must exist
docs_missing=0
for f in "docs/ai/PROJECT.md" "docs/ai/ARCHITECTURE.md"; do
    if [[ ! -f "$TARGET/$f" ]]; then
        error "docs/ai presence: $f is missing"
        docs_missing=1
    fi
done
if [[ $docs_missing -eq 0 ]]; then
    ok "docs/ai presence: docs/ai/PROJECT.md and docs/ai/ARCHITECTURE.md are present"
fi

echo ""
if [[ $has_error -eq 1 ]]; then
    echo -e "${COLOR_ERROR}Diagnostics failed with errors.${COLOR_RESET}" >&2
    exit 2
elif [[ $has_warning -eq 1 ]]; then
    echo -e "${COLOR_WARN}Diagnostics passed with warnings.${COLOR_RESET}" >&2
    exit 1
else
    echo -e "${COLOR_OK}Diagnostics passed successfully. Target install is healthy.${COLOR_RESET}"
    exit 0
fi

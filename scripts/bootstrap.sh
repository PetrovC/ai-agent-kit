#!/usr/bin/env bash
# bootstrap.sh — Download a pinned ai-agent-kit release and install it.
#
# Quick install (all 3 tools, current directory):
#   curl -fsSL https://github.com/PetrovC/ai-agent-kit/releases/latest/download/bootstrap.sh | bash
#
# Pinned version with explicit options:
#   curl -fsSL https://github.com/PetrovC/ai-agent-kit/releases/download/v1.23.0/bootstrap.sh \
#     | bash -s -- --target /path/to/project --tools claude --version v1.23.0
#
# Options:
#   --version   Release tag, e.g. v1.23.0 (default: latest)
#   --target    Project directory           (default: current directory)
#   --tools     Comma-separated list        (default: codex,claude,agy)
#   --profile   full | minimal              (default: full)
#   --dry-run   Print what would happen; do not download or install

set -euo pipefail

REPO="PetrovC/ai-agent-kit"
VERSION=""
TARGET="."
TOOLS="codex,claude,agy"
PROFILE="full"
DRY_RUN=false

# Validate that a flag has a following non-flag value
require_value() {
    local opt="$1" value="$2" remaining="$3"
    if (( remaining < 2 )); then
        echo "Error: $opt requires a value" >&2; exit 1
    fi
    if [[ "$value" == --* ]]; then
        echo "Error: $opt requires a value, got '$value'" >&2; exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) require_value "$1" "${2-}" "$#"; VERSION="$2"; shift 2 ;;
        --target)  require_value "$1" "${2-}" "$#"; TARGET="$2";  shift 2 ;;
        --tools)   require_value "$1" "${2-}" "$#"; TOOLS="$2";   shift 2 ;;
        --profile) require_value "$1" "${2-}" "$#"; PROFILE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

# Resolve latest version if not specified
if [[ -z "$VERSION" ]]; then
    echo "Fetching latest release version..."
    if command -v curl >/dev/null 2>&1; then
        VERSION="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
            | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')"
    else
        echo "Error: curl is required to fetch the latest version." >&2
        echo "Install curl or pass --version v<tag> explicitly." >&2
        exit 1
    fi
    if [[ -z "$VERSION" ]]; then
        echo "Error: could not determine latest release version." >&2
        echo "Pass --version v<tag> explicitly." >&2
        exit 1
    fi
fi

ARCHIVE_NAME="ai-agent-kit-${VERSION}.tar.gz"
ARCHIVE_URL="https://github.com/${REPO}/releases/download/${VERSION}/${ARCHIVE_NAME}"

echo ""
echo "+--------------------------------------+"
echo "|      ai-agent-kit bootstrap         |"
echo "+--------------------------------------+"
echo "  Version: $VERSION"
echo "  Target : $TARGET"
echo "  Tools  : $TOOLS"
echo "  Profile: $PROFILE"
echo "  Source : $ARCHIVE_URL"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] Would download: $ARCHIVE_URL"
    echo "[dry-run] Would extract to a temporary directory"
    echo "[dry-run] Would run: install.sh --target $TARGET --tools $TOOLS --profile $PROFILE"
    echo "[dry-run] Would clean up the temporary directory"
    exit 0
fi

if [[ ! -d "$TARGET" ]]; then
    echo "Error: target directory does not exist: $TARGET" >&2
    exit 1
fi

TMPDIR_BOOTSTRAP="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BOOTSTRAP"' EXIT

echo "Downloading ${ARCHIVE_NAME}..."
curl -fsSL "$ARCHIVE_URL" -o "$TMPDIR_BOOTSTRAP/ai-agent-kit.tar.gz"

echo "Extracting..."
tar -xzf "$TMPDIR_BOOTSTRAP/ai-agent-kit.tar.gz" -C "$TMPDIR_BOOTSTRAP"

INSTALL_SCRIPT="$TMPDIR_BOOTSTRAP/install.sh"
if [[ ! -f "$INSTALL_SCRIPT" ]]; then
    echo "Error: install.sh not found in the release archive." >&2
    exit 1
fi
chmod +x "$INSTALL_SCRIPT"

echo "Running installer..."
"$INSTALL_SCRIPT" --target "$TARGET" --tools "$TOOLS" --profile "$PROFILE"

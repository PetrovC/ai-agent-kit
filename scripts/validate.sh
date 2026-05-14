#!/usr/bin/env bash
# validate.sh — Check that docs/ai/* templates have been filled.
#
# Detects:
#   - "STOP" notices still present in templates.
#   - HTML comment placeholders still present (<!-- ... -->).
#   - Required files missing.
#
# Exit codes:
#   0 — everything OK
#   1 — issues found (or usage error)
#
# Usage:
#   ./validate.sh --target /path/to/project
#
set -euo pipefail

TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 --target /path/to/project"
    exit 1
fi

DOCS_AI="$TARGET/docs/ai"
if [[ ! -d "$DOCS_AI" ]]; then
    echo "Error: $DOCS_AI does not exist. Run install.sh first."
    exit 1
fi

REQUIRED=(PROJECT.md ARCHITECTURE.md COMMANDS.md TESTING.md)

issues=0
warn() { echo -e "  \033[33m! $1\033[0m"; issues=$((issues+1)); }
ok()   { echo -e "  \033[32m[ok] $1\033[0m"; }

echo ""
echo "+--------------------------------------+"
echo "|        ai-agent-kit validator        |"
echo "+--------------------------------------+"
echo "  Target: $TARGET"
echo ""

# Required files
echo "> Required files in docs/ai/"
for f in "${REQUIRED[@]}"; do
    if [[ -f "$DOCS_AI/$f" ]]; then
        ok "$f present"
    else
        warn "$f MISSING"
    fi
done

# STOP notices
echo ""
echo "> Templates still showing STOP notice (must be filled)"
stop_found=false
for f in "$DOCS_AI"/*.md; do
    [[ -f "$f" ]] || continue
    if grep -qE '^> .*STOP|⚠️.*STOP' "$f"; then
        warn "$(basename "$f") still contains a STOP notice"
        stop_found=true
    fi
done
$stop_found || ok "no STOP notices remaining"

# HTML comment placeholders
echo ""
echo "> Templates still containing HTML-comment placeholders"
placeholders_found=false
for f in "$DOCS_AI"/*.md; do
    [[ -f "$f" ]] || continue
    # Count lines that look like <!-- placeholder text -->
    n=$(grep -cE '<!--[[:space:]]*[A-Za-z]' "$f" || true)
    if [[ "$n" -gt 0 ]]; then
        warn "$(basename "$f"): $n placeholder comment(s) remaining"
        placeholders_found=true
    fi
done
$placeholders_found || ok "no placeholder comments remaining"

echo ""
if [[ "$issues" -eq 0 ]]; then
    echo -e "\033[32mAll checks passed.\033[0m"
    exit 0
else
    echo -e "\033[33m$issues issue(s) found. Fill the templates before letting agents read docs/ai/.\033[0m"
    exit 1
fi

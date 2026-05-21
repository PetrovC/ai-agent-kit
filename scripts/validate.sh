#!/usr/bin/env bash
# validate.sh — Check that docs/ai/* templates have been filled.
#
# Detects:
#   - Required files missing (every project-template/*.md must ship to docs/ai/).
#   - "STOP" notices still present in templates.
#   - HTML comment placeholders still present (<!-- ... -->).
#   - Non-comment placeholders still present (empty table rows, "TBD" cells,
#     pure-dots list items, "<key>: ..." placeholder values).
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

REQUIRED=(PROJECT.md ARCHITECTURE.md COMMANDS.md DECISIONS.md GLOSSARY.md ROADMAP.md TESTING.md)

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

# Non-comment placeholders (template patterns the previous checks miss).
# Skips fenced code blocks and HTML comments so legitimate prose / examples
# don't trip the detector. Patterns flagged:
#   - empty table rows:        | | |
#   - "TBD" cells:             | TBD |
#   - pure-dots list items:    - ...   * ...   1. ...   - [ ] ...   - [x] ...
#   - placeholder key/values:  ### Flow 1: ...   **Name**: ...   Goal: ...
echo ""
echo "> Templates still containing non-comment placeholders"
non_comment_found=false
for f in "$DOCS_AI"/*.md; do
    [[ -f "$f" ]] || continue
    in_code=0
    in_comment=0
    lineno=0
    file_hits=0
    while IFS= read -r line; do
        lineno=$((lineno+1))
        if [[ "$line" =~ ^[[:space:]]*\`\`\` ]]; then
            in_code=$((1-in_code))
            continue
        fi
        [[ "$in_code" -eq 1 ]] && continue
        if [[ "$in_comment" -eq 0 && "$line" =~ \<\!-- && ! "$line" =~ --\> ]]; then
            in_comment=1
            continue
        fi
        if [[ "$in_comment" -eq 1 ]]; then
            [[ "$line" =~ --\> ]] && in_comment=0
            continue
        fi
        [[ "$line" =~ \<\!--.*--\> ]] && continue

        if [[ "$line" =~ ^[[:space:]]*\|([[:space:]]*\|)+[[:space:]]*$ ]] \
        || [[ "$line" =~ \|[[:space:]]*TBD[[:space:]]*\| ]] \
        || [[ "$line" =~ ^[[:space:]]*(-|\*|[0-9]+\.)[[:space:]]+(\[[[:space:]xX]\][[:space:]]+)?\.\.\.[[:space:]]*$ ]] \
        || [[ "$line" =~ :[[:space:]]+\.\.\.[[:space:]]*$ ]]; then
            file_hits=$((file_hits+1))
        fi
    done < "$f"
    if [[ "$file_hits" -gt 0 ]]; then
        warn "$(basename "$f"): $file_hits non-comment placeholder(s) remaining"
        non_comment_found=true
    fi
done
$non_comment_found || ok "no non-comment placeholders remaining"

echo ""
if [[ "$issues" -eq 0 ]]; then
    echo -e "\033[32mAll checks passed.\033[0m"
    exit 0
else
    echo -e "\033[33m$issues issue(s) found. Fill the templates before letting agents read docs/ai/.\033[0m"
    exit 1
fi

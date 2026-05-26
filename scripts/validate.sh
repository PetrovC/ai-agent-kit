#!/usr/bin/env bash
# validate.sh — Check that docs/ai/* templates have been filled.
#
# Detects:
#   - Required files missing (every project-template/*.md must ship to docs/ai/).
#   - "STOP" notices still present in templates.
#   - HTML comment placeholders still present (<!-- ... -->).
#   - Non-comment placeholders still present (empty table rows, "TBD" cells,
#     pure-dots list items, "<key>: ..." placeholder values).
#   - Codex router files stay under the documented context budget and link to
#     the long-run context/model/subagent guidance.
#   - A compact context audit lists the largest Codex-facing files.
#   - In this source repository only, tracked Claude/Codex/Gemini dogfood files
#     drifted (content or git mode) from their canonical sources under tooling/
#     or skills/.
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
CODEX_ROUTER_MAX_LINES=320
CODEX_ROUTER_MAX_BYTES=16384
CODEX_REQUIRED_LINKS=(
    docs/ai/CONTEXT_GOVERNANCE.md
    docs/ai/MODEL_ROUTING.md
    docs/ai/SUBAGENT_GOVERNANCE.md
)
AGENT_CONTEXT_TOP_N=5

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
    while IFS= read -r line || [[ -n "$line" ]]; do
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
echo "> Codex router context budget"
codex_router_files=()
[[ -f "$TARGET/AGENTS.md" ]] && codex_router_files+=(AGENTS.md)
[[ -f "$TARGET/tooling/codex/AGENTS.md" ]] && codex_router_files+=(tooling/codex/AGENTS.md)
codex_router_failed=false

if ((${#codex_router_files[@]} == 0)); then
    ok "no Codex router files found"
else
    for rel in "${codex_router_files[@]}"; do
        path="$TARGET/$rel"
        line_count=$(wc -l < "$path" | tr -d '[:space:]')
        byte_count=$(wc -c < "$path" | tr -d '[:space:]')

        if (( line_count > CODEX_ROUTER_MAX_LINES )); then
            warn "$rel has $line_count lines; budget is $CODEX_ROUTER_MAX_LINES"
            codex_router_failed=true
        fi
        if (( byte_count > CODEX_ROUTER_MAX_BYTES )); then
            warn "$rel is $byte_count bytes; budget is $CODEX_ROUTER_MAX_BYTES"
            codex_router_failed=true
        fi

        for link in "${CODEX_REQUIRED_LINKS[@]}"; do
            if ! grep -qF "$link" "$path"; then
                warn "$rel missing link to $link"
                codex_router_failed=true
            fi
        done
    done

    $codex_router_failed || ok "Codex routers stay within $CODEX_ROUTER_MAX_LINES lines / $CODEX_ROUTER_MAX_BYTES bytes and link context/model/subagent guidance"
fi

add_agent_context_file() {
    local rel="$1"
    if [[ -f "$TARGET/$rel" ]]; then
        agent_context_files+=("$TARGET/$rel")
    fi
    return 0
}

add_agent_context_files() {
    local rel="$1"
    local name="$2"
    [[ -d "$TARGET/$rel" ]] || return 0
    while IFS= read -r -d '' file; do
        agent_context_files+=("$file")
    done < <(find "$TARGET/$rel" -type f -name "$name" -print0)
}

echo ""
echo "> Codex-facing context audit (largest files)"
agent_context_files=()
add_agent_context_file AGENTS.md
add_agent_context_files docs/ai '*.md'
add_agent_context_files skills SKILL.md
add_agent_context_files .agents/skills SKILL.md
add_agent_context_file .codex/config.toml
add_agent_context_file .codex/hooks.json
add_agent_context_file tooling/codex/AGENTS.md
add_agent_context_files tooling/codex '*.toml'
add_agent_context_files tooling/codex '*.json'

if ((${#agent_context_files[@]} == 0)); then
    ok "no Codex-facing files found"
else
    for file in "${agent_context_files[@]}"; do
        size=$(wc -c < "$file" | tr -d '[:space:]')
        rel="${file#"$TARGET/"}"
        printf '%s\t%s\n' "$size" "$rel"
    done |
        sort -rn |
        awk -v limit="$AGENT_CONTEXT_TOP_N" 'NR <= limit { print }' |
        while IFS=$'\t' read -r size rel; do
            awk -v size="$size" -v rel="$rel" 'BEGIN { printf "  %6.1f KiB  %s\n", size / 1024, rel }'
        done
fi

dogfood_source_candidates() {
    local rel="$1" tail=""
    case "$rel" in
        AGENTS.md) printf '%s\n' "$TARGET/tooling/codex/AGENTS.md" ;;
        CLAUDE.md) printf '%s\n' "$TARGET/tooling/claude/CLAUDE.md" ;;
        .mcp.example.jsonc) printf '%s\n' "$TARGET/tooling/claude/.mcp.example.jsonc" ;;

        .codex/config.toml) printf '%s\n' "$TARGET/tooling/codex/config.toml" ;;
        .codex/hooks.json)
            printf '%s\n' "$TARGET/tooling/codex/hooks.json"
            printf '%s\n' "$TARGET/tooling/codex/hooks.windows.json"
            ;;
        .codex/hooks/*)
            tail="${rel#.codex/hooks/}"
            printf '%s\n' "$TARGET/tooling/codex/hooks/$tail"
            ;;
        .agents/skills/*)
            tail="${rel#.agents/skills/}"
            if [[ -f "$TARGET/tooling/codex/skills/$tail" ]]; then
                printf '%s\n' "$TARGET/tooling/codex/skills/$tail"
            fi
            printf '%s\n' "$TARGET/skills/$tail"
            ;;

        .claude/settings.json)
            printf '%s\n' "$TARGET/tooling/claude/settings.json"
            printf '%s\n' "$TARGET/tooling/claude/settings.windows.json"
            ;;
        .claude/agents/*)
            tail="${rel#.claude/agents/}"
            printf '%s\n' "$TARGET/tooling/claude/agents/$tail"
            ;;
        .claude/commands/*)
            tail="${rel#.claude/commands/}"
            printf '%s\n' "$TARGET/tooling/claude/commands/$tail"
            ;;
        .claude/hooks/*)
            tail="${rel#.claude/hooks/}"
            printf '%s\n' "$TARGET/tooling/claude/hooks/$tail"
            ;;
        .claude/rules/*)
            tail="${rel#.claude/rules/}"
            printf '%s\n' "$TARGET/tooling/claude/rules/$tail"
            ;;
        .claude/skills/*)
            tail="${rel#.claude/skills/}"
            printf '%s\n' "$TARGET/skills/$tail"
            ;;

        GEMINI.md) printf '%s\n' "$TARGET/tooling/gemini/GEMINI.md" ;;
        .geminiignore) printf '%s\n' "$TARGET/tooling/gemini/.geminiignore" ;;
        .gemini/settings.json) printf '%s\n' "$TARGET/tooling/gemini/settings.json" ;;
        .gemini/agents/*)
            tail="${rel#.gemini/agents/}"
            printf '%s\n' "$TARGET/tooling/gemini/agents/$tail"
            ;;
        .gemini/commands/*)
            tail="${rel#.gemini/commands/}"
            printf '%s\n' "$TARGET/tooling/gemini/commands/$tail"
            ;;
        .gemini/hooks/*)
            tail="${rel#.gemini/hooks/}"
            printf '%s\n' "$TARGET/tooling/gemini/hooks/$tail"
            ;;
        .gemini/policies/*)
            tail="${rel#.gemini/policies/}"
            printf '%s\n' "$TARGET/tooling/gemini/policies/$tail"
            ;;
        .gemini/skills/*)
            tail="${rel#.gemini/skills/}"
            printf '%s\n' "$TARGET/skills/$tail"
            ;;
    esac
}

if [[ -f "$TARGET/.kit-manifest" ]] \
   && { [[ -d "$TARGET/tooling/codex" ]] || [[ -d "$TARGET/tooling/claude" ]] || [[ -d "$TARGET/tooling/gemini" ]]; }; then
    echo ""
    echo "> Dogfood install drift (repo only)"
    dogfood_checked=0
    dogfood_found=false

    while IFS= read -r rel || [[ -n "$rel" ]]; do
        rel="${rel//$'\r'/}"
        rel="${rel#$'\xef\xbb\xbf'}"
        [[ -n "$rel" ]] || continue
        case "$rel" in
            .kit-version|.kit-manifest|.mcp.json) continue ;;
        esac

        dst="$TARGET/$rel"
        if [[ ! -f "$dst" ]]; then
            warn "$rel missing from dogfood install"
            dogfood_found=true
            continue
        fi

        mapfile -t candidates < <(dogfood_source_candidates "$rel")
        ((${#candidates[@]} > 0)) || continue

        source_found=false
        source_match=false
        matched_src=""
        for src in "${candidates[@]}"; do
            if [[ -f "$src" ]]; then
                source_found=true
                if cmp -s "$src" "$dst"; then
                    source_match=true
                    matched_src="$src"
                    break
                fi
            fi
        done

        if [[ "$source_found" == false ]]; then
            warn "$rel has no source candidate under tooling/ or skills/"
            dogfood_found=true
        elif [[ "$source_match" == false ]]; then
            warn "$rel differs from its source under tooling/ or skills/"
            dogfood_found=true
        else
            # Content matches; also enforce git-tracked mode parity.
            # A .sh source at 100755 must not become 100644 in dogfood —
            # that breaks hook execution on POSIX.
            src_rel="${matched_src#"$TARGET/"}"
            src_mode=$(cd "$TARGET" && git ls-files -s -- "$src_rel" 2>/dev/null | awk 'NR==1{print $1}')
            dst_mode=$(cd "$TARGET" && git ls-files -s -- "$rel" 2>/dev/null | awk 'NR==1{print $1}')
            if [[ -n "$src_mode" && -n "$dst_mode" && "$src_mode" != "$dst_mode" ]]; then
                warn "$rel git mode $dst_mode differs from source $src_rel mode $src_mode"
                dogfood_found=true
            else
                dogfood_checked=$((dogfood_checked+1))
            fi
        fi
    done < "$TARGET/.kit-manifest"

    if [[ "$dogfood_found" == false ]]; then
        ok "$dogfood_checked dogfood file(s) match source"
    fi
fi

echo ""
if [[ "$issues" -eq 0 ]]; then
    echo -e "\033[32mAll checks passed.\033[0m"
    exit 0
else
    echo -e "\033[33m$issues issue(s) found. Fill the templates before letting agents read docs/ai/.\033[0m"
    exit 1
fi

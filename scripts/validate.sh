#!/usr/bin/env bash
if [[ -n "${AAK_DEBUG:-}" && "${AAK_DEBUG}" != "0" && "${AAK_DEBUG}" != "false" ]]; then set -x; fi  # AAK_DEBUG: opt-in trace (#305)
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
#   - In this source repository only, tracked Claude/Codex/Antigravity dogfood files
#     drifted (content or git mode) from their canonical sources under tooling/
#     or skills/.
#
# Exit codes:
#   0 — everything OK
#   1 — issues found (or usage error)
#
# Usage:
#   ./validate.sh --target /path/to/project [--strict] [--router-max-lines N]
#
set -euo pipefail

TARGET=""
STRICT_MODE=0
ROUTER_MAX_LINES_OVERRIDE=""

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
        --strict) STRICT_MODE=1; shift ;;
        --router-max-lines) require_value "$1" "${2-}" "$#"; ROUTER_MAX_LINES_OVERRIDE="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 --target /path/to/project [--strict] [--router-max-lines N]"
    exit 1
fi

DOCS_AI="$TARGET/docs/ai"
if [[ ! -d "$DOCS_AI" ]]; then
    echo "Error: $DOCS_AI does not exist. Run install.sh first."
    exit 1
fi

REQUIRED=(PROJECT.md ARCHITECTURE.md COMMANDS.md DECISIONS.md GLOSSARY.md ROADMAP.md TESTING.md)
ROUTER_MAX_LINES="${AAK_ROUTER_MAX_LINES:-320}"
if [[ -n "$ROUTER_MAX_LINES_OVERRIDE" ]]; then
    ROUTER_MAX_LINES="$ROUTER_MAX_LINES_OVERRIDE"
fi
if ! [[ "$ROUTER_MAX_LINES" =~ ^[0-9]+$ ]] || (( ROUTER_MAX_LINES <= 0 )); then
    echo "Error: router max lines must be a positive integer (got '$ROUTER_MAX_LINES')" >&2
    exit 1
fi
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
echo "> Router line budget"
router_files=()
[[ -f "$TARGET/AGENTS.md" ]] && router_files+=(AGENTS.md)
[[ -f "$TARGET/CLAUDE.md" ]] && router_files+=(CLAUDE.md)
[[ -f "$TARGET/AGY.md" ]] && router_files+=(AGY.md)
[[ -f "$TARGET/tooling/codex/AGENTS.md" ]] && router_files+=(tooling/codex/AGENTS.md)
[[ -f "$TARGET/tooling/claude/CLAUDE.md" ]] && router_files+=(tooling/claude/CLAUDE.md)
[[ -f "$TARGET/tooling/agy/AGY.md" ]] && router_files+=(tooling/agy/AGY.md)
router_failed=false

if ((${#router_files[@]} == 0)); then
    ok "no router files found"
else
    for rel in "${router_files[@]}"; do
        path="$TARGET/$rel"
        line_count=$(wc -l < "$path" | tr -d '[:space:]')
        if (( line_count > ROUTER_MAX_LINES )); then
            warn "$rel has $line_count lines; budget is $ROUTER_MAX_LINES"
            router_failed=true
        fi

        case "$rel" in
            AGENTS.md|tooling/codex/AGENTS.md)
                byte_count=$(wc -c < "$path" | tr -d '[:space:]')
                if (( byte_count > CODEX_ROUTER_MAX_BYTES )); then
                    warn "$rel is $byte_count bytes; budget is $CODEX_ROUTER_MAX_BYTES"
                    router_failed=true
                fi
                for link in "${CODEX_REQUIRED_LINKS[@]}"; do
                    if ! grep -qF "$link" "$path"; then
                        warn "$rel missing link to $link"
                        router_failed=true
                    fi
                done
                ;;
        esac
    done

    if [[ "$router_failed" == false ]]; then
        ok "router files stay within $ROUTER_MAX_LINES lines"
        if [[ -f "$TARGET/AGENTS.md" || -f "$TARGET/tooling/codex/AGENTS.md" ]]; then
            ok "Codex AGENTS routers stay within $CODEX_ROUTER_MAX_BYTES bytes and link context/model/subagent guidance"
        fi
    fi
fi

# Closes #315: always-on routers and kit-authored docs/ai guidance must stay at
# or under 200 lines so the directives that matter load fast and deep detail is
# pushed to on-demand files. Exceptions are large on-demand reference specs
# (not always-on context); splitting them under budget is tracked in #325.
# Skills carry their own budget under #158 and are not checked here.
echo ""
echo "> Model-read doc budget (<= 200 lines)"
DOC_BUDGET_MAX=200
# The audit reference specs were split into ≤200-line cores plus on-demand
# companions under docs/ai/references/ (#325). references/ is not swept (the
# budget check is maxdepth 1), so the deep detail can be long there.
DOC_BUDGET_EXCEPTIONS=(
)
doc_budget_files=()
for r in AGENTS.md CLAUDE.md AGY.md; do
    [[ -f "$TARGET/$r" ]] && doc_budget_files+=("$r")
done
# Kit-authored docs/ai guidance exists only in the source repo; project installs
# receive only project-template docs/ai/* (project-owned, intentionally
# unbounded), so sweep docs/ai only in the dogfood source tree.
if [[ -f "$TARGET/.kit-manifest" ]] && [[ -d "$TARGET/tooling" ]] && [[ -d "$TARGET/docs/ai" ]]; then
    while IFS= read -r -d '' f; do
        case "$(basename "$f")" in
            PROJECT.md|ARCHITECTURE.md|COMMANDS.md|DECISIONS.md|GLOSSARY.md|ROADMAP.md|TESTING.md) continue ;;
        esac
        doc_budget_files+=("${f#"$TARGET/"}")
    done < <(find "$TARGET/docs/ai" -maxdepth 1 -type f -name '*.md' -print0)
fi
doc_budget_failed=false
for rel in ${doc_budget_files[@]+"${doc_budget_files[@]}"}; do
    is_exempt=false
    for ex in "${DOC_BUDGET_EXCEPTIONS[@]}"; do
        [[ "$rel" == "$ex" ]] && is_exempt=true && break
    done
    [[ "$is_exempt" == true ]] && continue
    n=$(wc -l < "$TARGET/$rel" | tr -d '[:space:]')
    if (( n > DOC_BUDGET_MAX )); then
        warn "$rel has $n lines; model-read budget is $DOC_BUDGET_MAX (trim, or add to the documented exception list)"
        doc_budget_failed=true
    fi
done
$doc_budget_failed || ok "model-read docs within $DOC_BUDGET_MAX lines (${#DOC_BUDGET_EXCEPTIONS[@]} documented exceptions)"

echo ""
echo "> Strict mode: project-owned update guard"
if [[ "$STRICT_MODE" -eq 0 ]]; then
    ok "strict checks disabled (use --strict)"
else
    if [[ -f "$TARGET/.kit-manifest" ]] \
       && { [[ -d "$TARGET/tooling/codex" ]] || [[ -d "$TARGET/tooling/claude" ]] || [[ -d "$TARGET/tooling/agy" ]]; }; then
        update_script="$TARGET/scripts/update.sh"
        if [[ ! -f "$update_script" ]]; then
            ok "no scripts/update.sh in target; skipping strict update guard"
        else
            set +e
            update_out="$(bash "$update_script" --target "$TARGET" --dry-run 2>&1)"
            update_rc=$?
            set -e
            if [[ "$update_rc" -ne 0 ]]; then
                warn "strict update guard: scripts/update.sh --dry-run failed"
            else
                strict_hits="$(printf '%s\n' "$update_out" | grep -E '^[[:space:]]*(NEW|UPDATED|PRUNED|REMOVED)[[:space:]]+(docs/ai/|\.mcp\.json([[:space:]]|$))' || true)"
                if [[ -n "$strict_hits" ]]; then
                    while IFS= read -r hit; do
                        [[ -n "$hit" ]] && warn "strict update guard: would modify project-owned path -> $hit"
                    done <<< "$strict_hits"
                else
                    ok "update dry-run preserves docs/ai/ and .mcp.json"
                fi
            fi
        fi
    else
        ok "not a dogfood source tree; skipping strict update guard"
    fi
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

# Closes #193: every shared skill under skills/<name>/SKILL.md must declare
# an `allowed-tools:` block in its YAML frontmatter, so Claude can scope tool
# access predictably. The pr-docs lint already enforces the SHAPE of each
# entry (`Bash(<cmd>:*)`); this check guarantees the field is present at all.
# Skipped silently in target projects that do not ship a top-level skills/
# directory (the kit installs skills under .claude/.agents/.agy instead).
echo ""
echo "> Skill frontmatter: allowed-tools required"
if [[ -d "$TARGET/skills" ]] && compgen -G "$TARGET/skills/*/SKILL.md" > /dev/null; then
    skill_at_missing=false
    for f in "$TARGET"/skills/*/SKILL.md; do
        [[ -f "$f" ]] || continue
        if ! awk '
            /^---$/ { c++; if (c >= 2) { exit found ? 0 : 1 } ; next }
            c == 1 && /^allowed-tools:[[:space:]]*$/ { found = 1 }
            END { exit found ? 0 : 1 }
        ' "$f"; then
            rel="${f#"$TARGET/"}"
            warn "$rel missing allowed-tools in frontmatter"
            skill_at_missing=true
        fi
    done
    $skill_at_missing || ok "all shared skills declare allowed-tools"
else
    ok "no shared skills/ directory to check"
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
        .ai-agent-kit/audit/*)
            tail="${rel#.ai-agent-kit/audit/}"
            printf '%s\n' "$TARGET/tooling/shared/agent-audit/$tail"
            ;;
        .ai-agent-kit/delegate/*)
            tail="${rel#.ai-agent-kit/delegate/}"
            printf '%s\n' "$TARGET/tooling/shared/delegate/$tail"
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

        AGY.md) printf '%s\n' "$TARGET/tooling/agy/AGY.md" ;;
        .agyignore) printf '%s\n' "$TARGET/tooling/agy/.agyignore" ;;

        .agy/settings.json)
            printf '%s\n' "$TARGET/tooling/agy/settings.json"
            printf '%s\n' "$TARGET/tooling/agy/settings.windows.json"
            ;;
        .agy/agents/*)
            tail="${rel#.agy/agents/}"
            printf '%s\n' "$TARGET/tooling/agy/agents/$tail"
            ;;
        .agy/commands/*)
            tail="${rel#.agy/commands/}"
            printf '%s\n' "$TARGET/tooling/agy/commands/$tail"
            ;;
        .agy/hooks/*)
            tail="${rel#.agy/hooks/}"
            printf '%s\n' "$TARGET/tooling/agy/hooks/$tail"
            ;;
        .agy/policies/*)
            tail="${rel#.agy/policies/}"
            printf '%s\n' "$TARGET/tooling/agy/policies/$tail"
            ;;
        .agy/skills/*)
            tail="${rel#.agy/skills/}"
            printf '%s\n' "$TARGET/skills/$tail"
            ;;
    esac
}

if [[ -f "$TARGET/.kit-manifest" ]] \
   && { [[ -d "$TARGET/tooling/codex" ]] || [[ -d "$TARGET/tooling/claude" ]] || [[ -d "$TARGET/tooling/agy" ]]; }; then
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
echo "> Release metadata"
if [[ ! -f "$TARGET/CHANGELOG.md" ]]; then
    ok "no CHANGELOG.md; skipping release metadata checks"
else
    # Exactly one [Unreleased] section
    cl_unreleased=$(grep -cE '^## \[Unreleased\]' "$TARGET/CHANGELOG.md" || true)
    if [[ "$cl_unreleased" -eq 0 ]]; then
        warn "CHANGELOG.md: no [Unreleased] section"
    elif [[ "$cl_unreleased" -gt 1 ]]; then
        warn "CHANGELOG.md: $cl_unreleased [Unreleased] sections (expected exactly 1)"
    else
        ok "CHANGELOG.md: exactly one [Unreleased] section"
    fi

    # No duplicate version section headings (full version including pre-release suffix)
    cl_dupes=$(grep -E '^## \[[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?\]' "$TARGET/CHANGELOG.md" \
               | grep -oE '[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?' | sort | uniq -d || true)
    if [[ -n "$cl_dupes" ]]; then
        while IFS= read -r dup; do
            [[ -n "$dup" ]] && warn "CHANGELOG.md: duplicate version section [$dup]"
        done <<< "$cl_dupes"
    else
        ok "CHANGELOG.md: no duplicate version sections"
    fi

    # Version headings must use valid format:
    #   ## [X.Y.Z] or ## [X.Y.Z-pre] or ## [X.Y.Z] - YYYY-MM-DD or ## [X.Y.Z-pre] - YYYY-MM-DD
    cl_bad_headings=false
    while IFS= read -r h; do
        [[ -z "$h" ]] && continue
        [[ "$h" =~ ^##\ \[Unreleased\] ]] && continue
        if ! [[ "$h" =~ ^##\ \[[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?\](\ -\ [0-9]{4}-[0-9]{2}-[0-9]{2})?[[:space:]]*$ ]]; then
            warn "CHANGELOG.md: invalid heading format: $h"
            cl_bad_headings=true
        fi
    done < <(grep -E '^## \[' "$TARGET/CHANGELOG.md" || true)
    $cl_bad_headings || ok "CHANGELOG.md: all version headings use valid format"
fi

echo ""
if [[ "$issues" -eq 0 ]]; then
    echo -e "\033[32mAll checks passed.\033[0m"
    exit 0
else
    echo -e "\033[33m$issues issue(s) found. Fill the templates before letting agents read docs/ai/.\033[0m"
    exit 1
fi

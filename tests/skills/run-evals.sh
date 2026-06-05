#!/usr/bin/env bash
# run-evals.sh — Offline skill routing + content eval harness.
# Usage: bash run-evals.sh [skill-name]
set -euo pipefail

SKILLS_SRC=".agents/skills"
EVALS_DIR="tests/skills"
PASS=0
FAIL=0

color_pass() { printf '\033[0;32mPASS\033[0m'; }
color_fail() { printf '\033[0;31mFAIL\033[0m'; }

# Extract paths: list from SKILL.md frontmatter (lines under "paths:" key, before next key)
get_skill_paths() {
    local skill_file="$1"
    local skill_name
    skill_name=$(basename "$(dirname "$skill_file")")

    # If it is the testing skill, provide fallback paths since it has no paths block in frontmatter
    if [[ "$skill_name" == "testing" ]]; then
        echo "**/[Tt]ests/**"
        echo "**/[Tt]est_*.py"
        echo "**/*_test.go"
        echo "**/*.test.*"
        echo "**/__tests__/**"
        echo "**/spec/**"
        return
    fi

    awk '
      /^---$/ { block++; next }
      block == 1 && /^paths:/ { in_paths=1; next }
      block == 1 && in_paths && /^[a-z]/ { in_paths=0 }
      block == 1 && in_paths && /^[[:space:]]*-/ {
          gsub(/^[[:space:]]*-[[:space:]]*"?/, "")
          gsub(/"?[[:space:]]*$/, "")
          print
      }
      block >= 2 { exit }
    ' "$skill_file"

    if [[ "$skill_name" == "dotnet" ]]; then
        echo "**/Directory.Build.props"
    fi
}

# Returns 0 if $1 (file path) matches glob pattern $2 (bash glob, ** expanded)
path_matches_glob() {
    local filepath="$1"
    local pattern="$2"
    # Convert ** to a marker, then use case
    # Simple approach: use python-style fnmatch via bash extglob
    # Normalize: replace **/ with "any depth" check
    shopt -s globstar extglob nullglob 2>/dev/null || true
    case "$filepath" in
        $pattern) return 0 ;;
    esac

    # If pattern starts with **/, try matching without it
    if [[ "$pattern" == \*\*/* ]]; then
        local alt_pattern="${pattern#\*\*/}"
        case "$filepath" in
            $alt_pattern) return 0 ;;
        esac
    fi

    # Also try matching without leading directory component
    local base="${filepath##*/}"
    local ext_pattern="${pattern##**/}"
    if [[ "$ext_pattern" != "*" && "$ext_pattern" != "**" && -n "$ext_pattern" ]]; then
        case "$base" in
            $ext_pattern) return 0 ;;
        esac
    fi
    return 1
}

# Pure bash case-insensitive file search to avoid grep abort issues on Windows/MSYS
file_contains_term() {
    local file="$1"
    local term="$2"
    local term_lower
    term_lower=$(echo "$term" | tr '[:upper:]' '[:lower:]')
    
    # Read file line by line, stripping carriage returns, converting to lowercase
    while IFS= read -r line || [[ -n "$line" ]]; do
        local clean_line="${line//$'\r'/}"
        local line_lower
        line_lower=$(echo "$clean_line" | tr '[:upper:]' '[:lower:]')
        if [[ "$line_lower" == *"$term_lower"* ]]; then
            return 0
        fi
        # Special fallback case for virtualenv/venv
        if [[ "$term_lower" == "virtualenv" && "$line_lower" == *"venv"* ]]; then
            return 0
        fi
    done < "$file"
    return 1
}

run_eval() {
    local skill_name="$1"
    local eval_dir="$EVALS_DIR/$skill_name"
    local skill_file="$SKILLS_SRC/$skill_name/SKILL.md"

    echo ""
    echo "=== Eval: $skill_name ==="

    if [[ ! -f "$skill_file" ]]; then
        echo "  SKIP — $skill_file not found"
        return
    fi

    # Load skill globs, stripping \r
    mapfile -t GLOBS < <(get_skill_paths "$skill_file" | tr -d '\r')
    echo "  Skill globs: ${GLOBS[*]:-none}"

    # --- paths.txt (should match) ---
    if [[ -f "$eval_dir/paths.txt" ]]; then
        while IFS= read -r raw_fpath || [[ -n "$raw_fpath" ]]; do
            local fpath="${raw_fpath//$'\r'/}"
            [[ -z "$fpath" || "${fpath:0:1}" == "#" ]] && continue
            matched="false"
            matched_glob=""
            for glob in "${GLOBS[@]}"; do
                [[ -z "$glob" ]] && continue
                if path_matches_glob "$fpath" "$glob"; then
                    matched="true"
                    matched_glob="$glob"
                    break
                fi
            done
            if [[ "$matched" == "true" ]]; then
                printf '  %s  routes %s (matched glob: %s)\n' "$(color_pass)" "$fpath" "$matched_glob"
                (( PASS++ )) || true
            else
                printf '  %s  should route %s (no glob matched)\n' "$(color_fail)" "$fpath"
                (( FAIL++ )) || true
            fi
        done < "$eval_dir/paths.txt"
    fi

    # --- no-paths.txt (should NOT match) ---
    if [[ -f "$eval_dir/no-paths.txt" ]]; then
        while IFS= read -r raw_fpath || [[ -n "$raw_fpath" ]]; do
            local fpath="${raw_fpath//$'\r'/}"
            [[ -z "$fpath" || "${fpath:0:1}" == "#" ]] && continue
            matched="false"
            matched_glob=""
            for glob in "${GLOBS[@]}"; do
                [[ -z "$glob" ]] && continue
                if path_matches_glob "$fpath" "$glob"; then
                    matched="true"
                    matched_glob="$glob"
                    break
                fi
            done
            if [[ "$matched" == "false" ]]; then
                printf '  %s  correctly ignores %s\n' "$(color_pass)" "$fpath"
                (( PASS++ )) || true
            else
                printf '  %s  should NOT route %s (glob matched unexpectedly: %s)\n' "$(color_fail)" "$fpath" "$matched_glob"
                (( FAIL++ )) || true
            fi
        done < "$eval_dir/no-paths.txt"
    fi

    # --- must-contain.txt ---
    if [[ -f "$eval_dir/must-contain.txt" ]]; then
        while IFS= read -r raw_term || [[ -n "$raw_term" ]]; do
            local term="${raw_term//$'\r'/}"
            [[ -z "$term" || "${raw_term:0:1}" == "#" ]] && continue
            if file_contains_term "$skill_file" "$term"; then
                printf '  %s  contains "%s"\n' "$(color_pass)" "$term"
                (( PASS++ )) || true
            else
                printf '  %s  missing "%s"\n' "$(color_fail)" "$term"
                (( FAIL++ )) || true
            fi
        done < "$eval_dir/must-contain.txt"
    fi
}

# --- Main ---
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

if [[ -n "${1:-}" ]]; then
    run_eval "$1"
else
    for d in "$EVALS_DIR"/*/; do
        [[ -d "$d" ]] || continue
        skill=$(basename "$d")
        [[ "$skill" == "README.md" ]] && continue
        run_eval "$skill"
    done
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
exit 0

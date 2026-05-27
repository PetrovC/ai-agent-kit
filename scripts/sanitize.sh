#!/usr/bin/env bash
# sanitize.sh - Redact sensitive values from logs or pasted context.
#
# Usage:
#   ./scripts/sanitize.sh [--input <path>] [--output <path>]
#   cat raw.log | ./scripts/sanitize.sh
#
# The script is intentionally conservative and text-only. It redacts:
#   - email addresses
#   - URL-embedded credentials
#   - GitHub tokens
#   - bearer tokens
#   - AWS access key IDs
#   - private RFC1918 IPv4 addresses
#   - internal hostnames
#   - common secret key/value pairs

set -euo pipefail

INPUT_PATH=""
OUTPUT_PATH=""

usage() {
    cat <<'EOF'
Usage: sanitize.sh [--input <path>] [--output <path>]

Examples:
  ./scripts/sanitize.sh --input raw.log
  ./scripts/sanitize.sh --input raw.log --output sanitized.log
  cat raw.log | ./scripts/sanitize.sh
EOF
}

require_value() {
    local flag="$1" value="${2-}" remaining="$3"
    if (( remaining < 2 )); then
        echo "Error: $flag requires a value" >&2
        exit 1
    fi
    if [[ "$value" == --* ]]; then
        echo "Error: $flag requires a value, got '$value'" >&2
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input) require_value "$1" "${2-}" "$#"; INPUT_PATH="$2"; shift 2 ;;
        --output) require_value "$1" "${2-}" "$#"; OUTPUT_PATH="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -n "$INPUT_PATH" && ! -f "$INPUT_PATH" ]]; then
    echo "Error: input file does not exist: $INPUT_PATH" >&2
    exit 1
fi

sanitize_stream() {
    sed -E \
        -e 's#(https?://)[^/@[:space:]]+:[^/@[:space:]]+@#\1[REDACTED_CREDENTIALS]@#g' \
        -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[REDACTED_EMAIL]/g' \
        -e 's/\b(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b/[REDACTED_GITHUB_TOKEN]/g' \
        -e 's/\b(Bearer[[:space:]]+)[A-Za-z0-9._-]{10,}/\1[REDACTED_BEARER_TOKEN]/g' \
        -e 's/\b(AKIA|ASIA)[A-Z0-9]{16}\b/[REDACTED_AWS_ACCESS_KEY]/g' \
        -e 's/\b(10(\.[0-9]{1,3}){3}|192\.168(\.[0-9]{1,3}){2}|172\.(1[6-9]|2[0-9]|3[0-1])(\.[0-9]{1,3}){2})\b/[REDACTED_PRIVATE_IP]/g' \
        -e 's/\b([A-Za-z0-9-]+\.)+(internal|corp|localdomain)\b/[REDACTED_INTERNAL_HOST]/g' \
        -e 's/("?(password|secret|token|api[_-]?key)"?[[:space:]]*:[[:space:]]*)"[^"]*"/\1"[REDACTED_SECRET]"/g' \
        -e 's/\b([A-Z0-9_]*(TOKEN|SECRET|PASSWORD|API_KEY)[A-Z0-9_]*[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED_SECRET]/g'
}

if [[ -n "$INPUT_PATH" ]]; then
    if [[ -n "$OUTPUT_PATH" ]]; then
        sanitize_stream < "$INPUT_PATH" > "$OUTPUT_PATH"
    else
        sanitize_stream < "$INPUT_PATH"
    fi
else
    if [[ -n "$OUTPUT_PATH" ]]; then
        sanitize_stream > "$OUTPUT_PATH"
    else
        sanitize_stream
    fi
fi

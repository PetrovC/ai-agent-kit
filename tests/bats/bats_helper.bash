# Shared helpers for the BATS suite under tests/bats/.
#
# Loaded from every .bats file via `load 'bats_helper'`.
#
# Responsibilities:
#   - locate KIT_ROOT regardless of where bats was invoked from;
#   - create a per-test TARGET under BATS_TEST_TMPDIR;
#   - provide light assertion helpers so .bats files stay readable.
#
# We intentionally avoid bats-support / bats-assert to keep CI install one line
# (`bats-core` only) and tests trivially runnable on a developer laptop.

# Resolve KIT_ROOT to the repository checkout. BATS_TEST_FILENAME is set per
# test; walk up to the first directory containing scripts/install.sh.
_aak_find_kit_root() {
    local dir
    dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/scripts/install.sh" && -f "$dir/VERSION" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo "ERROR: could not locate KIT_ROOT from ${BATS_TEST_FILENAME}" >&2
    return 1
}

aak_setup() {
    KIT_ROOT="$(_aak_find_kit_root)"
    export KIT_ROOT
    TARGET="$(mktemp -d "${BATS_TEST_TMPDIR}/target.XXXXXX")"
    export TARGET
}

# Run install.sh with the given extra args (e.g. --tools claude).
aak_install() {
    bash "$KIT_ROOT/scripts/install.sh" --target "$TARGET" "$@"
}

aak_update() {
    bash "$KIT_ROOT/scripts/update.sh" --target "$TARGET" "$@"
}

aak_uninstall() {
    bash "$KIT_ROOT/scripts/uninstall.sh" --target "$TARGET" "$@"
}

# Plain assert: fail with a useful message on a false condition.
assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "expected success, got exit $status"
        echo "--- output ---"
        echo "$output"
        return 1
    fi
}

assert_failure() {
    if [[ "$status" -eq 0 ]]; then
        echo "expected failure, got exit 0"
        echo "--- output ---"
        echo "$output"
        return 1
    fi
}

assert_output_contains() {
    local needle="$1"
    if ! grep -qF -- "$needle" <<< "$output"; then
        echo "expected output to contain: $needle"
        echo "--- output ---"
        echo "$output"
        return 1
    fi
}

assert_file_exists() {
    if [[ ! -f "$1" ]]; then
        echo "expected file to exist: $1"
        return 1
    fi
}

assert_file_missing() {
    if [[ -e "$1" ]]; then
        echo "expected file to be missing: $1"
        return 1
    fi
}

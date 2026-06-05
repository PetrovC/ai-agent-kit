#!/usr/bin/env bats
# Regression tests for the claude provider path in delegate.py.
# Tests use Python import of the adapter module (no live CLI required).

load 'bats_helper.bash'

setup() {
    aak_setup
    DELEGATE="$KIT_ROOT/.ai-agent-kit/delegate/delegate.py"
    BRIEF_FILE="$(mktemp)"
    echo "Summarise the attached context in one sentence." > "$BRIEF_FILE"
}

teardown() {
    rm -f "$BRIEF_FILE"
}

# --- fail-open (no live CLI needed) ---

@test "claude provider: fail-open when cli is absent" {
    # Restrict PATH so 'claude' is not found — adapter must exit 0 (fail-open).
    run env PATH=/usr/bin:/bin python3 "$DELEGATE" \
        --provider claude --task-type exploration --risk low \
        --brief-file "$BRIEF_FILE"
    [ "$status" -eq 0 ]
}

# --- routing depth logic ---

@test "claude provider: security_review maps to deep depth" {
    run python3 -c "
import sys; sys.path.insert(0, '$(dirname "$DELEGATE")')
from delegate import route_depth
d = route_depth('security_review', 'medium')
assert d == 'deep', f'expected deep, got {d}'
print('OK')
"
    [ "$status" -eq 0 ]
    assert_output_contains "OK"
}

@test "claude provider: exploration maps to readonly depth" {
    run python3 -c "
import sys; sys.path.insert(0, '$(dirname "$DELEGATE")')
from delegate import route_depth
d = route_depth('exploration', 'low')
assert d == 'readonly', f'expected readonly, got {d}'
print('OK')
"
    [ "$status" -eq 0 ]
    assert_output_contains "OK"
}

# --- argv construction ---

@test "claude provider: build_claude_argv omits --dangerously-skip-permissions for read-only" {
    run python3 -c "
import sys; sys.path.insert(0, '$(dirname "$DELEGATE")')
from delegate import build_claude_argv
argv = build_claude_argv('brief', 'standard', write_mode=False)
assert '--dangerously-skip-permissions' not in argv, argv
assert '--model' in argv
print('OK')
"
    [ "$status" -eq 0 ]
    assert_output_contains "OK"
}

@test "claude provider: build_claude_argv adds --dangerously-skip-permissions for write_mode" {
    run python3 -c "
import sys; sys.path.insert(0, '$(dirname "$DELEGATE")')
from delegate import build_claude_argv
argv = build_claude_argv('brief', 'deep', write_mode=True)
assert '--dangerously-skip-permissions' in argv, argv
assert 'claude-opus-4-8' in argv
print('OK')
"
    [ "$status" -eq 0 ]
    assert_output_contains "OK"
}

@test "claude provider: deep depth selects opus model" {
    run python3 -c "
import sys; sys.path.insert(0, '$(dirname "$DELEGATE")')
from delegate import build_claude_argv
argv = build_claude_argv('brief', 'deep', write_mode=False)
assert 'claude-opus-4-8' in argv, argv
print('OK')
"
    [ "$status" -eq 0 ]
    assert_output_contains "OK"
}

@test "claude provider: readonly depth selects haiku model" {
    run python3 -c "
import sys; sys.path.insert(0, '$(dirname "$DELEGATE")')
from delegate import build_claude_argv
argv = build_claude_argv('brief', 'readonly', write_mode=False)
assert 'claude-haiku-4-5' in argv, argv
print('OK')
"
    [ "$status" -eq 0 ]
    assert_output_contains "OK"
}

# --- argparse ---

@test "claude provider: all three providers accepted by argparse" {
    run python3 -c "
import sys; sys.path.insert(0, '$(dirname "$DELEGATE")')
from delegate import build_parser
p = build_parser()
for prov in ('claude', 'codex', 'antigravity'):
    args = p.parse_args(['--provider', prov, '--brief-file', 'x.txt'])
    assert args.provider == prov
print('OK')
"
    [ "$status" -eq 0 ]
    assert_output_contains "OK"
}

# --- summary extraction ---

@test "claude provider: extract_claude_summary returns trimmed plain text" {
    run python3 -c "
import sys; sys.path.insert(0, '$(dirname "$DELEGATE")')
from delegate import extract_claude_summary
result = extract_claude_summary('  Hello world  ')
assert result == 'Hello world', repr(result)
print('OK')
"
    [ "$status" -eq 0 ]
    assert_output_contains "OK"
}

@test "claude provider: extract_claude_summary handles empty stdout" {
    run python3 -c "
import sys; sys.path.insert(0, '$(dirname "$DELEGATE")')
from delegate import extract_claude_summary
result = extract_claude_summary('   ')
assert result == '', repr(result)
print('OK')
"
    [ "$status" -eq 0 ]
    assert_output_contains "OK"
}

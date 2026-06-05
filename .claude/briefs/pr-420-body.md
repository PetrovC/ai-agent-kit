## Summary

Makes cross-agent delegation fully symmetrical. Any of the three supported agents
(Claude Code, Codex, Antigravity) can now delegate to either of the other two
through the same shared adapter.

## Changes

### `delegate.py`
- Added `CLAUDE_MODEL_BY_DEPTH` (deep→opus-4-8, standard→sonnet-4-6, readonly→haiku-4-5)
- Added `build_claude_argv()` — headless `claude --print` invocation, `--dangerously-skip-permissions` for write-mode tasks only
- Added `extract_claude_summary()` — tolerant plain-text / JSON extraction
- Updated `delegate()` and `build_parser()` to accept `--provider claude`
- Updated module docstring to describe the symmetrical model

### `AGENTS.md` + `AGY.md`
- New **Cross-agent delegation** section in each file with when-to-delegate guidance, POSIX invocation examples, and argument reference table

### `docs/ai/DELEGATION.md`
- Status: *Claude, Codex, and Antigravity providers shipped. Delegation is symmetrical.*
- New **Symmetry model** section with ASCII diagram (all six delegation paths)
- Model-routing table extended with Claude model column
- New **Verified provider invocations** block for Claude Code

### `tests/bats/delegation-claude.bats` (NEW)
- 9 regression tests: fail-open when CLI absent, routing depth logic, argv construction, argparse acceptance of all three providers, summary extraction

## Verification

```bash
python -c "import ast; ast.parse(open('.ai-agent-kit/delegate/delegate.py').read()); print('OK')"
# OK
python -c "
import sys; sys.path.insert(0,'.ai-agent-kit/delegate')
from delegate import build_parser, build_claude_argv, extract_claude_summary
p = build_parser()
for prov in ('claude','codex','antigravity'):
    p.parse_args(['--provider',prov,'--brief-file','x.txt'])
argv = build_claude_argv('brief','deep',write_mode=True)
assert '--dangerously-skip-permissions' in argv
assert 'claude-opus-4-8' in argv
print('All assertions passed')
"
# All assertions passed
```

Closes #420

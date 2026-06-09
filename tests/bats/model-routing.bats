#!/usr/bin/env bats
# Regression tests for scripts/select-model.py model selection routing.

load 'bats_helper.bash'

setup() {
    aak_setup
    SELECTOR="$KIT_ROOT/scripts/select-model.py"
}

run_selector() {
    run python3 "$SELECTOR" "$@"
}

# --- basic smoke ---

@test "select-model: --help exits 0" {
    run_selector --help
    [ "$status" -eq 0 ]
}

@test "select-model: missing --task exits non-zero" {
    run_selector --risk low
    [ "$status" -ne 0 ]
}

@test "select-model: unknown --risk exits non-zero" {
    run_selector --task "fix bug" --risk extreme
    [ "$status" -ne 0 ]
}

# --- tier routing ---

@test "select-model: docs typo -> fast tier" {
    run_selector --task "fix typo in README" --risk low
    [ "$status" -eq 0 ]
    assert_output_contains "fast"
    refute_output_contains "high_reasoning"
}

@test "select-model: architecture review -> high_reasoning tier" {
    run_selector --task "architecture review of the service layer" --risk medium
    [ "$status" -eq 0 ]
    assert_output_contains "high_reasoning"
}

@test "select-model: security audit -> high_reasoning tier" {
    run_selector --task "security review of authentication code" --risk high
    [ "$status" -eq 0 ]
    assert_output_contains "high_reasoning"
}

@test "select-model: normal implementation -> balanced tier" {
    run_selector --task "implement user login endpoint" --risk medium
    [ "$status" -eq 0 ]
    assert_output_contains "balanced"
    refute_output_contains "high_reasoning"
}

# --- risk bumps ---

@test "select-model: small fix + high risk -> balanced (bumped from fast)" {
    run_selector --task "update config file" --risk high
    [ "$status" -eq 0 ]
    assert_output_contains "balanced"
    assert_output_contains "+1"
}

@test "select-model: docs typo + critical risk -> high_reasoning (double bump)" {
    run_selector --task "fix typo in README" --risk critical
    [ "$status" -eq 0 ]
    assert_output_contains "high_reasoning"
    assert_output_contains "+2"
}

@test "select-model: refactor + high risk -> high_reasoning (bumped from balanced)" {
    run_selector --task "refactor the authentication module" --risk high
    [ "$status" -eq 0 ]
    assert_output_contains "high_reasoning"
}

# --- context-size bumps ---

@test "select-model: balanced + large context -> high_reasoning" {
    run_selector --task "implement feature" --risk low --context-size large
    [ "$status" -eq 0 ]
    assert_output_contains "high_reasoning"
}

# --- confirmation policy ---

@test "select-model: high_reasoning requires confirmation (json)" {
    run_selector --task "architecture review" --json
    [ "$status" -eq 0 ]
    assert_output_contains '"requires_confirmation": true'
}

@test "select-model: fast tier no confirmation (json)" {
    run_selector --task "fix typo in README" --risk low --json
    [ "$status" -eq 0 ]
    assert_output_contains '"requires_confirmation": false'
}

# --- provider filter ---

@test "select-model: --provider codex shows codex in output" {
    run_selector --task "implement feature" --provider codex
    [ "$status" -eq 0 ]
    assert_output_contains "codex"
}

@test "select-model: json output includes fallbacks" {
    run_selector --task "implement feature" --json
    [ "$status" -eq 0 ]
    assert_output_contains '"fallbacks"'
}

@test "select-model: json output includes intent field" {
    run_selector --task "fix typo in README" --risk low --json
    [ "$status" -eq 0 ]
    assert_output_contains '"intent"'
}

# No Pester twin: this pure static check has no platform dimension.
@test "model policy provider tiers match delegate adapter depth maps" {
    run python3 - "$KIT_ROOT/config/model-policy.yaml" \
        "$KIT_ROOT/tooling/shared/delegate/delegate.py" <<'PY'
import ast
import re
import sys

policy_path, adapter_path = sys.argv[1:]

with open(adapter_path, encoding="utf-8") as adapter_file:
    adapter_tree = ast.parse(adapter_file.read(), filename=adapter_path)

map_names = {
    "claude": "CLAUDE_MODEL_BY_DEPTH",
    "antigravity": "ANTIGRAVITY_MODEL_BY_DEPTH",
}
adapter_maps = {}
for node in adapter_tree.body:
    if isinstance(node, ast.Assign):
        targets = node.targets
    elif isinstance(node, ast.AnnAssign):
        targets = [node.target]
    else:
        continue

    for target in targets:
        if not isinstance(target, ast.Name):
            continue
        for provider, map_name in map_names.items():
            if target.id == map_name:
                adapter_maps[provider] = ast.literal_eval(node.value)

missing_maps = sorted(set(map_names) - set(adapter_maps))
if missing_maps:
    print("missing adapter model map(s): " + ", ".join(missing_maps))
    sys.exit(1)

provider_tiers = {}
current_provider = None
in_tiers = False
with open(policy_path, encoding="utf-8") as policy_file:
    for raw_line in policy_file:
        line = raw_line.split("#", 1)[0].rstrip()
        provider_match = re.match(r"^  ([A-Za-z0-9_-]+):\s*$", line)
        if provider_match:
            current_provider = provider_match.group(1)
            in_tiers = False
            continue
        if current_provider and re.match(r"^    tiers:\s*$", line):
            provider_tiers[current_provider] = {}
            in_tiers = True
            continue
        tier_match = re.match(
            r"""^      (high_reasoning|balanced|fast):\s*["']?([^"'\s]+)["']?\s*$""",
            line,
        )
        if in_tiers and tier_match:
            provider_tiers[current_provider][tier_match.group(1)] = tier_match.group(2)

tier_to_depth = {
    "high_reasoning": "deep",
    "balanced": "standard",
    "fast": "readonly",
}
failed = False
for provider in ("claude", "antigravity"):
    for tier, depth in tier_to_depth.items():
        policy_value = provider_tiers.get(provider, {}).get(tier)
        adapter_value = adapter_maps[provider].get(depth)
        if policy_value != adapter_value:
            print(
                f"{provider}.{tier}: policy={policy_value!r}, "
                f"adapter[{depth}]={adapter_value!r}"
            )
            failed = True

sys.exit(1 if failed else 0)
PY
    if [ "$status" -ne 0 ]; then
        printf '%s\n' "$output"
        return 1
    fi
}

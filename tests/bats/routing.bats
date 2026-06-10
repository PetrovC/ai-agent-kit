#!/usr/bin/env bats
#
# Regression tests for the offline skill selector (scripts/select-skills.py).
# These tests run the selector against known tasks and file lists and assert
# that the output matches the expected fixture behavior.
# No LLM calls. No network access. Pure offline.

load 'bats_helper'

# KIT_ROOT is set by aak_setup(), which must run in setup() before each test.
# Do NOT set SELECTOR at the global level — KIT_ROOT is empty at load time.
SELECTOR=""

setup() {
    aak_setup
    SELECTOR="$KIT_ROOT/scripts/select-skills.py"
}

# Helper: run the selector and capture output
run_selector() {
    run python3 "$SELECTOR" "$@"
}

@test "selector: full-stack review selects code-review, dotnet, and angular" {
    run_selector \
        --task "Review and fix my Planora project" \
        --files "src/Api/Program.cs,src/Domain/Trip.cs,apps/web/src/app/app.component.ts"
    assert_success
    assert_output_contains "code-review"
    assert_output_contains "dotnet"
    assert_output_contains "angular"
}

@test "selector: full-stack review recommends delegation" {
    run_selector \
        --task "Review and fix my Planora project" \
        --files "src/Api/Program.cs,apps/web/src/app/app.component.ts"
    assert_success
    assert_output_contains "should_delegate: true"
}

@test "selector: dotnet DDD backend does not select angular" {
    run_selector \
        --task "Add the TripApproval aggregate to the Domain layer" \
        --files "src/Domain/Trip.cs,src/Application/Commands/ApproveTripCommand.cs"
    assert_success
    assert_output_contains "dotnet"
    refute_output_contains "angular"
}

@test "selector: dotnet DDD backend does not delegate" {
    run_selector \
        --task "Add aggregate to Domain layer" \
        --files "src/Domain/Trip.cs"
    assert_success
    assert_output_contains "no delegation"
}

@test "selector: typo fix selects no skills" {
    run_selector \
        --task "Fix typo in README" \
        --files "README.md"
    assert_success
    assert_output_contains "No skills selected"
}

@test "selector: typo fix does not delegate" {
    run_selector \
        --task "Fix typo in README" \
        --files "README.md"
    assert_success
    refute_output_contains "should_delegate: true"
}

@test "selector: CI workflow selects github-workflow" {
    run_selector \
        --task "Add GitHub Actions workflow for release pipeline" \
        --files ".github/workflows/release.yml"
    assert_success
    assert_output_contains "github-workflow"
}

@test "selector: security review of auth endpoints selects code-review" {
    run_selector \
        --task "Security review of the authentication endpoints" \
        --files "src/Api/Controllers/AuthController.cs"
    assert_success
    assert_output_contains "code-review"
}

@test "selector: angular-only task does not select dotnet" {
    run_selector \
        --task "Fix the broken Angular component for the trip list" \
        --files "apps/web/src/app/trips/trip-list.component.ts"
    assert_success
    assert_output_contains "angular"
    refute_output_contains "dotnet"
}

@test "selector: exits 0 even when no skills selected" {
    run_selector --task "update whitespace in config file" --files "config.json"
    assert_success
}

@test "selector: --json flag outputs valid JSON" {
    run_selector \
        --task "Review and fix my Planora project" \
        --files "src/Api/Program.cs,apps/web/src/app/app.component.ts" \
        --json
    assert_success
    # Output must be parseable as JSON
    run python3 -c "import json,sys; json.loads(sys.stdin.read())" <<< "$output"
    assert_success
}

@test "selector: --debug flag shows all skills with scores" {
    run_selector \
        --task "Review and fix my Planora project" \
        --files "src/Api/Program.cs" \
        --debug
    assert_success
    assert_output_contains "score="
}

@test "selector: SQL Server / T-SQL task selects database skill" {
    run_selector \
        --task "Tune SQL Server indexes and fix the deadlock in this T-SQL stored procedure" \
        --files "src/Infrastructure/Sql/Orders.sql,src/Infrastructure/OrdersDbContext.cs"
    assert_success
    assert_output_contains "database"
}

@test "selector: keyword-only SQL Server task selects database without a .sql file" {
    run_selector \
        --task "Optimize this T-SQL stored procedure and fix the SQL Server deadlock"
    assert_success
    assert_output_contains "database"
}

@test "selector: legacy modernization task selects architecture and testing" {
    run_selector --task "Modernize this legacy module with the strangler-fig pattern and characterization tests"
    assert_success
    assert_output_contains "architecture"
    assert_output_contains "testing"
}

@test "selector: deep greenfield architecture prompt selects architecture" {
    run_selector --task "Design clean architecture boundaries, ensure aggregate consistency and define the bounded context for our new domain"
    assert_success
    assert_output_contains "architecture"
}

@test "selector: skills root exists" {
    [[ -d "$KIT_ROOT/skills" ]]
}

@test "selector: can find at least 5 skill SKILL.md files" {
    count=$(find "$KIT_ROOT/skills" -name "SKILL.md" | wc -l | tr -d ' ')
    [[ "$count" -ge 5 ]]
}

@test "selector: godot gdscript files route to godot, not dotnet" {
    run_selector \
        --task "Implement player movement and jump physics in Godot GDScript" \
        --files "scenes/player/player.gd,scenes/player/player.tscn"
    assert_success
    assert_output_contains "godot"
    refute_output_contains "dotnet"
}

@test "selector: keyword-only godot task selects godot without files" {
    run_selector --task "Refactor the Godot scene tree and autoload singletons for the inventory UI"
    assert_success
    assert_output_contains "godot"
}

@test "selector: keyword-only rust task selects rust (#484)" {
    run_selector --task "Fix lifetime error in async tokio handler"
    assert_success
    assert_output_contains "rust"
    refute_output_contains "dotnet"
}

@test "selector: angular signals migration does not pull dotnet (#484)" {
    run_selector \
        --task "Migrate Angular component to signals and standalone" \
        --files "src/app/user.component.ts"
    assert_success
    assert_output_contains "angular"
    refute_output_contains "dotnet"
}

@test "selector: ef schema migration still routes data-migration to dotnet (#484)" {
    run_selector \
        --task "Add an EF Core migration for the orders schema" \
        --files "src/Orders/Data/AppDbContext.cs"
    assert_success
    assert_output_contains "dotnet"
}

@test "selector: rust gdext task selects godot and rust" {
    run_selector \
        --task "Expose a Rust gdext pathfinding node to GDScript via GDExtension" \
        --files "rust/src/pathfinding.rs,godot/native.gdextension"
    assert_success
    assert_output_contains "godot"
    assert_output_contains "rust"
}

@test "selector: plain .ts backend file routes to node (#498)" {
    run_selector \
        --task "add express middleware for request logging" \
        --files "src/server/app.ts"
    assert_success
    assert_output_contains "node"
    refute_output_contains "dotnet"
}

@test "selector: .tsx component stays with react, not node (#498)" {
    run_selector \
        --task "tighten prop types on the profile card" \
        --files "src/components/ProfileCard.tsx"
    assert_success
    assert_output_contains "react"
    refute_output_contains "node ("
}

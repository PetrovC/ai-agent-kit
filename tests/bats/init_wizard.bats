#!/usr/bin/env bats
# tests/bats/init_wizard.bats - tests for scripts/init.sh

setup() {
  TMPDIR="$(mktemp -d)"
  mkdir -p "$TMPDIR/docs/ai"
  # Create a stub COMMANDS.md with STOP notice
  echo "> ⚠️ STOP — Fill this file" > "$TMPDIR/docs/ai/COMMANDS.md"
  SCRIPT="$BATS_TEST_DIRNAME/../../scripts/init.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "init --preset dotnet seeds COMMANDS.md" {
  run bash "$SCRIPT" --target "$TMPDIR" --preset dotnet
  [ "$status" -eq 0 ]
  grep -q "dotnet build" "$TMPDIR/docs/ai/COMMANDS.md"
  # STOP notice should be gone
  ! grep -q "STOP" "$TMPDIR/docs/ai/COMMANDS.md"
}

@test "init --preset node seeds COMMANDS.md" {
  run bash "$SCRIPT" --target "$TMPDIR" --preset node
  [ "$status" -eq 0 ]
  grep -q "npm install" "$TMPDIR/docs/ai/COMMANDS.md"
}

@test "init --preset python seeds COMMANDS.md" {
  run bash "$SCRIPT" --target "$TMPDIR" --preset python
  [ "$status" -eq 0 ]
  grep -q "pytest" "$TMPDIR/docs/ai/COMMANDS.md"
}

@test "init --preset go seeds COMMANDS.md" {
  run bash "$SCRIPT" --target "$TMPDIR" --preset go
  [ "$status" -eq 0 ]
  grep -q "go test" "$TMPDIR/docs/ai/COMMANDS.md"
}

@test "init --preset rust seeds COMMANDS.md" {
  run bash "$SCRIPT" --target "$TMPDIR" --preset rust
  [ "$status" -eq 0 ]
  grep -q "cargo build" "$TMPDIR/docs/ai/COMMANDS.md"
}

@test "init skips if COMMANDS.md already filled" {
  # Write a filled COMMANDS.md (no STOP notice)
  echo -e "# Commands\n\nAlready filled." > "$TMPDIR/docs/ai/COMMANDS.md"
  run bash "$SCRIPT" --target "$TMPDIR" --preset dotnet
  [ "$status" -eq 0 ]
  # Should NOT overwrite
  ! grep -q "dotnet" "$TMPDIR/docs/ai/COMMANDS.md"
}

@test "init fails if docs/ai does not exist" {
  run bash "$SCRIPT" --target "/tmp/nonexistent-$$" --preset dotnet
  [ "$status" -ne 0 ]
}

@test "init --preset invalid-preset fails" {
  run bash "$SCRIPT" --target "$TMPDIR" --preset invalid
  [ "$status" -ne 0 ]
}

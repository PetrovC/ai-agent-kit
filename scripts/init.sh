#!/usr/bin/env bash
if [[ -n "${AAK_DEBUG:-}" && "${AAK_DEBUG}" != "0" && "${AAK_DEBUG}" != "false" ]]; then set -x; fi
# init.sh — Seed stack-specific docs/ai/COMMANDS.md for the target project.
#
# Usage:
#   ./init.sh [--target /path/to/project] [--preset <name>]
#
# Presets: dotnet | node | python | go | rust | generic
# Default target is the current directory.
#
# If --preset is omitted, an interactive numbered menu is shown.
#
set -euo pipefail

TARGET=""
PRESET=""

# --- arg parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --preset) PRESET="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

TARGET="${TARGET:-.}"

DOCS_AI="$TARGET/docs/ai"
COMMANDS_MD="$DOCS_AI/COMMANDS.md"

if [[ ! -d "$DOCS_AI" ]]; then
  echo "Error: $DOCS_AI does not exist. Run install.sh first." >&2
  exit 1
fi

if [[ -f "$COMMANDS_MD" ]] && ! grep -qE 'STOP' "$COMMANDS_MD"; then
  echo "  [ok] $COMMANDS_MD already filled — skipping (no STOP notice found)."
  exit 0
fi

PRESETS=(dotnet node python go rust generic)

if [[ -z "$PRESET" ]]; then
  echo "Choose a stack preset for docs/ai/COMMANDS.md:"
  for i in "${!PRESETS[@]}"; do
    echo "  $((i+1))) ${PRESETS[$i]}"
  done
  read -rp "Enter number [1-6]: " choice
  idx=$((choice - 1))
  if [[ $idx -lt 0 || $idx -ge ${#PRESETS[@]} ]]; then
    echo "Invalid choice." >&2; exit 1
  fi
  PRESET="${PRESETS[$idx]}"
fi

# Validate preset
is_valid_preset() {
  local p
  for p in "${PRESETS[@]}"; do [[ "$PRESET" == "$p" ]] && return 0; done
  return 1
}
if ! is_valid_preset; then
  echo "Error: Unknown preset '$PRESET'. Valid: ${PRESETS[*]}" >&2; exit 1
fi

# Write COMMANDS.md based on preset
write_commands() {
  local preset="$1"
  local out="$2"
  cat > "$out" << 'HEREDOC'
# Commands

> The single source of truth for all build, test, lint, and run commands.
> AI agents read this file to know which commands to use for verification.
HEREDOC

  case "$preset" in
    dotnet)
      cat >> "$out" << 'HEREDOC'

## Setup
```bash
dotnet restore
```

## Build
```bash
dotnet build
```

## Run
```bash
dotnet run --project src/<Project>
```

## Tests
```bash
dotnet test
dotnet test --filter "FullyQualifiedName~<TestName>"
```

## Lint / format
```bash
dotnet format --verify-no-changes
```

## CI equivalent
```bash
dotnet restore
dotnet build --no-restore
dotnet test --no-build
dotnet format --verify-no-changes
```
HEREDOC
      ;;
    node)
      cat >> "$out" << 'HEREDOC'

## Setup
```bash
npm install
```

## Build
```bash
npm run build
```

## Run
```bash
npm run dev
```

## Tests
```bash
npm test
npm run test:watch
```

## Lint / format
```bash
npm run lint
npm run type-check
```

## CI equivalent
```bash
npm ci
npm run build
npm test
npm run lint
```
HEREDOC
      ;;
    python)
      cat >> "$out" << 'HEREDOC'

## Setup
```bash
pip install -r requirements.txt
# or
pip install -e ".[dev]"
```

## Run
```bash
python -m <module>
```

## Tests
```bash
pytest
pytest -k <test_name>
pytest --tb=short
```

## Lint / format
```bash
ruff check .
ruff format --check .
mypy .
```

## CI equivalent
```bash
pip install -e ".[dev]"
ruff check .
ruff format --check .
pytest
```
HEREDOC
      ;;
    go)
      cat >> "$out" << 'HEREDOC'

## Setup
```bash
go mod download
```

## Build
```bash
go build ./...
```

## Run
```bash
go run ./cmd/<main>
```

## Tests
```bash
go test ./...
go test -run <TestName> ./...
go test -v ./...
```

## Lint / format
```bash
gofmt -l .
go vet ./...
golangci-lint run
```

## CI equivalent
```bash
go mod download
go build ./...
go test ./...
go vet ./...
```
HEREDOC
      ;;
    rust)
      cat >> "$out" << 'HEREDOC'

## Setup
```bash
cargo fetch
```

## Build
```bash
cargo build
cargo build --release
```

## Run
```bash
cargo run
```

## Tests
```bash
cargo test
cargo test <test_name>
cargo test -- --nocapture
```

## Lint / format
```bash
cargo fmt --check
cargo clippy -- -D warnings
```

## CI equivalent
```bash
cargo fetch
cargo build
cargo test
cargo fmt --check
cargo clippy -- -D warnings
```
HEREDOC
      ;;
    generic)
      cat >> "$out" << 'HEREDOC'

## Setup
```bash
# TODO: add dependency install command
```

## Build
```bash
# TODO: add build command
```

## Run
```bash
# TODO: add run command
```

## Tests
```bash
# TODO: add test command
```

## Lint / format
```bash
# TODO: add lint command
```

## CI equivalent
```bash
# TODO: list commands that must pass before merge
```
HEREDOC
      ;;
  esac
}

write_commands "$PRESET" "$COMMANDS_MD"
echo "  [ok] $COMMANDS_MD seeded with '$PRESET' preset."
echo "  Review and customize before committing."

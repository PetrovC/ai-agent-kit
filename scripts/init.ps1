<#
.SYNOPSIS
    Seed stack-specific docs/ai/COMMANDS.md for the target project.

.DESCRIPTION
    Creates the COMMANDS.md file with the standard structure based on a preset.

.PARAMETER Target
    Default target is the current directory.

.PARAMETER Preset
    Presets: dotnet | node | python | go | rust | generic
    If omitted, an interactive numbered menu is shown.
#>

param(
    [string]$Target = ".",
    [string]$Preset = ""
)

if ($env:AAK_DEBUG -and $env:AAK_DEBUG -ne "0" -and $env:AAK_DEBUG -ne "false") { Set-PSDebug -Trace 1 }

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$docsAi = Join-Path $Target "docs/ai"
$commandsMd = Join-Path $docsAi "COMMANDS.md"

if (-not (Test-Path $docsAi -PathType Container)) {
    Write-Error "Error: $docsAi does not exist. Run install.sh first."
    exit 1
}

if (Test-Path $commandsMd -PathType Leaf) {
    $content = Get-Content $commandsMd -Raw
    if ($content -and $content -notmatch "STOP") {
        Write-Host "  [ok] $commandsMd already filled - skipping (no STOP notice found)."
        exit 0
    }
}

$Presets = @("dotnet", "node", "python", "go", "rust", "generic")

if ([string]::IsNullOrEmpty($Preset)) {
    Write-Host "Choose a stack preset for docs/ai/COMMANDS.md:"
    for ($i = 0; $i -lt $Presets.Count; $i++) {
        $num = $i + 1
        Write-Host "  $num) $($Presets[$i])"
    }
    $choice = Read-Host "Enter number [1-6]"
    if ($choice -match '^[1-6]$') {
        $Preset = $Presets[[int]$choice - 1]
    } else {
        Write-Error "Invalid choice."
        exit 1
    }
}

if ($Presets -notcontains $Preset) {
    Write-Error "Error: Unknown preset '$Preset'. Valid: $($Presets -join ' ')"
    exit 1
}

# Generate contents
$content = @'
# Commands

> The single source of truth for all build, test, lint, and run commands.
> AI agents read this file to know which commands to use for verification.
'@

switch ($Preset) {
    "dotnet" {
        $content += "`n" + @'

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
'@
    }
    "node" {
        $content += "`n" + @'

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
'@
    }
    "python" {
        $content += "`n" + @'

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
'@
    }
    "go" {
        $content += "`n" + @'

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
'@
    }
    "rust" {
        $content += "`n" + @'

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
'@
    }
    "generic" {
        $content += "`n" + @'

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
'@
    }
}

# Ensure LF line endings and write without BOM
$content = $content -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($commandsMd, $content, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "  [ok] $commandsMd seeded with '$Preset' preset."
Write-Host "  Review and customize before committing."

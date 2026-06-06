<#
.SYNOPSIS
    Diagnose a target project's installation of ai-agent-kit.

.DESCRIPTION
    Inspects target project files and environment to verify:
      - Kit version (via .kit-version or VERSION compared with latest git tag)
      - Manifest integrity (each file in .kit-manifest exists)
      - Hook executability (.sh hooks must be executable on Unix)
      - Presence of .mcp.example.jsonc
      - Presence of docs/ai/PROJECT.md and docs/ai/ARCHITECTURE.md

    Exit codes:
      0 - healthy
      1 - warnings
      2 - errors

.PARAMETER Target
    Path to the target project.

.EXAMPLE
    pwsh scripts/doctor.ps1 -Target C:\path\to\project
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Target
)

if ($env:AAK_DEBUG -and $env:AAK_DEBUG -ne "0" -and $env:AAK_DEBUG -ne "false") { Set-PSDebug -Trace 1 }  # AAK_DEBUG: opt-in trace (#305)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Write-Error "Target directory '$Target' does not exist."
    exit 2
}

# Resolve target to full path
$resolvedTarget = (Resolve-Path -LiteralPath $Target).Path

$script:hasError = $false
$script:hasWarning = $false

function Write-Ok([string]$msg) {
    Write-Host "[OK] $msg" -ForegroundColor Green
}

function Write-Warn([string]$msg) {
    Write-Host "[WARN] $msg" -ForegroundColor Yellow
    $script:hasWarning = $true
}

function Write-Err([string]$msg) {
    Write-Host "[ERROR] $msg" -ForegroundColor Red
    $script:hasError = $true
}

Write-Host ""
Write-Host "+--------------------------------------+"
Write-Host "|          ai-agent-kit doctor         |"
Write-Host "+--------------------------------------+"
Write-Host "  Target: $resolvedTarget"
Write-Host ""

# a. Version check: read VERSION file from the kit root (one directory up from scripts/); report if target has no .kit-manifest
$kitVersion = ""
# In the repo the kit root is one level up from scripts/; in a release archive
# VERSION sits beside this script. Detect via the VERSION sentinel.
$kitRootVersionPath = if (Test-Path -LiteralPath (Join-Path $PSScriptRoot "VERSION") -PathType Leaf) { Join-Path $PSScriptRoot "VERSION" } else { Join-Path (Split-Path -Parent $PSScriptRoot) "VERSION" }
if (Test-Path -LiteralPath $kitRootVersionPath -PathType Leaf) {
    $kitVersion = (Get-Content -LiteralPath $kitRootVersionPath -Raw).Trim()
}

if (-not $kitVersion) {
    Write-Err "Version check: Could not read VERSION file from kit root ($kitRootVersionPath)"
} else {
    # Read target version from .kit-version or VERSION
    $targetVersion = ""
    $kitVersionPath = Join-Path $resolvedTarget ".kit-version"
    $versionFilePath = Join-Path $resolvedTarget "VERSION"

    if (Test-Path -LiteralPath $kitVersionPath -PathType Leaf) {
        $versionLine = Get-Content -LiteralPath $kitVersionPath -Raw
        if ($versionLine -match "ai-agent-kit@([0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)*)") {
            $targetVersion = $Matches[1]
        } else {
            $targetVersion = $versionLine.Trim()
        }
    } elseif (Test-Path -LiteralPath $versionFilePath -PathType Leaf) {
        $targetVersion = (Get-Content -LiteralPath $versionFilePath -Raw).Trim()
    }

    if (-not $targetVersion) {
        Write-Warn "Version check: Could not determine target kit version (no .kit-version or VERSION file)"
    } else {
        $targetVersionClean = $targetVersion.TrimStart('v')
        $kitVersionClean = $kitVersion.TrimStart('v')
        if ($targetVersionClean -ne $kitVersionClean) {
            Write-Warn "Version check: Target version ($targetVersion) does not match kit version ($kitVersion)"
        } else {
            Write-Ok "Version check: Target version matches kit version ($targetVersion)"
        }
    }
}

$manifestPath = Join-Path $resolvedTarget ".kit-manifest"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Write-Warn "Version check: Target has no .kit-manifest file"
}

# b. Manifest integrity: verify every file in .kit-manifest exists at target
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Write-Err "Manifest integrity: .kit-manifest is missing at target"
} else {
    $manifestDrift = $false
    $lines = Get-Content -LiteralPath $manifestPath
    foreach ($line in $lines) {
        $rel = $line.Trim()
        if (-not $rel) { continue }
        $fullPath = Join-Path $resolvedTarget $rel
        if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
            Write-Err "Manifest integrity: Missing file -> $rel"
            $manifestDrift = $true
        }
    }
    if (-not $manifestDrift) {
        Write-Ok "Manifest integrity: All files in .kit-manifest exist at target"
    }
}

# c. Hook executability: .claude/hooks/*.sh and .codex/hooks/*.sh must be executable
$isWindows = $true
if ($null -ne $IsWindows) {
    $isWindows = $IsWindows
} else {
    $isWindows = [System.Environment]::OSVersion.Platform -notIn @("Unix", "MacOSX")
}

$hooksChecked = 0
$hooksFailed = 0
$hookDirs = @(".claude\hooks", ".codex\hooks")

foreach ($hdir in $hookDirs) {
    $fullHDir = Join-Path $resolvedTarget $hdir
    if (Test-Path -LiteralPath $fullHDir -PathType Container) {
        $files = Get-ChildItem -LiteralPath $fullHDir -Filter "*.sh" -File
        foreach ($file in $files) {
            $hooksChecked++
            $isExecutable = $true
            if ($env:AAK_TEST_FORCE_NON_EXECUTABLE) {
                $isExecutable = $false
            } elseif (-not $isWindows) {
                try {
                    $escapedPath = $file.FullName -replace "'", "'\''"
                    & sh -c "test -x '$escapedPath'"
                    $isExecutable = ($LASTEXITCODE -eq 0)
                } catch {
                    $isExecutable = $true
                }
            }
            if (-not $isExecutable) {
                $relPath = $file.FullName.Substring($resolvedTarget.Length).TrimStart('\').TrimStart('/') -replace '\\', '/'
                Write-Warn "Hook executability: Hook is not executable -> $relPath"
                $hooksFailed++
            }
        }
    }
}

if ($hooksChecked -eq 0) {
    Write-Ok "Hook executability: No hooks found to verify"
} elseif ($hooksFailed -eq 0) {
    Write-Ok "Hook executability: All $hooksChecked hooks are executable"
}

# d. MCP file: .mcp.example.jsonc must exist
$mcpPath = Join-Path $resolvedTarget ".mcp.example.jsonc"
if (Test-Path -LiteralPath $mcpPath -PathType Leaf) {
    Write-Ok "MCP file: .mcp.example.jsonc is present"
} else {
    Write-Err "MCP file: .mcp.example.jsonc is missing"
}

# e. docs/ai presence: docs/ai/PROJECT.md, docs/ai/ARCHITECTURE.md must exist
$docsMissing = $false
foreach ($docName in @("docs\ai\PROJECT.md", "docs\ai\ARCHITECTURE.md")) {
    $docPath = Join-Path $resolvedTarget $docName
    if (Test-Path -LiteralPath $docPath -PathType Leaf) {
        # OK
    } else {
        Write-Err "docs/ai presence: $docName is missing"
        $docsMissing = $true
    }
}
if (-not $docsMissing) {
    Write-Ok "docs/ai presence: docs/ai/PROJECT.md and docs/ai/ARCHITECTURE.md are present"
}

Write-Host ""
if ($script:hasError) {
    Write-Host "Diagnostics failed with errors." -ForegroundColor Red
    exit 2
} elseif ($script:hasWarning) {
    Write-Host "Diagnostics passed with warnings." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "Diagnostics passed successfully. Target install is healthy." -ForegroundColor Green
    exit 0
}

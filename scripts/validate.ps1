<#
.SYNOPSIS
    Check that docs/ai/* templates have been filled in a target project.

.DESCRIPTION
    Detects:
      - "STOP" notices still present in templates.
      - HTML-comment placeholders still present (<!-- ... -->).
      - Required files missing.

    Exit codes:
      0 - everything OK
      1 - issues found (or usage error)

.PARAMETER Target
    Path to the project root to validate.

.EXAMPLE
    .\validate.ps1 -Target "C:\Projects\my-project"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Target
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$DocsAi = Join-Path $Target "docs\ai"
if (-not (Test-Path $DocsAi)) {
    Write-Error "$DocsAi does not exist. Run install.ps1 first."
    exit 1
}

$Required = @("PROJECT.md", "ARCHITECTURE.md", "COMMANDS.md", "TESTING.md")
$Issues = 0

function Warn([string]$msg) {
    Write-Host "  ! $msg" -ForegroundColor Yellow
    $script:Issues++
}

function Ok([string]$msg) {
    Write-Host "  [ok] $msg" -ForegroundColor Green
}

Write-Host ""
Write-Host "+--------------------------------------+"
Write-Host "|        ai-agent-kit validator        |"
Write-Host "+--------------------------------------+"
Write-Host "  Target: $Target"
Write-Host ""

# Required files
Write-Host "> Required files in docs/ai/"
foreach ($f in $Required) {
    if (Test-Path (Join-Path $DocsAi $f)) {
        Ok "$f present"
    } else {
        Warn "$f MISSING"
    }
}

# STOP notices
Write-Host ""
Write-Host "> Templates still showing STOP notice (must be filled)"
$stopFound = $false
Get-ChildItem -Path $DocsAi -Filter "*.md" -File | ForEach-Object {
    if (Select-String -Path $_.FullName -Pattern "STOP" -Quiet) {
        Warn "$($_.Name) still contains a STOP notice"
        $stopFound = $true
    }
}
if (-not $stopFound) { Ok "no STOP notices remaining" }

# HTML comment placeholders
Write-Host ""
Write-Host "> Templates still containing HTML-comment placeholders"
$placeholdersFound = $false
Get-ChildItem -Path $DocsAi -Filter "*.md" -File | ForEach-Object {
    $hits = @(Select-String -Path $_.FullName -Pattern "<!--\s*[A-Za-z]")
    if ($hits.Count -gt 0) {
        Warn "$($_.Name): $($hits.Count) placeholder comment(s) remaining"
        $placeholdersFound = $true
    }
}
if (-not $placeholdersFound) { Ok "no placeholder comments remaining" }

Write-Host ""
if ($Issues -eq 0) {
    Write-Host "All checks passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$Issues issue(s) found. Fill the templates before letting agents read docs/ai/." -ForegroundColor Yellow
    exit 1
}

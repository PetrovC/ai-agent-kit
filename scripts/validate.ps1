<#
.SYNOPSIS
    Check that docs/ai/* templates have been filled in a target project.

.DESCRIPTION
    Detects:
      - Required files missing (every project-template/*.md must ship to docs/ai/).
      - "STOP" notices still present in templates.
      - HTML-comment placeholders still present (<!-- ... -->).
      - Non-comment placeholders still present (empty table rows, "TBD" cells,
        pure-dots list items, "<key>: ..." placeholder values).

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

$Required = @("PROJECT.md", "ARCHITECTURE.md", "COMMANDS.md", "DECISIONS.md", "GLOSSARY.md", "ROADMAP.md", "TESTING.md")
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
    if (Select-String -Path $_.FullName -Pattern "^> .*STOP|⚠️.*STOP" -Quiet) {
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

# Non-comment placeholders (template patterns the previous checks miss).
# Skips fenced code blocks and HTML comments so legitimate prose / examples
# don't trip the detector. Patterns flagged:
#   - empty table rows:        | | |
#   - "TBD" cells:             | TBD |
#   - pure-dots list items:    - ...   * ...   1. ...   - [ ] ...   - [x] ...
#   - placeholder key/values:  ### Flow 1: ...   **Name**: ...   Goal: ...
Write-Host ""
Write-Host "> Templates still containing non-comment placeholders"
$nonCommentFound = $false
Get-ChildItem -Path $DocsAi -Filter "*.md" -File | ForEach-Object {
    $file = $_
    $inCode = $false
    $inComment = $false
    $hits = 0
    foreach ($line in (Get-Content -LiteralPath $file.FullName)) {
        if ($line -match '^\s*```') { $inCode = -not $inCode; continue }
        if ($inCode) { continue }
        if (-not $inComment -and $line -match '<!--' -and $line -notmatch '-->') {
            $inComment = $true; continue
        }
        if ($inComment) {
            if ($line -match '-->') { $inComment = $false }
            continue
        }
        if ($line -match '<!--.*-->') { continue }

        if ($line -match '^\s*\|(\s*\|)+\s*$' `
            -or $line -match '\|\s*TBD\s*\|' `
            -or $line -match '^\s*(-|\*|\d+\.)\s+(\[[\sxX]\]\s+)?\.\.\.\s*$' `
            -or $line -match ':\s+\.\.\.\s*$') {
            $hits++
        }
    }
    if ($hits -gt 0) {
        Warn "$($file.Name): $hits non-comment placeholder(s) remaining"
        $nonCommentFound = $true
    }
}
if (-not $nonCommentFound) { Ok "no non-comment placeholders remaining" }

Write-Host ""
if ($Issues -eq 0) {
    Write-Host "All checks passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$Issues issue(s) found. Fill the templates before letting agents read docs/ai/." -ForegroundColor Yellow
    exit 1
}

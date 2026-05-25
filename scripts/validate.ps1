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
      - In this source repository only, tracked Claude/Codex dogfood files
        drifted from their canonical sources under tooling/ or skills/.

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
# Closes #89: every Test-Path / Get-ChildItem / Select-String on a path
# derived from $Target uses -LiteralPath so a project at e.g.
# `C:\work\[acme]\app` is treated as a literal filesystem path, not a
# wildcard pattern that would silently miss the docs directory.
if (-not (Test-Path -LiteralPath $DocsAi)) {
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
    if (Test-Path -LiteralPath (Join-Path $DocsAi $f)) {
        Ok "$f present"
    } else {
        Warn "$f MISSING"
    }
}

# STOP notices
Write-Host ""
Write-Host "> Templates still showing STOP notice (must be filled)"
$stopFound = $false
Get-ChildItem -LiteralPath $DocsAi -Filter "*.md" -File | ForEach-Object {
    if (Select-String -LiteralPath $_.FullName -Pattern "^> .*STOP|⚠️.*STOP" -Quiet) {
        Warn "$($_.Name) still contains a STOP notice"
        $stopFound = $true
    }
}
if (-not $stopFound) { Ok "no STOP notices remaining" }

# HTML comment placeholders
Write-Host ""
Write-Host "> Templates still containing HTML-comment placeholders"
$placeholdersFound = $false
Get-ChildItem -LiteralPath $DocsAi -Filter "*.md" -File | ForEach-Object {
    $hits = @(Select-String -LiteralPath $_.FullName -Pattern "<!--\s*[A-Za-z]")
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
Get-ChildItem -LiteralPath $DocsAi -Filter "*.md" -File | ForEach-Object {
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

function Join-TargetRelative([string]$rel) {
    $path = $Target
    foreach ($part in ($rel -split "/")) {
        if ($part) {
            $path = Join-Path $path $part
        }
    }
    return $path
}

function Get-DogfoodSourceCandidates([string]$rel) {
    switch -Regex ($rel) {
        "^AGENTS\.md$" { return @("tooling/codex/AGENTS.md") }
        "^CLAUDE\.md$" { return @("tooling/claude/CLAUDE.md") }
        "^\.mcp\.example\.jsonc$" { return @("tooling/claude/.mcp.example.jsonc") }

        "^\.codex/config\.toml$" { return @("tooling/codex/config.toml") }
        "^\.codex/hooks\.json$" { return @("tooling/codex/hooks.json", "tooling/codex/hooks.windows.json") }
        "^\.codex/hooks/(.+)$" { return @("tooling/codex/hooks/$($Matches[1])") }
        "^\.agents/skills/(.+)$" {
            $tail = $Matches[1]
            $candidates = @()
            $codexSkill = "tooling/codex/skills/$tail"
            if (Test-Path -LiteralPath (Join-TargetRelative $codexSkill) -PathType Leaf) {
                $candidates += $codexSkill
            }
            $candidates += "skills/$tail"
            return $candidates
        }

        "^\.claude/settings\.json$" { return @("tooling/claude/settings.json", "tooling/claude/settings.windows.json") }
        "^\.claude/agents/(.+)$" { return @("tooling/claude/agents/$($Matches[1])") }
        "^\.claude/commands/(.+)$" { return @("tooling/claude/commands/$($Matches[1])") }
        "^\.claude/hooks/(.+)$" { return @("tooling/claude/hooks/$($Matches[1])") }
        "^\.claude/rules/(.+)$" { return @("tooling/claude/rules/$($Matches[1])") }
        "^\.claude/skills/(.+)$" { return @("skills/$($Matches[1])") }
    }
    return @()
}

function Test-SameFile([string]$left, [string]$right) {
    if (-not (Test-Path -LiteralPath $left -PathType Leaf)) { return $false }
    if (-not (Test-Path -LiteralPath $right -PathType Leaf)) { return $false }
    $leftHash = (Get-FileHash -LiteralPath $left -Algorithm SHA256).Hash
    $rightHash = (Get-FileHash -LiteralPath $right -Algorithm SHA256).Hash
    return $leftHash -eq $rightHash
}

$manifestPath = Join-Path $Target ".kit-manifest"
$codexSource = Join-Path $Target "tooling\codex"
$claudeSource = Join-Path $Target "tooling\claude"
if ((Test-Path -LiteralPath $manifestPath -PathType Leaf) `
    -and (Test-Path -LiteralPath $codexSource -PathType Container) `
    -and (Test-Path -LiteralPath $claudeSource -PathType Container)) {
    Write-Host ""
    Write-Host "> Dogfood install drift (repo only)"
    $dogfoodChecked = 0
    $dogfoodFound = $false

    foreach ($relRaw in (Get-Content -LiteralPath $manifestPath)) {
        $rel = $relRaw.Trim().TrimStart([char]0xFEFF)
        if (-not $rel) { continue }
        if ($rel -in @(".kit-version", ".kit-manifest", ".mcp.json")) { continue }

        $dst = Join-TargetRelative $rel
        if (-not (Test-Path -LiteralPath $dst -PathType Leaf)) {
            Warn "$rel missing from dogfood install"
            $dogfoodFound = $true
            continue
        }

        $candidates = @(Get-DogfoodSourceCandidates $rel)
        if ($candidates.Count -eq 0) { continue }

        $sourceFound = $false
        $sourceMatch = $false
        $matchedSrcRel = $null
        foreach ($candidate in $candidates) {
            $src = Join-TargetRelative $candidate
            if (Test-Path -LiteralPath $src -PathType Leaf) {
                $sourceFound = $true
                if (Test-SameFile $src $dst) {
                    $sourceMatch = $true
                    $matchedSrcRel = $candidate
                    break
                }
            }
        }

        if (-not $sourceFound) {
            Warn "$rel has no source candidate under tooling/ or skills/"
            $dogfoodFound = $true
        } elseif (-not $sourceMatch) {
            Warn "$rel differs from its source under tooling/ or skills/"
            $dogfoodFound = $true
        } else {
            # Content matches; also enforce git-tracked mode parity.
            # A .sh source at 100755 must not become 100644 in dogfood —
            # that breaks hook execution on POSIX.
            $srcMode = $null
            $dstMode = $null
            try {
                $srcLine = & git -C $Target ls-files -s -- $matchedSrcRel 2>$null | Select-Object -First 1
                $dstLine = & git -C $Target ls-files -s -- $rel 2>$null | Select-Object -First 1
                if ($srcLine) { $srcMode = ($srcLine -split '\s+')[0] }
                if ($dstLine) { $dstMode = ($dstLine -split '\s+')[0] }
            } catch {
                $srcMode = $null; $dstMode = $null
            }
            if ($srcMode -and $dstMode -and ($srcMode -ne $dstMode)) {
                Warn "$rel git mode $dstMode differs from source $matchedSrcRel mode $srcMode"
                $dogfoodFound = $true
            } else {
                $dogfoodChecked++
            }
        }
    }

    if (-not $dogfoodFound) {
        Ok "$dogfoodChecked dogfood file(s) match source"
    }
}

Write-Host ""
if ($Issues -eq 0) {
    Write-Host "All checks passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$Issues issue(s) found. Fill the templates before letting agents read docs/ai/." -ForegroundColor Yellow
    exit 1
}

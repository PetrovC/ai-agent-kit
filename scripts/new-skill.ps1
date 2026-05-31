<#
.SYNOPSIS
    Scaffold a new skill under skills/<name>/SKILL.md.

.DESCRIPTION
    Creates the skill file with the standard structure all existing skills follow,
    and inserts a TODO placeholder row into all three routing tables.

.PARAMETER Name
    Skill name in kebab-case (lowercase letters, digits, hyphens).

.PARAMETER Description
    One-sentence description of when to use this skill.

.EXAMPLE
    .\new-skill.ps1 -Name "graphql-server"
    .\new-skill.ps1 -Name "graphql-server" -Description "Use when building GraphQL servers with Apollo or Yoga."
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$Description = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$KitRoot = Split-Path -Parent $PSScriptRoot

function Write-Utf8NoBom([string]$path, [string]$text) {
    # PowerShell 5.1 `Set-Content -Encoding utf8` writes a UTF-8 BOM, which
    # corrupts the first routing-table row / YAML frontmatter for downstream
    # parsers and the CI grep checks. Write UTF-8 *without* BOM and normalise
    # to LF so the result matches the bash new-skill.sh output exactly.
    $text = $text -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

# Validate name as a cross-tool identifier. The slug becomes a directory, a
# Codex activation token, a Antigravity path, and a row in three routing tables —
# the previous "[a-z][a-z0-9-]*" regex also accepted "foo-" and "foo--bar".
if ($Name -notmatch '^[a-z][a-z0-9]*(-[a-z0-9]+)*$') {
    Write-Error "Skill name must be lowercase alphanumeric segments joined by single hyphens (e.g. graphql-server). Got: $Name"
    exit 1
}

# Reject Windows reserved device names so the same slug works on every target
# filesystem (new-skill.sh has the same guard).
$reserved = @('con','prn','aux','nul',
              'com1','com2','com3','com4','com5','com6','com7','com8','com9',
              'lpt1','lpt2','lpt3','lpt4','lpt5','lpt6','lpt7','lpt8','lpt9')
if ($reserved -contains $Name.ToLower()) {
    Write-Error "'$Name' is a Windows reserved device name and cannot be used as a skill slug."
    exit 1
}

$skillDir  = Join-Path $KitRoot "skills\$Name"
$skillFile = Join-Path $skillDir "SKILL.md"

if (Test-Path -LiteralPath $skillDir) {
    Write-Error "skills/$Name already exists."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = "Use when ... (describe the trigger condition for this skill in one sentence)."
}

[System.IO.Directory]::CreateDirectory($skillDir) | Out-Null

$title = ($Name -split '-' | ForEach-Object {
    $_.Substring(0,1).ToUpper() + $_.Substring(1)
}) -join ' '

$body = @"
---
name: $Name
description: >
  $Description
---

# $title Skill

## Goal

<!-- One paragraph: what does this skill ensure? What is the "definition of good"? -->

---

## Universal rules

- <!-- the 3-7 rules that apply regardless of stack / framework -->

---

## <Topic 1>

- <!-- detailed guidance for the first topic -->

---

## <Topic 2>

- <!-- detailed guidance for the second topic -->

---

## What NOT to do

- <!-- common anti-patterns to refuse, with reasons if non-obvious -->

---

## Verification commands

``````bash
# Commands to run to verify the work locally
``````

---

## Final response requirements

Always report:
- <!-- what the agent must include in its final response -->
- Any new dependency: name, version, **license (MIT only - see ``dependencies`` skill)**.
"@

Write-Utf8NoBom $skillFile $body

# -- Insert placeholder routing rows ---------------------------------------
# Tracks per-file success so partial routing failures cannot masquerade as a
# full scaffold. Exits non-zero at the end if any anchor was missing.
$script:routingResults = @()
$script:routingOk = $true

function Insert-RoutingRow([string]$file, [string]$row, [string]$anchor) {
    $base = Split-Path -Leaf $file
    # Normalise CRLF -> LF first: on a Windows checkout (autocrlf) the file is
    # CRLF on disk but the anchors are written with bare LF - without this the
    # IndexOf never matches and every routing row is silently skipped.
    $content = (Get-Content -LiteralPath $file -Raw) -replace "`r`n", "`n"
    $idx = $content.IndexOf($anchor)
    if ($idx -lt 0) {
        $script:routingResults += "$base : ANCHOR NOT FOUND -- add the row manually"
        $script:routingOk = $false
        return
    }
    $newContent = $content.Substring(0, $idx) + "`n" + $row + $content.Substring($idx)
    Write-Utf8NoBom $file $newContent
    $script:routingResults += "$base : row added"
}

# Anchor on the blank line before the "## Subagent routing" heading that ends
# the skill routing section (stable across all three routers; no dependency on a
# `---` separator or specific trailing prose).
$anchorSubagent = "`n`n## Subagent routing"

# The AGENTS.md row contains a literal `$<Name>` Codex activation token. The
# previous "``$`$Name``" form double-escaped the `$` and wrote `$$Name`
# literally instead of interpolating the skill slug — concatenation is
# unambiguous and matches the bash side byte-for-byte.
$claudeRow = '| TODO: describe when to use ' + $Name + ' | `' + $Name + '` skill |'
$agentsRow = '| TODO: describe when to use ' + $Name + ' | `$' + $Name + '` |'
$agyRow = '| TODO: describe when to use ' + $Name + ' | `.agy/skills/' + $Name + '/SKILL.md` |'

Insert-RoutingRow (Join-Path $KitRoot "tooling\claude\CLAUDE.md") $claudeRow $anchorSubagent
Insert-RoutingRow (Join-Path $KitRoot "tooling\codex\AGENTS.md")  $agentsRow $anchorSubagent
Insert-RoutingRow (Join-Path $KitRoot "tooling\agy\AGY.md") $agyRow $anchorSubagent

# -- Done ------------------------------------------------------------------
Write-Host "+--------------------------------------+" -ForegroundColor Green
Write-Host "|        new-skill scaffolded          |" -ForegroundColor Green
Write-Host "+--------------------------------------+" -ForegroundColor Green
Write-Host "  Created: skills/$Name/SKILL.md"
Write-Host "  Routing:"
foreach ($r in $script:routingResults) {
    Write-Host "    $r"
}
Write-Host ""
if (-not $script:routingOk) {
    Write-Host "  WARNING: one or more routing anchors were missing; the skill file was" -ForegroundColor Yellow
    Write-Host "           created but the routing tables above are incomplete." -ForegroundColor Yellow
    Write-Host ""
}
Write-Host "Next steps:"
Write-Host "  1. Edit skills/$Name/SKILL.md and fill the placeholders."
Write-Host "  2. Replace the TODO routing rows with a real description in:"
Write-Host "       tooling/claude/CLAUDE.md"
Write-Host "       tooling/codex/AGENTS.md"
Write-Host "       tooling/agy/AGY.md"
Write-Host "  3. Add an entry to CHANGELOG.md under [Unreleased] -> Added -> New skills."
Write-Host "  4. Re-run the install script in any target project to deploy."

# Mirror new-skill.sh: surface partial routing as a non-zero exit so CI /
# release scripts cannot treat the scaffold as fully successful when the
# routing tables are out of sync with the new skill file.
if (-not $script:routingOk) {
    exit 1
}

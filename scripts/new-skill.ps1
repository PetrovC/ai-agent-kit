<#
.SYNOPSIS
    Scaffold a new skill under skills/<name>/SKILL.md.

.DESCRIPTION
    Creates the skill file with the standard structure all existing skills follow.
    Reminds you to update routing tables and CHANGELOG.

.PARAMETER Name
    Skill name in kebab-case (lowercase letters, digits, hyphens).

.PARAMETER Description
    One-sentence description of when to use this skill.

.EXAMPLE
    .\new-skill.ps1 -Name "kotlin"
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

if ($Name -notmatch '^[a-z][a-z0-9-]*$') {
    Write-Error "Skill name must be kebab-case (a-z, 0-9, -). Got: $Name"
    exit 1
}

$skillDir  = Join-Path $KitRoot "skills\$Name"
$skillFile = Join-Path $skillDir "SKILL.md"

if (Test-Path $skillDir) {
    Write-Error "skills/$Name already exists."
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = "Use when ... (describe the trigger condition for this skill in one sentence)."
}

New-Item -ItemType Directory -Path $skillDir -Force | Out-Null

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

Set-Content -Path $skillFile -Value $body -Encoding utf8

Write-Host "+--------------------------------------+" -ForegroundColor Green
Write-Host "|        new-skill scaffolded          |" -ForegroundColor Green
Write-Host "+--------------------------------------+" -ForegroundColor Green
Write-Host "  Created: skills/$Name/SKILL.md"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Edit skills/$Name/SKILL.md and fill the placeholders."
Write-Host "  2. Add a routing row in:"
Write-Host "       tooling/claude/CLAUDE.md"
Write-Host "       tooling/codex/AGENTS.md"
Write-Host "       tooling/gemini/GEMINI.md"
Write-Host "  3. Add an entry to CHANGELOG.md under [Unreleased] -> Added -> New skills."
Write-Host "  4. Re-run the install script in any target project to deploy."

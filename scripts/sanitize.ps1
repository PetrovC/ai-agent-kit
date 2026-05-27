<#
.SYNOPSIS
    Redact sensitive values from logs or pasted context.

.DESCRIPTION
    Redacts common secret and identity patterns from text streams:
    - email addresses
    - URL-embedded credentials
    - GitHub tokens
    - bearer tokens
    - AWS access key IDs
    - private RFC1918 IPv4 addresses
    - internal hostnames
    - common secret key/value pairs

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sanitize.ps1 -InputPath ".\raw.log"

.EXAMPLE
    Get-Content .\raw.log -Raw | powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sanitize.ps1
#>

param(
    [string]$InputPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($InputPath -and -not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "Input file does not exist: $InputPath"
}

function Get-InputText {
    if ($InputPath) {
        return Get-Content -LiteralPath $InputPath -Raw
    }

    return [Console]::In.ReadToEnd()
}

function Invoke-Sanitization {
    param([Parameter(Mandatory = $true)][string]$Text)

    $text = $Text
    $text = [regex]::Replace($text, '(https?://)[^/@\s]+:[^/@\s]+@', '$1[REDACTED_CREDENTIALS]@')
    $text = [regex]::Replace($text, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '[REDACTED_EMAIL]')
    $text = [regex]::Replace($text, '\b(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b', '[REDACTED_GITHUB_TOKEN]')
    $text = [regex]::Replace($text, '\b(Bearer\s+)[A-Za-z0-9._-]{10,}', '$1[REDACTED_BEARER_TOKEN]')
    $text = [regex]::Replace($text, '\b(AKIA|ASIA)[A-Z0-9]{16}\b', '[REDACTED_AWS_ACCESS_KEY]')
    $text = [regex]::Replace($text, '\b(10(\.[0-9]{1,3}){3}|192\.168(\.[0-9]{1,3}){2}|172\.(1[6-9]|2[0-9]|3[0-1])(\.[0-9]{1,3}){2})\b', '[REDACTED_PRIVATE_IP]')
    $text = [regex]::Replace($text, '\b([A-Za-z0-9-]+\.)+(internal|corp|localdomain)\b', '[REDACTED_INTERNAL_HOST]')
    $text = [regex]::Replace($text, '("?(password|secret|token|api[_-]?key)"?\s*:\s*)"[^"]*"', '$1"[REDACTED_SECRET]"', 'IgnoreCase')
    $text = [regex]::Replace($text, '\b([A-Za-z0-9_]*(TOKEN|SECRET|PASSWORD|API_KEY)[A-Za-z0-9_]*\s*[:=]\s*)[^\s]+', '$1[REDACTED_SECRET]', 'IgnoreCase')
    return $text
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )

    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

$sanitized = Invoke-Sanitization -Text (Get-InputText)

if ($OutputPath) {
    Write-Utf8NoBom -Path $OutputPath -Text $sanitized
} else {
    [Console]::Out.Write($sanitized)
}

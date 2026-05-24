param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptName
)

$ErrorActionPreference = "Stop"

$candidates = @()
if ($env:ProgramFiles) {
    $candidates += (Join-Path $env:ProgramFiles "Git\bin\bash.exe")
}
$programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
if ($programFilesX86) {
    $candidates += (Join-Path $programFilesX86 "Git\bin\bash.exe")
}
$candidates += "C:\Program Files\Git\bin\bash.exe"

$bash = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $bash) {
    $bashCommand = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCommand) {
        $bash = $bashCommand.Source
    }
}

if (-not $bash) {
    Write-Error "Git Bash was not found. Install Git for Windows or add bash.exe to PATH."
    exit 127
}

$scriptPath = Join-Path $PSScriptRoot $ScriptName
if (-not (Test-Path -LiteralPath $scriptPath)) {
    Write-Error "Hook script not found: $scriptPath"
    exit 127
}

& $bash -lc 'exec "$1"' _ $scriptPath
exit $LASTEXITCODE

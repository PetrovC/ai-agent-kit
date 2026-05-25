param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptName
)

$ErrorActionPreference = "Stop"

$candidates = @()
if ($env:ProgramFiles) {
    $candidates += (Join-Path $env:ProgramFiles "Git\bin\bash.exe")
    $candidates += (Join-Path $env:ProgramFiles "Git\usr\bin\bash.exe")
}
$programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
if ($programFilesX86) {
    $candidates += (Join-Path $programFilesX86 "Git\bin\bash.exe")
    $candidates += (Join-Path $programFilesX86 "Git\usr\bin\bash.exe")
}

$bash = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $bash) {
    $bashCommand = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCommand -and $bashCommand.Source -notlike "*\Windows\System32\bash.exe") {
        $bash = $bashCommand.Source
    }
}

if (-not $bash) {
    Write-Error "Git Bash was not found. Install Git for Windows or add Git Bash to PATH before using Bash hooks."
    exit 127
}

$scriptPath = Join-Path $PSScriptRoot $ScriptName
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    Write-Error "Hook script not found: $scriptPath"
    exit 127
}

& $bash -lc 'exec "$1"' _ $scriptPath
exit $LASTEXITCODE

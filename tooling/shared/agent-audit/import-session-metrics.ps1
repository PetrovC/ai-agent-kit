param(
    [string]$Config = "",
    [string]$SourceRoot = (Get-Location).Path,
    [string]$Provider = "",
    [string]$Transcript = "",
    [string]$RunId = ""
)
if ($env:AAK_DEBUG -and $env:AAK_DEBUG -ne "0" -and $env:AAK_DEBUG -ne "false") { Set-PSDebug -Trace 1 }  # AAK_DEBUG: opt-in trace (#305)

$ErrorActionPreference = "Stop"

function Get-AakPythonInvocation {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) { return @($python.Source) }

    $python3 = Get-Command python3 -ErrorAction SilentlyContinue
    if ($python3) { return @($python3.Source) }

    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) { return @($py.Source, "-3") }

    Write-Error "python, python3, or py -3 is required for agent audit runtime"
    exit 127
}

$runtime = Join-Path $PSScriptRoot "audit_runtime.py"
$pythonInvocation = @(Get-AakPythonInvocation)
$exe = $pythonInvocation[0]
$pythonArgs = @()
if ($pythonInvocation.Count -gt 1) {
    $pythonArgs = @($pythonInvocation[1..($pythonInvocation.Count - 1)])
}

$argsList = @($runtime, "import-session-metrics", "--source-root", $SourceRoot, "--provider", $Provider, "--transcript", $Transcript)
if ($Config) { $argsList += @("--config", $Config) }
if ($RunId) { $argsList += @("--run-id", $RunId) }

& $exe @pythonArgs @argsList
exit $LASTEXITCODE

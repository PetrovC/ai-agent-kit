param(
    [Parameter(Mandatory = $true)]
    [string]$RunId,

    [string]$Config = "",
    [string]$SourceRoot = (Get-Location).Path,
    [switch]$Commit,
    [switch]$Push
)

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

$argsList = @($runtime, "finalize-run", "--source-root", $SourceRoot, "--run-id", $RunId)
if ($Config) { $argsList += @("--config", $Config) }
if ($Commit) { $argsList += "--commit" }
if ($Push) { $argsList += "--push" }

& $exe @pythonArgs @argsList
exit $LASTEXITCODE

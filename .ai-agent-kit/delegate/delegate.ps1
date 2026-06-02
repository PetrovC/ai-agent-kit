param(
    [string]$Provider = "",
    [string]$TaskType = "other",
    [string]$Risk = "medium",
    [string]$BriefFile = "",
    [string]$Config = "",
    [string]$SourceRoot = (Get-Location).Path,
    [string]$RunId = "",
    [string]$InvocationId = "",
    [int]$Timeout = 600
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

    Write-Error "python, python3, or py -3 is required for the delegation adapter"
    exit 127
}

$runtime = Join-Path $PSScriptRoot "delegate.py"
$pythonInvocation = @(Get-AakPythonInvocation)
$exe = $pythonInvocation[0]
$pythonArgs = @()
if ($pythonInvocation.Count -gt 1) {
    $pythonArgs = @($pythonInvocation[1..($pythonInvocation.Count - 1)])
}

$argsList = @(
    $runtime,
    "--provider", $Provider,
    "--task-type", $TaskType,
    "--risk", $Risk,
    "--brief-file", $BriefFile,
    "--source-root", $SourceRoot,
    "--timeout", "$Timeout"
)
if ($Config) { $argsList += @("--config", $Config) }
if ($RunId) { $argsList += @("--run-id", $RunId) }
if ($InvocationId) { $argsList += @("--invocation-id", $InvocationId) }

& $exe @pythonArgs @argsList
exit $LASTEXITCODE

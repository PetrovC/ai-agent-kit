param(
    [string]$Config = "",
    [string]$SourceRoot = (Get-Location).Path,
    [string]$Type = "",
    [string]$Actor = "main_agent",
    [string]$Payload = "",
    [string]$PayloadB64 = "",
    [string]$InvocationId = "",
    [string]$RunId = "",
    [string]$EventId = ""
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

$argsList = @($runtime, "emit-event", "--source-root", $SourceRoot, "--type", $Type, "--actor", $Actor)
if ($Config) { $argsList += @("--config", $Config) }
# JSON payloads are passed base64-encoded so neither this process boundary nor
# the native python call strips the embedded double quotes. -PayloadB64 is the
# quote-free form for programmatic / cross-process callers; -Payload is the
# convenience form for an interactive same-session caller.
if ($PayloadB64) {
    $argsList += @("--payload-b64", $PayloadB64)
} elseif ($Payload) {
    $argsList += @("--payload-b64", [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Payload)))
}
if ($InvocationId) { $argsList += @("--invocation-id", $InvocationId) }
if ($RunId) { $argsList += @("--run-id", $RunId) }
if ($EventId) { $argsList += @("--event-id", $EventId) }

& $exe @pythonArgs @argsList
exit $LASTEXITCODE

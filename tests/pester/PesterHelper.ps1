Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:KitRoot = $null
$script:Target = $null

function Get-AakKitRoot {
    $dir = $PSScriptRoot
    while ($dir -and $dir -ne [System.IO.Path]::GetPathRoot($dir)) {
        if ((Test-Path -LiteralPath (Join-Path $dir "scripts\install.ps1") -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $dir "VERSION") -PathType Leaf)) {
            return $dir
        }
        $dir = Split-Path -Parent $dir
    }

    throw "Could not locate kit root from $PSScriptRoot"
}

function Initialize-AakPesterTest {
    $script:KitRoot = Get-AakKitRoot
    $script:Target = Join-Path ([System.IO.Path]::GetTempPath()) "aak-pester-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:Target -Force | Out-Null
}

function Remove-AakPesterTarget {
    if ($script:Target -and (Test-Path -LiteralPath $script:Target)) {
        Remove-Item -LiteralPath $script:Target -Recurse -Force
    }
}

function Invoke-AakPowerShellScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Script,

        [string[]]$Arguments = @()
    )

    $powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $rawOutput = @(& $powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Script @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $text = ($rawOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine

    [pscustomobject]@{
        ExitCode = $exitCode
        Output = $text
        Lines = $rawOutput
    }
}

function Invoke-AakInstall {
    param([string[]]$Arguments = @())

    Invoke-AakPowerShellScript `
        -Script (Join-Path $script:KitRoot "scripts\install.ps1") `
        -Arguments (@("-Target", $script:Target) + $Arguments)
}

function Invoke-AakUpdate {
    param([string[]]$Arguments = @())

    Invoke-AakPowerShellScript `
        -Script (Join-Path $script:KitRoot "scripts\update.ps1") `
        -Arguments (@("-Target", $script:Target) + $Arguments)
}

function Invoke-AakUninstall {
    param([string[]]$Arguments = @())

    Invoke-AakPowerShellScript `
        -Script (Join-Path $script:KitRoot "scripts\uninstall.ps1") `
        -Arguments (@("-Target", $script:Target) + $Arguments)
}

function Invoke-AakValidate {
    Invoke-AakPowerShellScript `
        -Script (Join-Path $script:KitRoot "scripts\validate.ps1") `
        -Arguments @("-Target", $script:Target)
}

function Assert-AakSuccess {
    param([Parameter(Mandatory = $true)]$Result)

    if ($Result.ExitCode -ne 0) {
        throw "Expected success, got exit $($Result.ExitCode). Output:`n$($Result.Output)"
    }
}

function Assert-AakFailure {
    param([Parameter(Mandatory = $true)]$Result)

    if ($Result.ExitCode -eq 0) {
        throw "Expected failure, got exit 0. Output:`n$($Result.Output)"
    }
}

function Assert-AakOutputContains {
    param(
        [Parameter(Mandatory = $true)]
        $Result,

        [Parameter(Mandatory = $true)]
        [string]$Needle
    )

    if (-not $Result.Output.Contains($Needle)) {
        throw "Expected output to contain '$Needle'. Output:`n$($Result.Output)"
    }
}

function Assert-AakFileExists {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Expected file to exist: $Path"
    }
}

function Assert-AakFileMissing {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        throw "Expected path to be missing: $Path"
    }
}

function Get-AakTargetSnapshot {
    $root = (Resolve-Path -LiteralPath $script:Target).Path.TrimEnd('\')
    Get-ChildItem -LiteralPath $script:Target -Recurse -File |
        Where-Object { $_.Name -ne ".kit-version" } |
        Sort-Object FullName |
        ForEach-Object {
            $rel = $_.FullName.Substring($root.Length).TrimStart('\') -replace '\\', '/'
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            "$hash $rel"
        }
}

function Copy-AakFilledExampleProject {
    $source = Join-Path $script:KitRoot "examples\filled-project"
    Get-ChildItem -LiteralPath $source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $script:Target -Recurse -Force
    }
}

function Set-AakTargetChangelog {
    param([Parameter(Mandatory = $true)][string]$Content)

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $script:Target "CHANGELOG.md"), $Content, $utf8NoBom)
}

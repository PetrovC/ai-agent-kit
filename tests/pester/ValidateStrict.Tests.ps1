Describe "PowerShell validate strict mode" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
        Copy-AakFilledExampleProject
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) {
            Remove-AakPesterTarget
        }
    }

    It "validate.ps1 enforces -RouterMaxLines override" {
        $routerPath = Join-Path $script:Target "CLAUDE.md"
        Set-Content -LiteralPath $routerPath -Value @"
line 1
line 2
"@ -NoNewline

        $result = Invoke-AakValidate -Arguments @("-RouterMaxLines", "1")

        Assert-AakFailure $result
        Assert-AakOutputContains $result "CLAUDE.md has 2 lines; budget is 1"
    }

    It "validate.ps1 -Strict fails when update dry-run would modify docs/ai" {
        New-Item -ItemType Directory -Path (Join-Path $script:Target "scripts") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:Target "tooling\claude") -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:Target ".kit-manifest") -Value "" -NoNewline

        $updateScript = @'
param([string]$Target, [switch]$DryRun)
Write-Host "Changes:"
Write-Host "  UPDATED  docs/ai/PROJECT.md"
exit 0
'@
        Set-Content -LiteralPath (Join-Path $script:Target "scripts\update.ps1") -Value $updateScript -NoNewline

        $result = Invoke-AakValidate -Arguments @("-Strict")

        Assert-AakFailure $result
        Assert-AakOutputContains $result "strict update guard: would modify project-owned path"
        Assert-AakOutputContains $result "docs/ai/PROJECT.md"
    }

    It "validate.ps1 -Strict passes when update dry-run avoids project-owned paths" {
        New-Item -ItemType Directory -Path (Join-Path $script:Target "scripts") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:Target "tooling\claude") -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:Target ".kit-manifest") -Value "" -NoNewline

        $updateScript = @'
param([string]$Target, [switch]$DryRun)
Write-Host "Changes:"
Write-Host "  UPDATED  CLAUDE.md"
exit 0
'@
        Set-Content -LiteralPath (Join-Path $script:Target "scripts\update.ps1") -Value $updateScript -NoNewline

        $result = Invoke-AakValidate -Arguments @("-Strict")

        Assert-AakSuccess $result
        Assert-AakOutputContains $result "update dry-run preserves docs/ai/ and .mcp.json"
    }

    It "validate.ps1 fails when root MCP example drifts from Claude source" {
        $sourceDir = Join-Path $script:Target "tooling\claude"
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:KitRoot "tooling\claude\.mcp.example.jsonc") `
            -Destination (Join-Path $sourceDir ".mcp.example.jsonc")
        Copy-Item -LiteralPath (Join-Path $script:KitRoot "tooling\claude\.mcp.example.jsonc") `
            -Destination (Join-Path $script:Target ".mcp.example.jsonc")
        Set-Content -LiteralPath (Join-Path $script:Target ".kit-manifest") -Value ".mcp.example.jsonc" -NoNewline
        Add-Content -LiteralPath (Join-Path $script:Target ".mcp.example.jsonc") -Value "`n// local drift"

        $result = Invoke-AakValidate -Arguments @("-Strict")

        Assert-AakFailure $result
        Assert-AakOutputContains $result ".mcp.example.jsonc differs from its source under tooling/ or skills/"
    }
}

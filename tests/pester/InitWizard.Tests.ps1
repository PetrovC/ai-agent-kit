Describe "init.ps1 wizard" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest

        # Create docs/ai directory under the temporary target
        $docsAi = Join-Path $script:Target "docs\ai"
        New-Item -ItemType Directory -Path $docsAi -Force | Out-Null

        function Invoke-AakInit {
            param([string[]]$Arguments = @())

            Invoke-AakPowerShellScript `
                -Script (Join-Path $script:KitRoot "scripts\init.ps1") `
                -Arguments (@("-Target", $script:Target) + $Arguments)
        }
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) {
            Remove-AakPesterTarget
        }
    }

    It "dotnet preset seeds COMMANDS.md" {
        $commandsMd = Join-Path $script:Target "docs\ai\COMMANDS.md"
        Set-Content -LiteralPath $commandsMd -Value "STOP"

        $result = Invoke-AakInit -Arguments @("-Preset", "dotnet")
        Assert-AakSuccess $result

        $content = Get-Content -LiteralPath $commandsMd -Raw
        if ($content -notmatch "dotnet build") {
            throw "Expected COMMANDS.md to contain 'dotnet build'"
        }
        if ($content -match "STOP") {
            throw "Expected STOP notice to be removed"
        }
    }

    It "node preset seeds COMMANDS.md" {
        $commandsMd = Join-Path $script:Target "docs\ai\COMMANDS.md"
        Set-Content -LiteralPath $commandsMd -Value "STOP"

        $result = Invoke-AakInit -Arguments @("-Preset", "node")
        Assert-AakSuccess $result

        $content = Get-Content -LiteralPath $commandsMd -Raw
        if ($content -notmatch "npm install") {
            throw "Expected COMMANDS.md to contain 'npm install'"
        }
    }

    It "skips if COMMANDS.md already filled" {
        $commandsMd = Join-Path $script:Target "docs\ai\COMMANDS.md"
        Set-Content -LiteralPath $commandsMd -Value "# Commands`n`nAlready filled."

        $result = Invoke-AakInit -Arguments @("-Preset", "dotnet")
        Assert-AakSuccess $result

        $content = Get-Content -LiteralPath $commandsMd -Raw
        if ($content -match "dotnet") {
            throw "Expected init.ps1 to skip and not write 'dotnet'"
        }
    }
}

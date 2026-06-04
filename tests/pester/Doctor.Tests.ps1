Describe "PowerShell doctor diagnostics" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
        Copy-AakFilledExampleProject

        function Invoke-AakDoctor {
            param([string[]]$Arguments = @())

            Invoke-AakPowerShellScript `
                -Script (Join-Path $script:KitRoot "scripts\doctor.ps1") `
                -Arguments (@("-Target", $script:Target) + $Arguments)
        }
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) {
            Remove-AakPesterTarget
        }
    }

    It "doctor.ps1 runs on examples/filled-project and exits 0 after install" {
        $installResult = Invoke-AakInstall -Arguments @("-Tools", "claude,codex,agy")
        Assert-AakSuccess $installResult

        $result = Invoke-AakDoctor
        Assert-AakSuccess $result
        Assert-AakOutputContains $result "Diagnostics passed successfully. Target install is healthy."
    }

    It "doctor.ps1 exits 2 when a manifest file is missing" {
        $installResult = Invoke-AakInstall -Arguments @("-Tools", "claude,codex,agy")
        Assert-AakSuccess $installResult

        # Remove a file listed in the manifest to trigger manifest drift
        $claudePath = Join-Path $script:Target "CLAUDE.md"
        Remove-Item -LiteralPath $claudePath -Force

        $result = Invoke-AakDoctor
        if ($result.ExitCode -ne 2) {
            throw "Expected exit code 2, got $($result.ExitCode). Output:`n$($result.Output)"
        }
        Assert-AakOutputContains $result "Manifest integrity: Missing file -> CLAUDE.md"
    }

    It "doctor.ps1 exits 1 when a hook is not executable" {
        $installResult = Invoke-AakInstall -Arguments @("-Tools", "claude,codex,agy")
        Assert-AakSuccess $installResult

        # Set environment variable to force hook to be non-executable for testing
        $env:AAK_TEST_FORCE_NON_EXECUTABLE = "1"
        try {
            $result = Invoke-AakDoctor
            if ($result.ExitCode -ne 1) {
                throw "Expected exit code 1, got $($result.ExitCode). Output:`n$($result.Output)"
            }
            Assert-AakOutputContains $result "Hook executability: Hook is not executable"
        } finally {
            Remove-Item Env:\AAK_TEST_FORCE_NON_EXECUTABLE
        }
    }
}

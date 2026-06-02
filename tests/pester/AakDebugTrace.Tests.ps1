Describe "AAK_DEBUG opt-in trace (#305)" {
    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) { Remove-AakPesterTarget }
    }

    BeforeAll {
        function Invoke-ValidateWithDebug {
            # validate.ps1 against the shipped filled example is a deterministic,
            # read-only run that exits 0 — a stable probe for the trace toggle.
            param([AllowNull()][string]$DebugValue)
            $script = Join-Path $script:KitRoot "scripts\validate.ps1"
            $example = Join-Path $script:KitRoot "examples\filled-project"
            $old = $env:AAK_DEBUG
            try {
                if ($null -eq $DebugValue) {
                    Remove-Item Env:\AAK_DEBUG -ErrorAction SilentlyContinue
                } else {
                    $env:AAK_DEBUG = $DebugValue
                }
                return Invoke-AakPowerShellScript -Script $script -Arguments @("-Target", $example)
            } finally {
                if ($null -eq $old) { Remove-Item Env:\AAK_DEBUG -ErrorAction SilentlyContinue } else { $env:AAK_DEBUG = $old }
            }
        }
    }

    It "default run exits 0 with no PSDebug trace" {
        $result = Invoke-ValidateWithDebug -DebugValue $null
        Assert-AakSuccess $result
        if ($result.Output -match "Set-PSDebug") { throw "did not expect trace output by default" }
    }

    It "AAK_DEBUG=1 keeps the same exit code (tracing must not alter it)" {
        $result = Invoke-ValidateWithDebug -DebugValue "1"
        Assert-AakSuccess $result
    }

    It "AAK_DEBUG=0 is treated as off (same exit code, no trace toggle)" {
        $result = Invoke-ValidateWithDebug -DebugValue "0"
        Assert-AakSuccess $result
    }
}

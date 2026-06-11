Describe "bootstrap.ps1 PowerShell engine resolution" {
    BeforeAll {
        . "$PSScriptRoot\PesterHelper.ps1"
        $KitRoot = Get-AakKitRoot
        # Dot-source the bootstrap script. The InvocationName guard makes this
        # define functions only — no version fetch, download, or install runs.
        . (Join-Path $KitRoot "scripts\bootstrap.ps1")
    }

    It "prefers pwsh when PowerShell 7+ is available" {
        Mock Get-Command -ParameterFilter { $Name -eq "pwsh" } -MockWith {
            [pscustomobject]@{ Name = "pwsh" }
        }

        Resolve-AakPowerShellEngine | Should -Be "pwsh"
    }

    It "falls back to powershell when pwsh is absent" {
        Mock Get-Command -ParameterFilter { $Name -eq "pwsh" } -MockWith { $null }

        Resolve-AakPowerShellEngine | Should -Be "powershell"
    }
}

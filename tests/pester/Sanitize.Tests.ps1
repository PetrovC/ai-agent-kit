Describe "sanitize.ps1 redaction coverage" {
    BeforeAll {
        function Invoke-SanitizeFile {
            param([Parameter(Mandatory = $true)][string]$Content)

            $inputPath = Join-Path $script:Target "raw.log"
            $outputPath = Join-Path $script:Target "sanitized.log"
            [System.IO.File]::WriteAllText($inputPath, $Content, (New-Object System.Text.UTF8Encoding($false)))

            $result = Invoke-AakPowerShellScript `
                -Script (Join-Path $script:KitRoot "scripts\sanitize.ps1") `
                -Arguments @("-InputPath", $inputPath, "-OutputPath", $outputPath)

            [pscustomobject]@{
                Result = $result
                Output = if (Test-Path -LiteralPath $outputPath) { Get-Content -LiteralPath $outputPath -Raw } else { "" }
            }
        }
    }

    BeforeEach {
        . "$PSScriptRoot\PesterHelper.ps1"
        Initialize-AakPesterTest
    }

    AfterEach {
        if (Get-Command Remove-AakPesterTarget -ErrorAction SilentlyContinue) {
            Remove-AakPesterTarget
        }
    }

    It "redacts email addresses" {
        $run = Invoke-SanitizeFile -Content "contact jane.doe@example.com"
        Assert-AakSuccess $run.Result
        if ($run.Output -notmatch "\[REDACTED_EMAIL\]") {
            throw "Expected email redaction marker. Output: $($run.Output)"
        }
    }

    It "redacts URL credentials" {
        $run = Invoke-SanitizeFile -Content "url https://user:pass@api.internal/path"
        Assert-AakSuccess $run.Result
        if ($run.Output -notmatch "https://\[REDACTED_CREDENTIALS\]@") {
            throw "Expected URL credential redaction marker. Output: $($run.Output)"
        }
    }

    It "redacts GitHub and bearer tokens" {
        $content = "ghp_1234567890abcdefghijABCDEFGHIJ Bearer abcdefghijklmnop123456"
        $run = Invoke-SanitizeFile -Content $content
        Assert-AakSuccess $run.Result
        if ($run.Output -notmatch "\[REDACTED_GITHUB_TOKEN\]") {
            throw "Expected GitHub token redaction marker. Output: $($run.Output)"
        }
        if ($run.Output -notmatch "Bearer \[REDACTED_BEARER_TOKEN\]") {
            throw "Expected bearer token redaction marker. Output: $($run.Output)"
        }
    }

    It "redacts AWS key IDs and private IP addresses" {
        $run = Invoke-SanitizeFile -Content "AKIA1234567890ABCDEF 192.168.1.44"
        Assert-AakSuccess $run.Result
        if ($run.Output -notmatch "\[REDACTED_AWS_ACCESS_KEY\]") {
            throw "Expected AWS key redaction marker. Output: $($run.Output)"
        }
        if ($run.Output -notmatch "\[REDACTED_PRIVATE_IP\]") {
            throw "Expected private IP redaction marker. Output: $($run.Output)"
        }
    }

    It "redacts internal hostnames and secret fields" {
        $content = 'svc auth.service.corp {"password":"open-sesame"}'
        $run = Invoke-SanitizeFile -Content $content
        Assert-AakSuccess $run.Result
        if ($run.Output -notmatch "\[REDACTED_INTERNAL_HOST\]") {
            throw "Expected internal hostname redaction marker. Output: $($run.Output)"
        }
        if ($run.Output -notmatch '"password":"\[REDACTED_SECRET\]"') {
            throw "Expected password redaction marker. Output: $($run.Output)"
        }
    }

    It "redacts uppercase secret assignments" {
        $run = Invoke-SanitizeFile -Content "OPENAI_API_KEY=sk-super-secret"
        Assert-AakSuccess $run.Result
        if ($run.Output -notmatch "OPENAI_API_KEY=\[REDACTED_SECRET\]") {
            throw "Expected uppercase secret assignment redaction marker. Output: $($run.Output)"
        }
    }

    It "redacts OpenAI API keys" {
        $run = Invoke-SanitizeFile -Content "key sk-ABCDEFGHIJKLMNOPQRSTUVWX here"
        Assert-AakSuccess $run.Result
        if ($run.Output -notmatch "\[REDACTED_API_KEY\]") {
            throw "Expected OpenAI API key redaction marker. Output: $($run.Output)"
        }
    }

    It "redacts GitLab tokens" {
        $run = Invoke-SanitizeFile -Content "token glpat-ABCDEFGHIJKLMNOPQRST here"
        Assert-AakSuccess $run.Result
        if ($run.Output -notmatch "\[REDACTED_GITLAB_TOKEN\]") {
            throw "Expected GitLab token redaction marker. Output: $($run.Output)"
        }
    }
}

Describe "PowerShell validate release metadata" {
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

    It "validate.ps1 skips release metadata checks when CHANGELOG.md is absent" {
        $result = Invoke-AakValidate

        Assert-AakSuccess $result
        Assert-AakOutputContains $result "no CHANGELOG.md"
    }

    It "validate.ps1 passes with one Unreleased section and no versioned sections" {
        Set-AakTargetChangelog @'
# Changelog

## [Unreleased]

### Added
- Initial feature.
'@

        $result = Invoke-AakValidate

        Assert-AakSuccess $result
        Assert-AakOutputContains $result "CHANGELOG.md: exactly one [Unreleased] section"
        Assert-AakOutputContains $result "CHANGELOG.md: no duplicate version sections"
        Assert-AakOutputContains $result "CHANGELOG.md: all version headings use valid format"
    }

    It "validate.ps1 passes with dated versioned sections" {
        Set-AakTargetChangelog @'
# Changelog

## [Unreleased]

## [1.1.0] - 2026-05-01

### Changed
- Something changed.

## [1.0.0] - 2026-04-01

### Added
- Initial release.
'@

        $result = Invoke-AakValidate

        Assert-AakSuccess $result
        Assert-AakOutputContains $result "CHANGELOG.md: exactly one [Unreleased] section"
        Assert-AakOutputContains $result "CHANGELOG.md: no duplicate version sections"
        Assert-AakOutputContains $result "CHANGELOG.md: all version headings use valid format"
    }

    It "validate.ps1 passes with an undated versioned section" {
        Set-AakTargetChangelog @'
# Changelog

## [Unreleased]

## [1.0.0]

### Added
- Initial release.
'@

        $result = Invoke-AakValidate

        Assert-AakSuccess $result
        Assert-AakOutputContains $result "CHANGELOG.md: all version headings use valid format"
    }

    It "validate.ps1 fails when CHANGELOG.md has no Unreleased section" {
        Set-AakTargetChangelog @'
# Changelog

## [1.0.0] - 2026-04-01

### Added
- Initial release.
'@

        $result = Invoke-AakValidate

        Assert-AakFailure $result
        Assert-AakOutputContains $result "CHANGELOG.md: no [Unreleased] section"
    }

    It "validate.ps1 fails when CHANGELOG.md has two Unreleased sections" {
        Set-AakTargetChangelog @'
# Changelog

## [Unreleased]

### Added
- First batch.

## [Unreleased]

### Added
- Second batch.
'@

        $result = Invoke-AakValidate

        Assert-AakFailure $result
        Assert-AakOutputContains $result "[Unreleased] sections (expected exactly 1)"
    }

    It "validate.ps1 fails when CHANGELOG.md has duplicate version sections" {
        Set-AakTargetChangelog @'
# Changelog

## [Unreleased]

## [1.0.0] - 2026-04-01

### Added
- Original.

## [1.0.0] - 2026-04-15

### Fixed
- Duplicate.
'@

        $result = Invoke-AakValidate

        Assert-AakFailure $result
        Assert-AakOutputContains $result "duplicate version section [1.0.0]"
    }

    It "validate.ps1 fails when a version heading has a non-ISO date" {
        Set-AakTargetChangelog @'
# Changelog

## [Unreleased]

## [1.0.0] - not-a-date

### Added
- Something.
'@

        $result = Invoke-AakValidate

        Assert-AakFailure $result
        Assert-AakOutputContains $result "invalid heading format"
    }

    It "validate.ps1 fails when a version heading has extra trailing text" {
        Set-AakTargetChangelog @'
# Changelog

## [Unreleased]

## [1.0.0] BREAKING CHANGES

### Added
- Something.
'@

        $result = Invoke-AakValidate

        Assert-AakFailure $result
        Assert-AakOutputContains $result "invalid heading format"
    }
}

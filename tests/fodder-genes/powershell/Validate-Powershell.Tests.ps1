# Validate-Powershell.Tests.ps1
# Runs INSIDE the catlet (Windows PowerShell on Windows, pwsh on Linux).

BeforeAll {
    $script:pwsh = if ($IsLinux) { '/usr/bin/pwsh' } else { 'C:\Program Files\PowerShell\7\pwsh.exe' }
}

Describe "PowerShell 7" {
    It "is installed" {
        Test-Path $pwsh | Should -BeTrue
    }

    It "runs a script block" {
        & $pwsh -NoProfile -Command '1 + 1' | Should -Be 2
    }
}

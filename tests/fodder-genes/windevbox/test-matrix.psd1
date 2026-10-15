# test-matrix.psd1 - windevbox catlet geneset. Format: see tests/README.md.
# Test a tag, e.g. .\Test-FodderGene.ps1 -Gene dbosoft/windevbox/win11-next
# -ProvisioningTimeoutMinutes 120 (Visual Studio takes most of the time).

@{
    TestSuites = @(
        @{
            Name = "DevBox"
            OSMatrix = @("win11-24h2-enterprise")
            CatletSpec = "catlets/win11.yaml"
            HostTests = @(
                @{ Name = "C: was extended to the 127 GB disk"; Command = "[int]((Get-Volume -DriveLetter C).Size / 1GB)"; Expect = '^1[0-2]\d$' }
                @{ Name = "E: is a trusted dev drive"; Command = "fsutil devdrv query E:"; Expect = '(?i)trusted' }
                @{ Name = "git is installed and configured"; Command = "& 'C:\Program Files\Git\cmd\git.exe' config --system init.defaultBranch"; Expect = '^main$' }
                @{ Name = "Node.js is installed"; Command = "Test-Path 'C:\Program Files\nodejs\node.exe'"; Expect = 'True' }
                @{ Name = "GitHub CLI is installed"; Command = "Test-Path 'C:\Program Files\GitHub CLI\gh.exe'"; Expect = 'True' }
                @{ Name = "PowerShell 7 is installed"; Command = "Test-Path 'C:\Program Files\PowerShell\7\pwsh.exe'"; Expect = 'True' }
                @{ Name = "VS Code is installed"; Command = "Test-Path 'C:\Program Files\Microsoft VS Code\Code.exe'"; Expect = 'True' }
                @{ Name = "Visual Studio is installed"; Command = "Test-Path 'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe'"; Expect = 'True' }
                @{ Name = "Hyper-V is enabled"; Command = "(Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All).State"; Expect = 'Enabled' }
            )
        }
    )
}

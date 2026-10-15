# test-matrix.psd1 - hyperv fodder gene (install). Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            Name = "ServerInstall"
            OSMatrix = @("winsrv2022-standard")
            CatletSpec = "catlets/install.yaml"
            HostTests = @(
                @{ Name = "Hyper-V role is installed"; Command = "(Get-WindowsFeature Hyper-V).Installed"; Expect = 'True' }
                @{ Name = "Hyper-V PowerShell works"; Command = "(Get-Command Get-VM).Source"; Expect = 'Hyper-V' }
            )
        }
        @{
            Name = "ClientInstall"
            OSMatrix = @("win11-24h2-enterprise")
            CatletSpec = "catlets/install.yaml"
            HostTests = @(
                @{ Name = "Hyper-V is enabled"; Command = "(Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All).State"; Expect = 'Enabled' }
                @{ Name = "Hyper-V PowerShell works"; Command = "(Get-Command Get-VM).Source"; Expect = 'Hyper-V' }
            )
        }
    )
}

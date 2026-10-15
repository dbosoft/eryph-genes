# test-matrix.psd1 - winget fodder gene
# Format: see tests/README.md.
# winget is an AppX package and cannot run as SYSTEM (see src/winget/readme.md);
# host checks run in the guest-services service context, so they verify the
# installation state instead of running winget.

@{
    TestSuites = @(
        @{
            Name = "WingetInstall"
            OSMatrix = @("winsrv2022-standard", "win10-20h2-enterprise", "win11-24h2-enterprise")
            CatletSpec = "catlets/basic-winget-test.yaml"
            HostTests = @(
                @{ Name = "App Installer is installed for all users"; Command = "(Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller).Version"; Expect = '\d+\.\d+' }
                @{ Name = "winget.exe is present"; Command = "Test-Path `"`$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe`""; Expect = 'True' }
            )
        }

        @{
            # Server 2019 has no supported winget; the gene must not break provisioning there.
            Name = "WingetUnsupportedOS"
            OSMatrix = @("winsrv2019-standard")
            CatletSpec = "catlets/winget-compatibility-test.yaml"
            HostTests = @(
                @{ Name = "OS is Server 2019"; Command = "(Get-CimInstance Win32_OperatingSystem).BuildNumber"; Expect = '^17763' }
            )
        }
    )
}

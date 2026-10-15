# test-matrix.psd1 - winget fodder gene
# Format: see tests/README.md.
# winget is an AppX package and cannot run as SYSTEM (see src/winget/readme.md);
# host checks run in the guest-services service context, so they verify the
# installation state instead of running winget. Server 2019 is not supported.

@{
    TestSuites = @(
        @{
            Name = "WingetInstall"
            OSMatrix = @("winsrv2022-standard", "win10-20h2-enterprise", "win11-24h2-enterprise")
            CatletSpec = "catlets/basic-winget-test.yaml"
            HostTests = @(
                @{ Name = "App Installer is provisioned for all users"; Command = "(Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq Microsoft.DesktopAppInstaller).Version"; Expect = '\d+\.\d+' }
                @{ Name = "winget.exe is present"; Command = "Test-Path `"`$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe`""; Expect = 'True' }
            )
        }
    )
}

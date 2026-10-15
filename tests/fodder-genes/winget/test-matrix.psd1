# test-matrix.psd1 - winget fodder gene
# Format: see tests/README.md.
# winget is an AppX package and cannot run as SYSTEM (see src/winget/readme.md);
# host checks run in the guest-services service context, so they verify the
# installation state instead of running winget. Server 2019 is not supported.
# win10-20h2-enterprise is left out until its image is rebuilt: 20250914 still
# provisions with cloudbase-init.

@{
    TestSuites = @(
        @{
            Name = "WingetInstall"
            OSMatrix = @("winsrv2022-standard", "win11-24h2-enterprise")
            CatletSpec = "catlets/basic-winget-test.yaml"
            HostTests = @(
                @{ Name = "App Installer is provisioned for all users"; Command = "(Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq Microsoft.DesktopAppInstaller).Version"; Expect = '\d+\.\d+' }
                @{ Name = "winget.exe is present"; Command = "Test-Path `"`$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe`""; Expect = 'True' }
            )
        }
        @{
            # packages variable: winget runs as Local System through the wrapper
            Name = "WingetPackages"
            OSMatrix = @("winsrv2022-standard", "win11-24h2-enterprise")
            CatletSpec = "catlets/winget-packages-test.yaml"
            HostTests = @(
                @{ Name = "package from the variable is installed"; Command = "Test-Path `"`$env:ProgramFiles\7-Zip\7z.exe`""; Expect = 'True' }
                @{ Name = "wrapper runs winget as Local System"; Command = "& C:\ProgramData\eryph\winget\winget-system.ps1 --version"; Expect = '^v\d+\.\d+' }
                @{ Name = "installing again is accepted"; Command = "& C:\ProgramData\eryph\winget\winget-system.ps1 install --id 7zip.7zip --exact --source winget --scope machine --silent --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Null; `"rc=`$LASTEXITCODE`""; Expect = 'rc=(0|-1978335189|-1978335135)$' }
            )
        }
    )
}

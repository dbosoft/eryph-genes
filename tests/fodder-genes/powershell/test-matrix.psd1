# test-matrix.psd1 - powershell fodder gene
# Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            Name = "LinuxInstall"
            OSMatrix = @("ubuntu-24.04")
            CatletSpec = "catlets/linux-install.yaml"
            HostTests = @(
                @{ Name = "pwsh is on the PATH"; Command = "pwsh -NoProfile -Command '`$PSVersionTable.PSVersion.ToString()' < /dev/null"; Expect = '^7\.' }
                @{ Name = "PowerShell ssh subsystem is configured"; Command = "cat /etc/ssh/sshd_config.d/99-powershell.conf"; Expect = 'Subsystem powershell /usr/bin/pwsh -sshs' }
            )
            InVMTests = @("Validate-Powershell.Tests.ps1")
        }

        @{
            Name = "WindowsInstall"
            OSMatrix = @("winsrv2022-standard")
            CatletSpec = "catlets/win-install.yaml"
            HostTests = @(
                # Full path: the msi adds pwsh to the machine PATH, but the
                # guest-services process keeps the PATH it started with.
                @{ Name = "pwsh 7 is installed"; Command = "& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -Command '`$PSVersionTable.PSVersion.ToString()'"; Expect = '^7\.' }
            )
            InVMTests = @("Validate-Powershell.Tests.ps1")
        }
    )
}

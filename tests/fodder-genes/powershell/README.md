# powershell fodder gene tests

```powershell
.\Test-FodderGene.ps1 -Gene dbosoft/powershell                       # both suites
.\Test-FodderGene.ps1 -Gene dbosoft/powershell -Suite LinuxInstall    # Linux only
```

`LinuxInstall` installs `linux-install` on Ubuntu 24.04, `WindowsInstall` installs `win-install`
on Server 2022. Both run host checks and `Validate-Powershell.Tests.ps1` inside the catlet. On
Linux the in-VM Pester run needs pwsh, which this gene provides itself.

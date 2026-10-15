# winget fodder gene tests

```powershell
.\Test-FodderGene.ps1 -Gene dbosoft/winget                                              # all suites (elevated)
.\Test-FodderGene.ps1 -Gene dbosoft/winget -Suite WingetInstall -BaseOS winsrv2022-standard -KeepVM
```

| Suite | OS | Checks |
|---|---|---|
| WingetInstall | Server 2022, Win10 20H2, Win11 24H2 | App Installer installed for all users, `winget.exe` present |
| WingetUnsupportedOS | Server 2019 | the gene provisions cleanly on an OS without supported winget |

winget is an AppX package and cannot run as SYSTEM (see `src/winget/readme.md`). The host checks
run in the guest-services service context, so they check the installation state instead of
running winget commands.

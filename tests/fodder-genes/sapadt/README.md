# sapadt fodder gene tests

```powershell
.\Test-FodderGene.ps1 -Gene dbosoft/sapadt                                             # all suites (elevated)
.\Test-FodderGene.ps1 -Gene dbosoft/sapadt -BaseOS win11-24h2-enterprise -KeepVM
```

| Suite | OS | Checks |
|---|---|---|
| SapAdtInstall | Win11 24H2, Server 2022 | VC++ v14 runtime, `C:\eclipse\eclipse.exe` with bundled JRE, ADT core feature, Start menu shortcut |

The fodder downloads about 600 MB (Eclipse and ADT) and takes 3 to 5 minutes.

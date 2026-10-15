# sapdev fodder gene tests

```powershell
.\Test-FodderGene.ps1 -Gene dbosoft/sapdev     # elevated
```

| Suite | OS | Checks |
|---|---|---|
| SapDevTools | Win11 24H2 | cds, ui5 and mbt in `C:\ProgramData\npm`, npm prefix on the system PATH, cf CLI v8 with the multiapps plugin in `CF_PLUGIN_HOME`, BTP CLI (license accepted in the test catlet) |

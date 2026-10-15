# Test infrastructure

How to write and run gene tests: [docs/gene-testing.md](../docs/gene-testing.md).

```
eryph-genes/
├── Test-PackedBaseCatlet.ps1 / .Tests.ps1   # base catlets (OS images) after pack_build.ps1
├── Test-FodderGene.ps1 / .Tests.ps1         # fodder genes, driven by test-matrix.psd1
├── Test-GeneRelease.ps1                     # release gate: Test-FodderGene per tag, optionally from the local build
├── Copy-ToLocalGenepool.ps1                 # .packed build -> local eryph-zero genepool
└── tests/
    ├── EryphTestHelpers.psm1                # shared helpers (EGS access, file copy, provisioning wait, diagnostics)
    ├── vm-runner.ps1                        # runs Pester inside a catlet
    ├── base-catlet/<os>/                    # in-VM validation of base catlets
    └── fodder-genes/<geneset>/              # test matrix, catlet specs and in-VM tests per fodder gene
```

All entry points run in an elevated PowerShell session (host-side `egs-tool`, VmId) and need
Pester 5 or 6.

## Helpers (EryphTestHelpers.psm1)

| Function | Purpose |
|---|---|
| `Initialize-EGSConnection` | `egs-tool add-ssh-config <vmid>` (alias `<vmid>.hyper-v.alt` + key exchange) |
| `Wait-EGSReady` | Wait until `egs-tool get-status` reports `available` |
| `Wait-ProvisioningComplete` | Wait until the fodder finished: Windows `state.json` Final stage plus per-script exit codes, Linux `cloud-init status` |
| `Invoke-EGSCommand` / `Invoke-EGSCommandWithExitCode` | Run a command in the guest over EGS SSH |
| `Copy-FileToVM` / `Copy-DirectoryToVM` / `Copy-PesterToVM` | Upload via `egs-tool upload-file` |
| `Copy-TestSuiteToVM` | Pester + validation files + runner for the base catlet tests |
| `Save-ProvisioningDiagnostics` | Copy provisioning state and logs from the guest into `diagnostics/` |
| `Get-EgsServiceLog` / `Get-CloudInitLog` / `Get-CloudInitLogs` | Provisioning agent log for manual debugging: Windows egs `agent.log`, Linux `cloud-init.log` |
| `Get-OsTypeForGeneset` | `windows` / `linux` from a base geneset name |

Windows base catlets run eryph guest services (`egs-service`) as provisioning agent; there is no
cloudbase-init anymore. Linux base catlets use cloud-init.

## Troubleshooting

- `egs-tool get-status <vmid>` shows whether guest services are reachable.
- `egs-tool add-ssh-config <vmid>` writes the alias again; afterwards `ssh <vmid>.hyper-v.alt -C hostname`.
- A failed fodder run leaves its diagnostics in `diagnostics/`. Re-run with `-KeepVM` to inspect
  the catlet; see [docs/fodder-debugging.md](../docs/fodder-debugging.md).

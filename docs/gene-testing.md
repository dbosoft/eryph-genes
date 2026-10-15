# Gene testing

Two test paths, both PowerShell + Pester (5 or 6), both run from the repo root in an
**elevated** session: they reach the catlets through host-side `egs-tool` (Hyper-V socket, VmId).

| What | Entry point | Tests in |
|---|---|---|
| Base catlets (OS images) after `pack_build.ps1` | `Test-PackedBaseCatlet.ps1` | `tests/base-catlet/<os>/Validate-BaseOS.Tests.ps1` |
| Fodder genes | `Test-FodderGene.ps1` | `tests/fodder-genes/<geneset>/` |

Base catlet builds and their tests normally run through the `/build-base-catlets` skill.

## Fodder genes

```powershell
.\Test-FodderGene.ps1 -Gene dbosoft/powershell                          # all suites, OS matrix from the test matrix
.\Test-FodderGene.ps1 -Gene dbosoft/winget/1.0 -Suite WingetInstall -BaseOS winsrv2022-standard -KeepVM
.\Test-GeneRelease.ps1 dbosoft/winget -FromBuild                       # copy the local build (tag next) to the local genepool, then test
```

The gene must be resolvable by eryph-zero: either published, or a local build copied with
`Copy-ToLocalGenepool.ps1`. A local `turbo build` always packs the tag `next`, so test a build as `dbosoft/<geneset>/next` (`Test-GeneRelease.ps1 -FromBuild` does both).

For each suite and each base OS, `Test-FodderGene.ps1`:
1. Fills the suite's catlet spec (`{{OS_VERSION}}`, `{{GENE}}`) and gives it a short unique name.
2. Deploys and starts it, sets up host-side EGS, waits for guest services.
3. Waits until provisioning finished:
   - Windows: `state.json` lists the Final stage. A failing script does not stop provisioning on
     Windows and doesn't show up in `state.json`, so the per-script logs are checked as well. Any
     `exit-code` other than 0, 1001 or 1003 counts as a provisioning failure.
   - Linux: `cloud-init status` is `done`, `error` or `degraded`.
4. Runs `Test-FodderGene.Tests.ps1` against the running catlet:
   - provisioning completed without failure
   - every host check
   - the in-VM Pester files
5. On failure, saves the guest's provisioning state and logs to `diagnostics/<timestamp>_...`.
6. Removes the catlet, unless `-KeepVM` is set.

Exit code 0 only when every suite passed on every OS.

### Test layout

```
tests/fodder-genes/<geneset>/
├── test-matrix.psd1              # required
├── catlets/<spec>.yaml           # one per suite (may be shared)
├── Validate-<Gene>.Tests.ps1     # optional, runs inside the catlet
└── README.md                     # what the suites cover
```

`tests/fodder-genes/powershell` is a complete example (Linux + Windows, host checks and in-VM
tests). `tests/fodder-genes/winget` shows several suites with different OS matrices.

### test-matrix.psd1

```powershell
@{
    TestSuites = @(
        @{
            Name       = "LinuxInstall"                  # -Suite filter, report name
            OSMatrix   = @("ubuntu-24.04")               # base geneset names (dbosoft/<name>)
            CatletSpec = "catlets/linux-install.yaml"
            HostTests  = @(
                @{ Name = "pwsh is on the PATH"; Command = "pwsh --version < /dev/null"; Expect = '^PowerShell 7' }
                @{ Name = "config written"; Command = "test -f /etc/myapp.conf" }   # exit code 0 = pass
                @{ Name = "expected failure"; Command = "..."; ExitCode = 1 }
            )
            InVMTests  = @("Validate-Powershell.Tests.ps1")   # optional
        }
    )
}
```

- **HostTests** run one command each in the guest through EGS SSH. A check passes when the exit
  code matches `ExitCode` (default 0) and the output matches the regex `Expect`, if one is set.
  - On Windows the command runs in PowerShell, started by the guest-services service. Use
    `sc.exe` and `Get-Content`, not the `sc`/`type` aliases.
  - On Linux it runs as root in the default shell.
  - Commands get no stdin and no TTY ([guest-services#68](https://github.com/eryph-org/guest-services/issues/68)),
    so never use a command that prompts. Pass the non-interactive flags (winget
    `--accept-source-agreements --disable-interactivity`, `apt-get -y`); on Linux add `< /dev/null`.
  - Tools installed by the fodder may not be on the service's PATH yet; call them by full path.
- **InVMTests** are uploaded with Pester and `tests/vm-runner.ps1` and run inside the catlet:
  Windows PowerShell on Windows, `pwsh` on Linux. Linux specs therefore need
  `gene:dbosoft/powershell:linux-install`, unless the gene under test installs pwsh itself.
- The OS type comes from the geneset name: `win*` is Windows; ubuntu, debian, alma, rocky,
  oracle, centos, fedora and rhel are Linux. Anything else fails fast.

### Catlet specs

```yaml
name: powershell-linux-test             # replaced by a unique short name
parent: dbosoft/{{OS_VERSION}}/starter

fodder:
  - source: gene:{{GENE}}:linux-install  # the fodder name is required
```

- `{{GENE}}` is `org/geneset` or `org/geneset/tag` (when a tag was given), so it always needs
  the `:<fodder-name>` suffix. `{{GENE_TAG}}` is an alias kept for older specs.
- `starter` parents already contain starter-food; don't add it again.
- Validate a spec before a long test run: fill in the placeholders and call `validate_catlet`.

### In-VM tests

Plain Pester files; they run inside the catlet with full access to it:

```powershell
Describe "PowerShell 7" {
    It "is installed" {
        Test-Path 'C:\Program Files\PowerShell\7\pwsh.exe' | Should -BeTrue
    }
}
```

Use `$IsLinux` when one file serves both OS types (Windows PowerShell leaves it undefined).

## Debugging a failed run

- `diagnostics/<timestamp>_<geneset>_<suite>_<os>/` has the guest's provisioning state and logs:
  - Windows: `state.json`, `agent.log`, per-script logs.
  - Linux: cloud-init status and logs, rendered scripts.
- Re-run the failing suite with `-Suite <name> -BaseOS <os> -KeepVM` and inspect the catlet with
  the MCP tools (`get_provisioning_log`, `catlet_exec`). `docs/fodder-debugging.md` lists what to
  look at.
- Clean up kept catlets afterwards (`remove_catlet`).

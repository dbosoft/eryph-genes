# Tooling

Which tool to use for what in this repository. Verified against eryph-zero 0.5.1 and guest
services 0.7.0.

## eryph MCP server (catlet work)

The repo's `.mcp.json` starts the eryph MCP server (`eryph-mcp`, stdio). It uses the local user's
eryph client credentials, like the PowerShell module and egs-tool. Install it once as a dotnet
tool: `dotnet tool install -g Eryph.Mcp.Server` (add `--add-source <folder with the nupkg>` until
it is on a public feed).

| Tool | Purpose |
|---|---|
| `validate_catlet(config, variables, name)` | Parse, resolve genes and variables, return the expanded config. The source of truth for syntax. Without a name, `catlet` is used. |
| `deploy_catlet(config, variables, name, project, waitSeconds)` | Create a catlet. Returns catlet id, or an operation id if not finished in time. |
| `get_operation(operationId, waitSeconds)` | Follow a long-running operation. |
| `list_catlets(project)` / `get_catlet(catletId)` | Inventory and status (incl. VmId, provisioning status). |
| `start_catlet` / `stop_catlet(mode)` / `remove_catlet` | Lifecycle, by catlet id. |
| `wait_for_provisioning(catletId, timeoutSeconds)` | Wait until guest services report and provisioning finished or failed. |
| `get_provisioning_log(catletId)` | The provisioning log the guest reported. |
| `catlet_exec(catletId, command, timeoutSeconds)` | Run a non-interactive command in the guest (stdout+stderr merged). No SSH setup, no admin. |

**Errors:** every error starts with its category:
- `[content error]`: change the catlet or fodder definition.
- `[state error]`: change the system state, for example a catlet that is stopped, missing or
  already exists.
- `[transient error]`: retry.

**`catlet_exec` notes:**
- **Windows:** the shell is PowerShell, so use `sc.exe` and `Get-Content` instead of the `sc` and
  `type` aliases.
- **Linux:** the default shell runs as root.
- **No stdin, no TTY:** append `< /dev/null` to commands that might read stdin. Guest services
  never close a command's stdin ([guest-services#68](https://github.com/eryph-org/guest-services/issues/68)).
  Plain `ssh host 'cmd'` has the same problem.

Always address catlets by **catlet id**; names are not unique.

## egs-tool (file transfer, interactive SSH)

Not covered by the MCP server. `egs-tool --help` / `egs-tool catlet --help` list everything.

Off-host or without admin, through eryph (takes the **catlet id**):

```
egs-tool catlet get-status <catlet-id>
egs-tool catlet upload-file <catlet-id> <local> <remote>        # also upload-directory
egs-tool catlet download-file <catlet-id> <remote> <local>      # also download-directory
egs-tool catlet add-ssh-config <catlet-id> --add-key             # then: ssh <catlet-id>.eryph.alt
```

On the Hyper-V host, as admin, through the Hyper-V socket (takes the **VmId**, used by the test
scripts):

```
egs-tool add-ssh-config <vmid>        # writes the <vmid>.hyper-v.alt alias and exchanges keys
egs-tool get-status <vmid>
ssh <vmid>.hyper-v.alt -C "<command>"
egs-tool upload-file <vmid> <local> <remote>
```

Use plain `ssh`; the alias routes through a ProxyCommand, no OpenSSH path pinning.

## eryph PowerShell module (scripts)

The repo's test scripts (`Test-PackedBaseCatlet.ps1`, `Test-FodderGene.ps1`) use the cmdlets
`New-Catlet`, `Start-Catlet`, `Get-Catlet`, `Remove-Catlet`, `Test-Catlet`, `Get-EryphOperation`.
Pipe YAML that has variables with `-SkipVariablesPrompt`, otherwise New-Catlet/Test-Catlet fail
with a NullReferenceException. For interactive work use the MCP server instead.

## Build, local genepool, tests

All from the repo root, PowerShell. Test scripts need an elevated session (host-side egs-tool).

```powershell
pnpm install
pnpm turbo build --filter=@dbosoft/<geneset>...        # one geneset and its tags
pnpm turbo build                                       # everything

.\Resolve-GenepoolPath.ps1                             # local genepool path (admin), cached by the scripts
.\Copy-ToLocalGenepool.ps1 -Geneset dbosoft/<geneset>/next    # .packed build -> LOCAL genepool

.\Test-FodderGene.ps1 -Gene dbosoft/<geneset>[/<tag>] [-Suite ...] [-BaseOS ...] [-KeepVM]
.\Test-GeneRelease.ps1 dbosoft/<geneset> -FromBuild           # copy next + test
.\Test-PackedBaseCatlet.ps1 -Geneset dbosoft/<os>/<date> -GenepoolPath <path> -OsType windows|linux
```

`.\Test-Repository.ps1` runs the static checks the CI runs on every PR (no Hyper-V needed).
`.\prepare.ps1 [-BaseCatlets]` installs or checks the required tools.

Base catlet builds (`build.ps1`, hours) run through the `/build-base-catlets` skill, or in CI with
`azure-pipelines-base-catlets.yml` (manual, self-hosted pool `eryph`, no push).

**Never use for testing:** `push_packed.ps1` and `pnpm publish-genesets` push to the PUBLIC
genepool (genepool.eryph.io); a pushed tag cannot be removed.

## Versions

- Fodder genes: semantic versions in the tag package.json, managed with changesets (`npx changeset`).
- OS images: date tags (`20261014`).

# Eryph Core Concepts (eryph 0.5)

Concept reference for working in this repository. For commands (MCP tools, `egs-tool`, PowerShell
cmdlets used by scripts, build commands) see [tooling.md](tooling.md). For debugging provisioning see
[fodder-debugging.md](fodder-debugging.md), for error messages see [error-patterns.md](error-patterns.md).

## Terms

- **Catlet** - a Hyper-V VM defined by a YAML catlet specification.
- **Gene** - a reusable unit published in a geneset: a catlet gene, a fodder gene, or a volume gene.
- **Geneset** - a versioned family of genes, addressed as `org/geneset` (e.g. `dbosoft/ubuntu-24.04`).
- **Tag** - a version of a geneset: `org/geneset/tag`. Date tags for OS images (`20261014`), semantic
  tags for fodder (`2.0`), and moving tags such as `latest` and `starter`. An omitted tag means `latest`.
- **Genepool** - the gene repository. Public genes come from https://genepool.eryph.io; eryph-zero also
  keeps a local genepool (cache), which is where locally built genes are copied for testing.
- **Fodder** - provisioning configuration (cloud-config or scripts) that runs inside the guest.
- **Project** - catlets are deployed into a project (catlet `project` property or the deploy call).

eryph-zero runs as a Windows service on the Hyper-V host; the MCP server and the PowerShell cmdlets are
clients of it.

## Gene types

| Type | Content | Notes |
|---|---|---|
| Catlet gene | catlet YAML | Can have a `parent`, inline fodder and fodder references. |
| Fodder gene | YAML with `name`, optional `variables`, `fodder` list | No `parent`; composed into catlets via `source:`. |
| Volume gene | disk image (VHDX, packed) | Base OS disks; referenced by catlet genes (e.g. `gene:dbosoft/ubuntu-24.04/<date>:sda`). |

Only catlet genes inherit. Fodder genes are composed, not extended.

## Base and starter catlets

Base catlets (OS images) in this repo, e.g. `dbosoft/ubuntu-24.04`, `dbosoft/winsrv2022-standard`,
`dbosoft/winsrv2025-standard`, `dbosoft/win11-24h2-enterprise`, `dbosoft/almalinux-9`
(see `genes/dbosoft/` for the full list).

- `org/geneset` or `org/geneset/latest` - plain OS, no user configured.
- `org/geneset/starter` - `latest` plus `gene:dbosoft/starter-food:<linux-starter|win-starter>`.
  Validation expands `starter` to `starter-1.0`. Do not add starter-food again on a `/starter` parent.

Starter credentials (variables of `src/starter-food/default/fodder/*.yaml`):

| Fodder | Variables (defaults) |
|---|---|
| `linux-starter` | `username` (`admin`), `password` (`admin`, secret), `lockPassword` (`false`), `sshPublicKey` |
| `win-starter` | `AdminUsername` (`Admin`), `AdminPassword` (`InitialPassw0rd`, secret); also enables RDP |

## Provisioning inside the guest

| | Linux base catlets | Windows base catlets |
|---|---|---|
| Provisioning agent | cloud-init | eryph guest services (`egs-service`, service `eryph-guest-services`) |
| Remote access | guest services (package `eryph-guest-services`) | guest services (same service) |

Windows base catlets no longer contain cloudbase-init. Every base catlet ships guest services
(currently egs 0.7.0), so test catlets do not need any extra fodder for remote access.

### egs-service on Windows

- Accepts the full `#cloud-config` schema, multipart MIME and `#include`. There is no "only a few
  directives work" restriction anymore.
- Implemented modules, in run order: Growpart, SetHostname, ApplyNetworkConfig, NtpClient, Timezone,
  SetLocale, UsersGroups, SetPasswords, SshModule, WriteFiles, Runcmd, Licensing, WriteFilesDeferred,
  ScriptsUser, PowerState. Stages: Local, Network, Config, Final.
- Linux-only keys (`packages`, `apt`, `snap`, ...) are accepted and ignored (logged at Info): no package
  installation happens on Windows. Install software from a script.
- Not implemented on Windows: Jinja templating, part-handler, boothook execution, vendor-data merge,
  random passwords (always set an explicit password), `windows_update`, `winget`, `chocolatey`, `chef`,
  `dsc` modules, WinRM listener configuration.
- Script dispatch: by filename extension (`.ps1` -> PowerShell with `-ExecutionPolicy Bypass`,
  `.cmd`/`.bat` -> `cmd.exe /c`, `.sh` skipped), then shebang (`#ps1` / `#ps1_sysnative` -> PowerShell,
  `#!/...` skipped), then a shellscript with no other signal runs under PowerShell. Setting
  `filename: something.ps1` is the recommended explicit form, but not required.
- Exit codes: `1001` = reboot, then continue with the next script; `1003` = reboot and re-run the same
  script; `1002` is not supported. Any other non-zero exit is logged and the **next script still runs**.
- Frequencies: per-instance, per-boot, per-once.
- Logs and state: see [fodder-debugging.md](fodder-debugging.md)
  (`C:\ProgramData\eryph\provisioning\state.json`, per-script logs under
  `C:\ProgramData\eryph\provisioning\logs\`).

### cloud-init on Linux

Standard cloud-init semantics. A failing module or script can stop later parts, so a broken early
fodder entry can leave the catlet half-provisioned. Logs: `/var/log/cloud-init.log`,
`/var/log/cloud-init-output.log`, `cloud-init status --long`.

## Catlet specification

```yaml
name: my-vm                              # required
parent: dbosoft/ubuntu-24.04/starter     # no gene: prefix for parent
hostname: web01
cpu:
  count: 4
memory:
  startup: 4096
drives:
- name: sda
  size: 50
capabilities:
- name: nested_virtualization
fodder:
- name: setup
  type: cloud-config
  content:
    packages: [nginx]
```

- Top-level properties: `version`, `project`, `name`, `location`, `hostname`, `environment`, `store`,
  `parent`, `cpu`, `memory`, `drives`, `network_adapters`, `capabilities`, `networks`, `variables`,
  `fodder`.
- Unknown properties are rejected. Property names match case-insensitively (`filename`, `fileName`),
  but `file_name` is rejected.
- Mutations for inherited items (drives, adapters, capabilities, networks): `merge` (default),
  `overwrite`, `remove`.
- Inherited fodder is combined with the catlet's own fodder; a fodder entry can be removed with
  `remove: true`. The validated (expanded) configuration shows the effective result.

### Schema vs. eryph

`docs/catlet-schema-v1.0.json` is stricter than eryph. Example: it only allows cloud-config `content`
as an object, while eryph also accepts it as a string block. `validate_catlet` (or `Test-Catlet` in
scripts) is authoritative.

## Fodder

Fodder entry types: `cloud-config` (content as YAML object or string block) and `shellscript`
(content string, optional `filename`); the schema also lists other cloud-init part types. Entries can
be marked `secret: true`.

```yaml
fodder:
# Linux
- name: packages
  type: cloud-config
  content:
    packages: [nginx]
    runcmd:
    - systemctl enable --now nginx

# Windows
- name: iis
  type: shellscript
  filename: install-iis.ps1
  content: |
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
```

### Gene references

```yaml
- source: gene:dbosoft/winget:install           # gene:<org>/<geneset>:<fodder-name>, tag = latest
- source: gene:dbosoft/starter-food/2.0:win-starter   # explicit tag
```

The fodder name is mandatory: `gene:dbosoft/starter-food` fails with "The gene identifier is
malformed". `parent:` uses no `gene:` prefix; `source:` always does. Fodder names are the `name:` of
the fodder gene file (`src/<geneset>/<tag>/fodder/*.yaml`).

### Inline first, gene later

Develop fodder inline in a test catlet on a minimal parent, add one piece at a time, and verify each
step. Extract to a fodder gene (gene-maintainer agent) only once it works and is worth reusing.

## Variables

```yaml
variables:
- name: domain
  required: true
- name: enable_tls
  type: boolean
  value: false
- name: ssh_key
  secret: true

fodder:
- source: gene:dbosoft/starter-food:linux-starter
  variables:
  - name: sshPublicKey
    value: '{{ ssh_key }}'
```

- `variables` is always a **list of objects** (`name`, `type` = string|boolean|number, `value`,
  `required`, `secret`) - in catlets, fodder genes and on `source:` references. A key/value map is
  rejected.
- eryph only substitutes `{{ name }}`. Jinja control blocks (`{% if %}`) pass validation but are not
  evaluated by eryph, and egs on Windows does not implement Jinja either. Do not use them.
- `$var` in a `.yaml` file is literal text; PowerShell interpolation only happens when a script builds
  the YAML string itself.
- Values for required variables are passed at validate/deploy time (MCP `variables` argument; in
  PowerShell scripts `-Variables` plus `-SkipVariablesPrompt`).

## Genesets in this repo

- OS base catlets: `ubuntu-20.04` ... `ubuntu-26.04`, `almalinux-9`, `almalinux-10`, `oraclelinux-9`,
  `winsrv2022-standard`, `winsrv2025-standard`, `win10-*`/`win11-*-enterprise` (built from
  hyperv-boxes; more historic genesets exist under `genes/dbosoft/`).
- Fodder genesets (`src/`): `starter-food` (`linux-starter`, `win-starter`), `winconfig` (`enable-ssh`,
  `join-domain`, `rearm-eval`), `windomain` (`first-dc`), `winget` (`install`), `chocolatey`
  (`install`), `powershell` (`linux-install`, `win-install`), `guest-services` (`linux-install`,
  `win-install`; not needed on current base catlets), `hyperv` (`install`, `eryph-zero-latest`),
  `vscode` (`win-vscode`), `msvs` (`vs2022`), `vsts` (`agent-sp`), `windevdrive` (`configure`),
  `windsc` (`setup`).

Repository layout, package structure and build flow: see CLAUDE.md and the gene-maintainer agent.
Testing genes: [gene-testing.md](gene-testing.md) and `tests/README.md`.

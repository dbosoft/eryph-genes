# {{ manifest.short_description }}

A Windows 11 development environment for SAP BTP (CAP, UI5/Fiori) and ABAP, without Visual
Studio and without SAP GUI. It inherits everything of the
[Windows developer box](/b/dbosoft/windevbox) except Visual Studio.

## What's installed

From the Windows developer box:
- winget, Git, Node.js LTS, GitHub CLI (machine-wide)
- a trusted Dev Drive on `E:` (VHDX on C:) with package caches and a `\source` workspace
- Hyper-V, PowerShell 7, VS Code, system-wide Git configuration

SAP tools:
- VS Code extensions, installed for each user at first logon: SAP Fiori tools extension pack, SAP CDS language support, UI5 language assistant, REST Client, GitLens, PowerShell
- CAP (`cds`), UI5 CLI (`ui5`) and Cloud MTA Build Tool (`mbt`) globally for all users
- Cloud Foundry CLI v8 with the MultiApps plugin (`cf deploy`)
- SAP BTP CLI (`btp`), when the SAP Developer License is accepted (see below)
- Eclipse with the SAP ABAP Development Tools (ADT)

The catlet has 8 vCPUs, 16 GB memory and a 127 GB (dynamically expanding) system disk.

## Usage

The catlet does not include a user. Add starter-food, or your own fodder to create a user or
join a domain:

```yaml
name: my-sapdevbox
parent: {{ geneset }}/win11

fodder:
  - source: gene:dbosoft/starter-food:win-starter
```

### Variables

| Variable | Default | Description |
|---|---|---|
| `accept_sap_developer_license` | `false` | Accepts the [SAP Developer License](https://tools.hana.ondemand.com/developer-license-3_2.txt) and installs the SAP BTP CLI |
| `vscode_extensions` | SAP set (see above) | VS Code extensions installed for each user |
| `dev_tools` | `Git.Git,OpenJS.NodeJS.LTS,GitHub.cli` | winget packages installed machine-wide |
| `git_user_name`, `git_user_email` | empty | Git identity set for each user at first logon |
| `devdrive_size`, `devdrive_letter`, `devdrive_name` | `100`, `E`, empty | Dev Drive size, letter, or a dedicated eryph drive instead of the VHDX |

### Without Eclipse ADT

Remove the ADT fodder in your catlet:

```yaml
fodder:
  - source: gene:dbosoft/sapadt:install
    remove: true
```

## Important Note

The installation takes 15-25 minutes. To reuse the result, repack the catlet after the build
into a custom base catlet.

---

{{> food_versioning_major_minor }}

{{> footer }}

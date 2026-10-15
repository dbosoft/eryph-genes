# Windows Package Manager (winget)

This geneset provides fodder for installing Windows Package Manager (winget) on Windows systems. Winget is Microsoft's official command-line package manager for Windows 10 and later.

## Usage

Install winget:

```yaml
fodder:
  - source: gene:dbosoft/winget:install
```

Install winget and packages from the winget source, machine-wide:

```yaml
fodder:
  - source: gene:dbosoft/winget:install
    variables:
      - name: packages
        value: Git.Git,7zip.7zip
```

Use winget in your own fodder after `install`, through the wrapper it leaves on the machine:

```yaml
fodder:
  - source: gene:dbosoft/winget:install
  - name: install-tools
    type: shellscript
    filename: install-tools.ps1
    content: |
      & C:\ProgramData\eryph\winget\winget-system.ps1 install --id Microsoft.VisualStudioCode --exact `
          --source winget --scope machine --silent `
          --accept-source-agreements --accept-package-agreements --disable-interactivity
      exit $LASTEXITCODE
```

## Variables

| Name | Default | Description |
|---|---|---|
| `packages` | empty | winget package ids, comma separated, installed machine-wide after winget. A package that is already installed counts as success; any other failure fails the fodder. |

## winget as Local System

Fodder runs as Local System. The winget CLI does not run in that account out of the box: started
outside a package context it can't find its dependency DLLs. The wrapper
`C:\ProgramData\eryph\winget\winget-system.ps1` puts the dependency packages on the PATH and runs the
newest `winget.exe`; the `packages` variable uses it too.

As Local System, only these work:
- the `winget` source (not `msstore`)
- machine-scope installers (`--scope machine`); per-user packages would end up in the system profile

Microsoft documents only the `Microsoft.WinGet.Client` PowerShell module for the system context,
which requires PowerShell 7. This gene uses the CLI so that it doesn't depend on another gene.

## Supported Platforms

- Windows 10 1809 (build 17763) or later
- Windows 11
- Windows Server 2022 and later (winget officially supports Windows Server from 2025 on; 2022 works)

Windows Server 2019 is not supported: the current App Installer package cannot be provisioned there, and the fodder fails with a clear error.

Base catlets from the older image generation that still provision with cloudbase-init (for example `dbosoft/win10-20h2-enterprise/20250914`) are not supported either: their scripts run as the `cloudbase-init` user, who is not allowed to start winget from the WindowsApps folder.

## What it does

1. Checks the OS build (winget needs build 17763 or later)
2. Downloads the latest winget release from GitHub: the App Installer bundle, the dependency
   packages for the machine's architecture (VCLibs, Windows App Runtime) and the license
3. Provisions App Installer with `Add-AppxProvisionedPackage` for all users. Fodder runs as Local
   System, which `Add-AppxPackage` rejects, so winget is provisioned instead of installed for the
   current user. Every user gets winget at their next logon.
4. Writes the Local System wrapper and checks that winget runs with it
5. Installs the packages from the `packages` variable
6. Fails the provisioning step (exit code 1) when any step fails

Re-running updates the provisioned package to the latest release.

## Interactive use
### Manual winget Commands for Users

Once provisioned, users can run these winget commands interactively:

```powershell
# Search for packages
winget search <package-name>

# Install a package
winget install --id <package.id> --exact --silent

# List installed packages
winget list

# Upgrade packages
winget upgrade --all

# Show package information
winget show <package.id>
```

### Popular Package IDs for User Installation

- **Version Control**: `Git.Git`
- **Editors**: `Microsoft.VisualStudioCode`, `JetBrains.IntelliJIDEA.Community`
- **Languages**: `Python.Python.3.12`, `OpenJS.NodeJS.LTS`, `GoLang.Go`, `Microsoft.DotNet.SDK.8`
- **Containers**: `Docker.DockerDesktop`, `RedHat.Podman`
- **Cloud Tools**: `Microsoft.AzureCLI`, `Amazon.AWSCLI`, `Google.CloudSDK`
- **Databases**: `PostgreSQL.PostgreSQL`, `MongoDB.Server`, `Microsoft.SQLServerManagementStudio`
- **Utilities**: `Microsoft.PowerToys`, `7zip.7zip`, `WinSCP.WinSCP`

## Resources

- [Windows Package Manager Documentation](https://learn.microsoft.com/en-us/windows/package-manager/)
- [winget CLI Reference](https://learn.microsoft.com/en-us/windows/package-manager/winget/)
- [Browse Available Packages](https://winget.run/)
- [winget Package Manifest Repository](https://github.com/microsoft/winget-pkgs)

---

{{> food_versioning_major_minor }}

{{> footer }}
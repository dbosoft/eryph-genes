# Windows Package Manager (winget)

This geneset provides fodder for installing Windows Package Manager (winget) on Windows systems. Winget is Microsoft's official command-line package manager for Windows 10 and later.

## Usage

To install winget in your Windows catlets, add a gene reference:

```yaml
fodder:
  - source: gene:dbosoft/winget:install
```

## System Account Limitation

Winget is distributed as an AppX package through the Microsoft Store infrastructure. Due to Windows architecture constraints, AppX packages cannot be executed by the SYSTEM account. Since eryph fodder runs under the SYSTEM account during provisioning, winget commands will not function during VM provisioning.

For package installation during VM provisioning, use the Chocolatey geneset instead, which is fully compatible with the SYSTEM account. Winget remains useful for scenarios where users will interactively install software after provisioning or for creating developer workstation templates where winget will be used manually.

## Supported Platforms

- Windows 10 1809 (build 17763) or later
- Windows Server 2022 and later
- Windows 11

Windows Server 2019 is not supported: the current App Installer package cannot be provisioned there, and the fodder fails with a clear error.

## What it does

1. Checks the OS build (winget needs build 17763 or later)
2. Downloads the latest winget release from GitHub: the App Installer bundle, the dependency
   packages for the machine's architecture (VCLibs, Windows App Runtime) and the license
3. Provisions App Installer with `Add-AppxProvisionedPackage` for all users. Fodder runs as Local
   System, which `Add-AppxPackage` rejects, so winget is provisioned instead of installed for the
   current user. Every user gets winget at their next logon.
4. Fails the provisioning step (exit code 1) when App Installer is not provisioned afterwards

## Notes

- Dependencies and license always match the downloaded winget release
- Re-running updates the provisioned package to the latest release
## Post-Provisioning Usage

After winget is installed through this gene, it becomes available for users to install software interactively or through scripts running in user context. Due to the SYSTEM account limitation noted above, winget cannot be used in fodder for automated software installation during provisioning.

### Alternative: Using Chocolatey for Automated Installation

For automated software installation during VM provisioning, use Chocolatey:

```yaml
name: my-dev-environment
parent: dbosoft/win11-24h2-enterprise/starter

fodder:
  # Install Chocolatey package manager
  - source: gene:dbosoft/chocolatey:install
  
  # Install development tools via Chocolatey
  - name: install-dev-tools
    type: shellscript
    filename: install-tools.ps1
    content: |
      Write-Host "Installing development tools with Chocolatey..."
      
      # Install Git
      choco install git -y
      
      # Install Node.js LTS
      choco install nodejs-lts -y
      
      # Install Python
      choco install python3 -y
      
      # Install Docker Desktop
      choco install docker-desktop -y
      
      Write-Host "Development tools installation completed!"
```

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


# Versioning

This geneset contains only fodder genes and is versioned with a major-minor version scheme.  

There is no patch version - when a bug is fixed, a new minor version will be released.  
A new major version is released when a gene is removed from the geneset. 

The tag latest is updated with each released version. If you want to have a stable reference, don't use the latest tag, use a specific version tag. 

----

# Contributing

This geneset is maintained by dbosoft and is open for contributions.  

You can find the repository for this geneset on [github.com/dbosoft/eryph-genes](https://github.com/dbosoft/eryph-genes).  

  

# License

All public dbosoft genesets are licensed under the [MIT License](https://opensource.org/licenses/MIT).


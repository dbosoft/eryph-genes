# Windows Package Manager (winget)

This geneset provides fodder for installing Windows Package Manager (winget) on Windows systems. Winget is Microsoft's official command-line package manager for Windows 10 and later.

## Usage

To install winget in your Windows catlets, add a gene reference:

```yaml
fodder:
  - source: gene:dbosoft/winget:install
```

## System Account Limitation

Winget is distributed as an AppX package through the Microsoft Store infrastructure. Due to Windows architecture constraints, AppX packages cannot be executed by the SYSTEM account. Since eryph fodder runs under the SYSTEM account during cloudbase-init provisioning, winget commands will not function during VM provisioning.

For package installation during VM provisioning, use the Chocolatey geneset instead, which is fully compatible with the SYSTEM account. Winget remains useful for scenarios where users will interactively install software after provisioning or for creating developer workstation templates where winget will be used manually.

## Supported Platforms

- Windows 10 (build 16299 or later)
- Windows Server 2022 and later
- Windows 11

## What it does

The winget installation fodder performs the following steps:

1. **Checks existing installation** - Verifies if winget is already installed
2. **OS compatibility check** - Ensures Windows build 16299 or later
3. **Installs dependencies**:
   - Microsoft.UI.Xaml 2.8
   - Microsoft VCLibs 14.00
4. **Installs winget** - Downloads and installs the latest Microsoft.DesktopAppInstaller
5. **PATH configuration** - Updates system PATH to ensure winget is available globally

## Notes

- The installation process handles all required dependencies automatically
- winget will be available system-wide after installation
- The fodder uses PowerShell with proper error handling and logging
- Installation is idempotent - safe to run multiple times

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

{{> food_versioning_major_minor }}

{{> footer }}
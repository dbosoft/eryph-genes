# Chocolatey Package Manager

This geneset contains fodder for installing Chocolatey package manager on Windows systems.

## Usage

To install Chocolatey in your Windows catlets, add a gene reference:

```yaml
fodder:
  - source: gene:dbosoft/chocolatey:install
```

## Supported Platforms

- Windows 7 and later (with .NET Framework 4.0+)
- Windows Server 2008 R2 and later
- Windows 10/11
- Windows Server 2016 and later

## What it does

The Chocolatey installation fodder performs the following steps:

1. **Checks existing installation** - Verifies if Chocolatey is already installed
2. **Sets execution policy** - Temporarily bypasses PowerShell execution policy for installation
3. **Downloads and installs Chocolatey** - Uses the official installation script from chocolatey.org
4. **Handles .NET Framework dependencies** - Automatically reboots if .NET Framework update is required
5. **Verifies installation** - Confirms Chocolatey command is available and functional
6. **Environment variable refresh** - Updates PATH to ensure `choco` command is available

## Automatic Reboot Handling

This fodder includes intelligent reboot handling for .NET Framework dependencies:

- Detects when .NET Framework update requires a reboot
- Uses cloudbase-init exit code 1003 to request automatic reboot
- Continues installation seamlessly after reboot
- Creates temporary marker files to track installation state

## Notes

- The installation process handles all required dependencies automatically
- Chocolatey will be available system-wide after installation
- The fodder uses PowerShell with proper error handling and logging
- Installation is idempotent - safe to run multiple times
- Supports automatic reboots when .NET Framework updates are needed

## Using Chocolatey After Installation

Once Chocolatey is installed through this gene, you can use it in subsequent fodder to install applications.

### Example: Custom Fodder Using Chocolatey

Here's how to create custom fodder that depends on Chocolatey:

```yaml
name: my-dev-environment
parent: dbosoft/win11-24h2-enterprise/starter

fodder:
  # First, ensure Chocolatey is installed
  - source: gene:dbosoft/chocolatey:install
  
  # Then use Chocolatey to install applications
  - name: install-dev-tools
    type: shellscript
    filename: install-tools.ps1
    content: |
      Write-Host "Installing development tools with Chocolatey..."
      
      # Install Git
      choco install git --yes
      
      # Install Node.js
      choco install nodejs --yes
      
      # Install Python
      choco install python --yes
      
      # Install Docker Desktop
      choco install docker-desktop --yes
      
      # Install Visual Studio Code
      choco install vscode --yes
      
      Write-Host "Development tools installation completed!"
```

### Common Chocolatey Commands

```powershell
# Search for packages
choco search <package-name>

# Install a package
choco install <package-name> --yes

# List installed packages
choco list --local-only

# Upgrade packages
choco upgrade all --yes

# Show package information
choco info <package-name>

# Uninstall a package
choco uninstall <package-name> --yes
```

### Popular Chocolatey Packages for Development

- **Version Control**: `git`, `svn`, `mercurial`
- **Editors**: `vscode`, `notepadplusplus`, `atom`
- **Languages**: `python`, `nodejs`, `golang`, `dotnet-sdk`
- **Containers**: `docker-desktop`, `kubernetes-cli`
- **Cloud Tools**: `awscli`, `azure-cli`, `googlecloudsdk`
- **Databases**: `postgresql`, `mongodb`, `mysql`
- **Utilities**: `7zip`, `curl`, `wget`, `putty`, `winscp`

### Package Installation Options

```powershell
# Silent installation (recommended for automation)
choco install packagename --yes

# Install specific version
choco install packagename --version 1.2.3 --yes

# Install from specific source
choco install packagename --source https://chocolatey.org/api/v2/ --yes

# Force reinstall
choco install packagename --yes --force

# Install with parameters
choco install packagename --yes --params "'/NoDesktopIcon /NoStartMenuIcon'"
```

## Resources

- [Chocolatey Official Website](https://chocolatey.org/)
- [Chocolatey Documentation](https://docs.chocolatey.org/)
- [Browse Available Packages](https://community.chocolatey.org/packages)
- [Chocolatey CLI Reference](https://docs.chocolatey.org/en-us/choco/commands/)
- [Package Creation Guide](https://docs.chocolatey.org/en-us/create/create-packages)

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


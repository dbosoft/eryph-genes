# Visual Studio 2022 Installation for eryph

This directory contains a proof-of-concept for installing Visual Studio 2022 (Community, Professional, or Enterprise) in eryph catlets. It demonstrates eryph's capability to handle complex enterprise software installations with flexible configuration options.

## Overview

The solution provides:
- **Support for all editions** - Community, Professional, and Enterprise
- **Automated silent installation** of Visual Studio 2022
- **ISO support** for offline installations
- **Configurable workload and component selection** via eryph variables
- **Multiple language pack support**
- **Fallback to online installation** when no ISO is available
- **Proper reboot handling** with cloud-init integration
- **Resource allocation** based on VS requirements

## Files

- `test-vs-2022.yaml` - Main catlet configuration for deploying VS (all editions)
- `install-vs.ps1` - Standalone PowerShell script for testing/reference
- `README.md` - This documentation

## Requirements

- **Base Image**: Windows 10 20H2 Enterprise (`dbosoft/win10-20h2-enterprise/starter`)
- **CPU**: 8 cores (minimum 4, but 8 recommended for builds)
- **Memory**: 16 GB RAM (minimum 4 GB, but 16 GB recommended)
- **Disk**: 100 GB (VS requires 20-50 GB, plus workspace)

## Quick Start

### Basic Deployment (Community Edition)

Deploy with default settings (.NET Desktop + ASP.NET Web workloads):

```powershell
# Generate SSH key for remote access (use existing key if available)
ssh-keygen -t rsa -b 2048 -f "$env:TEMP\egs-key" -N '""'
$pubkey = Get-Content "$env:TEMP\egs-key.pub" -Raw

# Deploy the catlet
Get-Content test-vs-2022.yaml | New-Catlet -Variables @{
    egskey = $pubkey
} -SkipVariablesPrompt
```

### Professional Edition

Deploy Visual Studio Professional:

```powershell
Get-Content test-vs-2022.yaml | New-Catlet -Variables @{
    egskey = $pubkey
    vs_edition = "Professional"
    vs_workloads = "Microsoft.VisualStudio.Workload.Azure;Microsoft.VisualStudio.Workload.Data"
} -SkipVariablesPrompt
```

### Enterprise Edition with Custom Components

Deploy Visual Studio Enterprise with specific components:

```powershell
Get-Content test-vs-2022.yaml | New-Catlet -Variables @{
    egskey = $pubkey
    vs_edition = "Enterprise"
    vs_workloads = "Microsoft.VisualStudio.Workload.ManagedDesktop"
    vs_components = "Microsoft.VisualStudio.Component.Windows11SDK.22621;Microsoft.VisualStudio.Component.Git"
    vs_languages = "en-US;de-DE"
} -SkipVariablesPrompt
```

### Using an ISO

Deploy with a Visual Studio ISO for offline installation:

```powershell
Get-Content test-vs-2022.yaml | New-Catlet -Variables @{
    egskey = $pubkey
    vs_edition = "Enterprise"
    vs_iso_path = "\\server\share\vs_enterprise_2022.iso"
} -SkipVariablesPrompt
```

**Note**: Variables with default values (`vs_workloads`, `vs_install_path`, `include_recommended`) will use their defaults if not provided. The `egskey` variable is required for SSH access.

## Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `egskey` | string | *required* | SSH public key for remote access |
| `vs_edition` | string | Community | Edition to install (Community, Professional, Enterprise) |
| `vs_iso_path` | string | *empty* | Optional path to VS ISO file |
| `vs_workloads` | string | ManagedDesktop;NetWeb | Semicolon-separated workload IDs |
| `vs_components` | string | *empty* | Semicolon-separated component IDs |
| `vs_languages` | string | en-US | Semicolon-separated language codes |
| `vs_install_path` | string | C:\Program Files\Microsoft Visual Studio\2022\Community | Installation directory (auto-adjusts for edition) |
| `include_recommended` | boolean | true | Include recommended components for workloads |
| `include_optional` | boolean | false | Include optional components for workloads |

## Workloads vs Components

Visual Studio installer supports two levels of configuration:

- **Workloads**: High-level feature groups (what we use by default)
  - Example: `Microsoft.VisualStudio.Workload.ManagedDesktop` includes everything for .NET desktop development
  - Includes multiple related components automatically
  - Use `--includeRecommended` to add recommended components for each workload

- **Components**: Individual tools, SDKs, and libraries
  - Example: `Microsoft.VisualStudio.Component.Windows10SDK.19041` for a specific Windows SDK
  - More granular control but requires knowing exact dependencies
  - Can be mixed with workloads using multiple `--add` parameters

## Common Workload IDs

### Core Development
- `Microsoft.VisualStudio.Workload.ManagedDesktop` - .NET Desktop Development (WPF, WinForms, Console)
- `Microsoft.VisualStudio.Workload.NetWeb` - ASP.NET and Web Development
- `Microsoft.VisualStudio.Workload.Azure` - Azure Development
- `Microsoft.VisualStudio.Workload.NetCrossPlat` - .NET Multi-platform App UI Development (MAUI)
- `Microsoft.VisualStudio.Workload.NativeDesktop` - Desktop Development with C++
- `Microsoft.VisualStudio.Workload.Universal` - Universal Windows Platform Development

### Data & Science
- `Microsoft.VisualStudio.Workload.Data` - Data Storage and Processing (SQL Server, Azure Data Lake)
- `Microsoft.VisualStudio.Workload.DataScience` - Data Science and Analytical Applications
- `Microsoft.VisualStudio.Workload.Python` - Python Development
- `Microsoft.VisualStudio.Workload.Node` - Node.js Development

### Game Development
- `Microsoft.VisualStudio.Workload.ManagedGame` - Game Development with Unity
- `Microsoft.VisualStudio.Workload.NativeGame` - Game Development with C++ (DirectX, Unreal)

### Mobile & Cross-Platform
- `Microsoft.VisualStudio.Workload.NativeMobile` - Mobile Development with C++
- `Microsoft.VisualStudio.Workload.NetCrossPlat` - Mobile Development with .NET (MAUI)

### Other
- `Microsoft.VisualStudio.Workload.Office` - Office/SharePoint Development
- `Microsoft.VisualStudio.Workload.VisualStudioExtension` - Visual Studio Extension Development
- `Microsoft.VisualStudio.Workload.NativeCrossPlat` - Linux and Embedded Development with C++

## Common Component IDs (for fine-tuning)

### Windows SDKs
- `Microsoft.VisualStudio.Component.Windows10SDK.19041` - Windows 10 SDK (10.0.19041.0)
- `Microsoft.VisualStudio.Component.Windows10SDK.20348` - Windows 10 SDK (10.0.20348.0)
- `Microsoft.VisualStudio.Component.Windows11SDK.22000` - Windows 11 SDK (10.0.22000.0)
- `Microsoft.VisualStudio.Component.Windows11SDK.22621` - Windows 11 SDK (10.0.22621.0)

### .NET SDKs and Runtimes
- `Microsoft.NetCore.Component.SDK` - .NET SDK
- `Microsoft.NetCore.Component.Runtime.8.0` - .NET 8 Runtime
- `Microsoft.Net.Component.4.8.SDK` - .NET Framework 4.8 SDK
- `Microsoft.Net.Component.4.7.2.TargetingPack` - .NET Framework 4.7.2 Targeting Pack

### C++ Tools
- `Microsoft.VisualStudio.Component.VC.Tools.x86.x64` - MSVC v143 - VS 2022 C++ x64/x86 build tools
- `Microsoft.VisualStudio.Component.VC.CMake.Project` - C++ CMake tools for Windows
- `Microsoft.VisualStudio.Component.VC.ATL` - C++ ATL for latest v143 build tools

### Essential Tools
- `Microsoft.VisualStudio.Component.Git` - Git for Windows
- `Microsoft.VisualStudio.Component.NuGet` - NuGet Package Manager
- `Microsoft.VisualStudio.Component.SQL.LocalDB.Runtime` - SQL Server Express LocalDB

## Language Packs

Visual Studio supports multiple language packs that can be installed simultaneously:

### Common Language Codes
- `en-US` - English (United States) - Default
- `de-DE` - German
- `es-ES` - Spanish
- `fr-FR` - French
- `it-IT` - Italian
- `ja-JP` - Japanese
- `ko-KR` - Korean
- `pl-PL` - Polish
- `pt-BR` - Portuguese (Brazil)
- `ru-RU` - Russian
- `tr-TR` - Turkish
- `zh-CN` - Chinese (Simplified)
- `zh-TW` - Chinese (Traditional)
- `cs-CZ` - Czech

## Example: Custom Installation

### With Specific Components and Languages

```powershell
Get-Content test-vs-community.yaml | New-Catlet -Variables @{
    egskey = $pubkey
    # Workloads for base functionality
    vs_workloads = "Microsoft.VisualStudio.Workload.ManagedDesktop"
    # Add specific Windows SDK and Git
    vs_components = "Microsoft.VisualStudio.Component.Windows11SDK.22621;Microsoft.VisualStudio.Component.Git"
    # Install German and French language packs
    vs_languages = "en-US;de-DE;fr-FR"
    include_recommended = "true"
    include_optional = "false"
} -SkipVariablesPrompt
```

### Minimal Installation with Specific Components Only

```powershell
Get-Content test-vs-community.yaml | New-Catlet -Variables @{
    egskey = $pubkey
    vs_workloads = ""  # No workloads, only components
    vs_components = "Microsoft.VisualStudio.Component.VC.Tools.x86.x64;Microsoft.VisualStudio.Component.Windows11SDK.22621"
    include_recommended = "false"  # Don't include recommended when using specific components
} -SkipVariablesPrompt
```

For a complete and up-to-date list of all workload and component IDs, see: [Visual Studio Community Workload and Component IDs](https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-community?view=vs-2022)

## Installation Process

The installation follows this workflow:

1. **ISO Detection**
   - Checks user-provided ISO path (if specified)
   - Scans drives E:, F:, G:, H: for mounted ISOs (skips D: which contains cloud-init)
   - Falls back to downloading online bootstrapper

2. **Silent Installation**
   - Executes with `--quiet --wait --norestart` flags
   - Installs selected workloads with optional recommended components
   - Logs installation progress to temp directory

3. **Verification**
   - Confirms installation by checking for devenv.exe
   - Adds Visual Studio to system PATH
   - Reports installation status and any errors

## Monitoring Installation

Connect to the catlet via SSH to monitor progress:

```powershell
# Get catlet IP
$ip = Get-Catlet | Where-Object Name -eq "test-vs-community" | Get-CatletIp

# SSH into the catlet (default credentials: admin/admin)
ssh admin@$ip

# Check installation logs
Get-Content C:\Windows\Temp\VSInstallLogs\*.log -Tail 50
```

## Troubleshooting

### Installation Fails

1. **Check available disk space**
   ```powershell
   Get-PSDrive C | Select-Object Used,Free
   ```

2. **Review installation logs**
   ```powershell
   Get-ChildItem "$env:TEMP\dd_*.log" | Sort LastWriteTime -Desc | Select -First 1 | Get-Content -Tail 100
   ```

3. **Verify network connectivity** (for online installation)
   ```powershell
   Test-NetConnection aka.ms -Port 443
   ```

### ISO Not Detected

- Ensure ISO is mounted to drives E: through H: (D: is reserved for cloud-init)
- Verify ISO contains `vs_community.exe` or `vs_setup.exe` in root
- Check ISO path is accessible from the catlet

### Workload Not Installing

- Verify workload ID is correct (case-sensitive)
- Check if workload is available in Community edition
- Ensure sufficient disk space for selected workloads

## Reboot Handling

The installation script properly handles Visual Studio's reboot requirements using cloud-init exit codes:

### Exit Codes
- **Exit 0**: Installation completed successfully, no reboot needed
- **Exit 1001**: Installation completed but requires reboot (cloud-init will reboot and continue)
- **Exit 1003**: Installation needs to restart and retry (cloud-init will reboot and retry the script)

### Common Scenarios
1. **Simple workloads**: Usually complete without reboot
2. **Windows SDK components**: Often require reboot (exit 3010 → 1001)
3. **C++ tools**: May require mid-installation reboot (exit 1641 → 1003)
4. **Multiple language packs**: Might require reboot

### Monitoring Reboots
```powershell
# Check if catlet has rebooted
Get-Catlet | Where-Object Name -eq "test-vs-community" | Select-Object Name, Status, Uptime

# Check cloud-init logs after reboot
& "C:/Windows/System32/OpenSSH/ssh.exe" <catletId>.eryph.alt -C 'Get-Content "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log" -Tail 50'
```

## Performance Considerations

- Initial installation takes 30-60 minutes depending on:
  - Selected workloads (more workloads = longer installation)
  - Network speed (online installation)
  - Disk performance
  - Reboot requirements (adds 2-5 minutes per reboot)
- Using an ISO significantly reduces installation time
- Installing many components may trigger multiple reboots

## Licensing

### Edition Requirements
- **Community**: Free for individuals, open source, academic research, and small teams (up to 5 users)
- **Professional**: Requires valid license or subscription
- **Enterprise**: Requires valid license or subscription

### License Activation
After installation, you'll need to:
1. Sign in with a Microsoft account (Community)
2. Enter a product key or sign in with a subscription (Professional/Enterprise)

```powershell
# Check license status via SSH
& "C:/Windows/System32/OpenSSH/ssh.exe" <catletId>.eryph.alt -C 'powershell -Command "& ''C:\Program Files\Microsoft Visual Studio\2022\<Edition>\Common7\IDE\StorePID.exe'' /Product <ProductKey>"'
```

## Security Notes

- Default credentials are `admin/admin` (from starter parent)
- Configure SSH key authentication via `egskey` variable
- Consider changing default admin password after deployment
- Visual Studio telemetry can be disabled post-installation if required
- Product keys should be stored securely and not included in catlet YAML

## Extending This POC

This proof-of-concept can be extended to:

1. **Add Visual Studio Extensions**
   ```powershell
   # In fodder, after VS installation
   & "$InstallPath\Common7\IDE\VSIXInstaller.exe" /quiet /admin extension.vsix
   ```

2. **Configure Visual Studio Settings**
   ```powershell
   # Import settings file
   & "$InstallPath\Common7\IDE\devenv.exe" /ResetSettings settings.vssettings
   ```

3. **Install Additional Tools**
   - Add SQL Server Developer Edition
   - Install Docker Desktop for container development
   - Add Git and configure repositories

4. **Create Specialized Variants**
   - `test-vs-enterprise.yaml` for Enterprise edition
   - `test-vs-buildtools.yaml` for build agents
   - `test-vs-game-dev.yaml` with game development workloads

## References

- [Visual Studio Silent Installation](https://learn.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio)
- [Workload and Component IDs](https://learn.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-community)
- [Visual Studio System Requirements](https://learn.microsoft.com/en-us/visualstudio/releases/2022/system-requirements)
- [eryph Documentation](https://docs.eryph.io/)
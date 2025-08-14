# Visual Studio Code Gene

This geneset provides automated installation and configuration of Visual Studio Code with development extensions and optional Dev Drive integration for enhanced performance.

## Features

- **Automated Installation**: VS Code installation via Chocolatey package manager
- **System-Wide Configuration**: Settings and keybindings applied to all users
- **Extension Bootstrap**: Automatic extension installation on first launch
- **Dev Drive Integration**: Automatic detection and configuration of Dev Drives for optimal development performance
- **Reboot Handling**: Automatic handling of installation reboots via cloudbase-init

## Available Fodder

### `win-vscode`

Installs Visual Studio Code with development extensions and configures it for optimal development workflow.

## Variables

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `vscode_extensions` | `"ms-vscode.powershell,ms-python.python,ms-azuretools.vscode-docker"` | No | Comma-separated list of extensions to install |
| `vscode_settings_json` | Default development settings | No | JSON object with VS Code settings |
| `vscode_keybindings_json` | Default keybindings | No | JSON array with custom keybindings |
| `dev_drive_letter` | `""` (auto-detect) | No | Specific drive letter for Dev Drive, empty for auto-detection |

### Default Extensions

- **PowerShell** (`ms-vscode.powershell`) - PowerShell language support
- **Python** (`ms-python.python`) - Python development support  
- **Docker** (`ms-azuretools.vscode-docker`) - Docker container support

### Default Settings

```json
{
  "editor.fontSize": 14,
  "editor.tabSize": 2,
  "editor.wordWrap": "on",
  "terminal.integrated.fontSize": 13,
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 1000,
  "editor.formatOnSave": true,
  "editor.minimap.enabled": false
}
```

## Dev Drive Integration

When a Dev Drive is detected (automatically or via `dev_drive_letter`), the gene configures:

### Dev Drive Detection

1. **Explicit**: Set `dev_drive_letter` variable (e.g., `"E"`)
2. **Automatic**: Scans for:
   - Windows 11 Dev Drives (trusted developer volumes)
   - ReFS drives with "Dev" in the label
   - Skips system drives (C:, D:)

### Dev Drive Configuration

- **Extensions Directory**: `{DevDrive}:\vscode\extensions`
- **User Data**: `{DevDrive}:\vscode\user-data`
- **Workspace Storage**: `{DevDrive}:\vscode\workspace-storage`
- **Default Git Location**: `{DevDrive}:\source\repos`
- **Terminal Working Directory**: `{DevDrive}:\source`

### Performance Benefits

- ~25% faster file operations and builds
- Reduced antivirus scanning overhead
- Optimized for development workloads

## Usage Examples

### Basic Installation

```yaml
name: my-dev-machine
parent: dbosoft/winsrv2022-standard/starter

fodder:
  - source: gene:dbosoft/guest-services:win-install
    variables:
      - name: sshPublicKey
        value: '\{{ egskey }}'
  
  - source: gene:dbosoft/vscode:win-vscode
```

### Custom Extensions

```yaml
name: python-dev-machine
parent: dbosoft/winsrv2022-standard/starter

variables:
  - name: egskey
    secret: true

fodder:
  - source: gene:dbosoft/guest-services:win-install
    variables:
      - name: sshPublicKey
        value: '\{{ egskey }}'
  
  - source: gene:dbosoft/vscode:win-vscode
    variables:
      - name: vscode_extensions
        value: "ms-python.python,ms-python.pylint,ms-python.black-formatter,ms-vscode.vscode-json"
```

### With Dev Drive

```yaml
name: devdrive-vscode-machine
parent: dbosoft/winsrv2022-standard/starter

variables:
  - name: egskey
    secret: true

drives:
  - name: devdrive
    size: 100 GB

fodder:
  - source: gene:dbosoft/guest-services:win-install
    variables:
      - name: sshPublicKey
        value: '\{{ egskey }}'
  
  - source: gene:dbosoft/windevdrive:configure
    variables:
      - name: devdrive_name
        value: devdrive
      - name: devdrive_letter
        value: E
      - name: devdrive_label
        value: DevDrive
  
  - source: gene:dbosoft/vscode:win-vscode
    variables:
      - name: dev_drive_letter
        value: "E"
```

### Custom Settings

```yaml
name: custom-vscode-machine
parent: dbosoft/winsrv2022-standard/starter

variables:
  - name: egskey
    secret: true
  - name: my_vscode_settings
    value: |
      {
        "editor.fontSize": 16,
        "editor.theme": "dark",
        "workbench.colorTheme": "Dark+ (default dark)",
        "terminal.integrated.shell.windows": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe"
      }

fodder:
  - source: gene:dbosoft/guest-services:win-install
    variables:
      - name: sshPublicKey
        value: '\{{ egskey }}'
  
  - source: gene:dbosoft/vscode:win-vscode
    variables:
      - name: vscode_settings_json
        value: '\{{ my_vscode_settings }}'
```

## Post-Installation

### User Configuration

Each user should run the configuration script on first login:
```powershell
C:\ProgramData\configure-vscode-user.ps1
```

This script:
- Copies default settings and keybindings to user profile
- Shows Dev Drive configuration details (if applicable)
- Provides usage instructions

### Extension Installation

Extensions are installed automatically when users first launch VS Code through the bootstrap mechanism.

### Verification

To verify the installation:
```powershell
# Check VS Code installation
code --version

# Check extensions (after first launch)
code --list-extensions

# Check Dev Drive configuration (if applicable)
fsutil devdrv query E:
```

## Troubleshooting

### Installation Issues

- **Reboot Required**: The gene handles reboots automatically via cloudbase-init
- **Chocolatey Issues**: The gene will install Chocolatey if not present
- **Path Issues**: VS Code is automatically added to system PATH

### Dev Drive Issues

- **Not Detected**: Manually specify `dev_drive_letter` variable
- **Wrong Drive**: Check that the specified drive exists and is a fixed drive
- **Performance**: Ensure the drive is properly formatted as ReFS with Dev Drive flag

### Extension Issues

- **Download Failures**: Extensions download from VS Code Marketplace during bootstrap
- **Missing Extensions**: Check internet connectivity during installation
- **Manual Installation**: Extensions can be installed manually via VS Code UI

## Requirements

- **Windows Server 2022** or **Windows 10/11**
- **Internet Connection** for downloading VS Code and extensions
- **PowerShell 5.1** or later
- **Optional**: Dev Drive (Windows 11 22621+ for full Dev Drive support)

## Related Genes

- `dbosoft/windevdrive:configure` - Create and configure Dev Drives
- `dbosoft/guest-services:win-install` - SSH access via Eryph Guest Services
- `dbosoft/chocolatey` - Chocolatey package manager setup
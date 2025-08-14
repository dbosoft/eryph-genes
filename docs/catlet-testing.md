# Catlet Testing Best Practices

## Overview

This document provides essential guidelines for testing catlets and fodder in eryph environments. Proper testing ensures reliability across different Windows versions and configurations.

## Critical Testing Principles

### 1. Always Verify Actual Installation

**❌ WRONG:** Marking tests as complete based on script exit codes
```powershell
# Script reports: "Installation completed successfully!"
# Exit code: 0
# Assumption: Everything worked
```

**✅ CORRECT:** Verify the actual installation state
```powershell
# Check if software is actually installed
Test-Path "C:\Program Files\Microsoft VS Code\Code.exe"

# Verify functionality
& "C:\Program Files\Microsoft VS Code\Code.exe" --version

# Check services/processes are running
Get-Service | Where-Object Name -like "*vscode*"
```

### 2. Check the Correct Log Files

Cloudbase-init logs are located at:
- **Primary log:** `C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log`
- **Unattended log:** `C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init-unattend.log`

**NOT** at `C:\ProgramData\cloudbase-init\log\` (common mistake)

### 3. SSH Connection Methods

Use the correct SSH connection format:
```powershell
# Using Windows OpenSSH directly (most reliable)
"C:/Windows/System32/OpenSSH/ssh.exe" <catlet-id>.eryph.alt <command>

# Using catlet name
"C:/Windows/System32/OpenSSH/ssh.exe" <catlet-name>.eryph.alt <command>

# Always update SSH config after catlet creation
egs-tool.exe update-ssh-config
```

## Handling Reboot Requirements

### Cloudbase-init Exit Codes

Use special exit codes to handle reboots gracefully:

| Exit Code | Behavior |
|-----------|----------|
| **0** | Success, continue normally |
| **1001** | Reboot and DON'T run the script again |
| **1003** | Reboot and RUN the script again |
| **1002** | Don't reboot, but run script again next boot |

### Example: Handling .NET Framework Installation

```powershell
# Check for reboot markers
$rebootMarker = "C:\ProgramData\app-install-reboot.marker"
if (Test-Path $rebootMarker) {
    Write-Host "Post-reboot: Continuing installation..."
    Remove-Item $rebootMarker -Force
}

# Install software that may require .NET Framework
$output = Install-Software 2>&1 | Out-String

# Check if reboot is required
if ($output -match "reboot is required" -or $LASTEXITCODE -eq 3010) {
    Write-Host "Reboot required - requesting cloudbase-init reboot..."
    New-Item -Path $rebootMarker -ItemType File -Force | Out-Null
    exit 1003  # Reboot and run again
}
```

## Template-Based Testing Approach

### Benefits
- Single source of truth for fodder
- Easy multi-OS testing
- Consistent test scenarios

### Implementation
```yaml
# test-app-template.yaml
name: test-app-{{ os_variant }}
parent: {{ parent }}

variables:
- name: egskey
  secret: true

fodder:
  - name: install-app
    type: shellscript
    content: |
      # Your installation script
```

### Orchestration Script
```powershell
# test-all-os.ps1
$testMatrix = @(
    @{ Name = "win2019"; Parent = "dbosoft/winsrv2019-standard/starter" },
    @{ Name = "win10"; Parent = "dbosoft/win10-20h2-enterprise/starter" },
    @{ Name = "win11"; Parent = "dbosoft/win11-24h2-enterprise/starter" }
)

$template = Get-Content "test-app-template.yaml" -Raw
foreach ($test in $testMatrix) {
    $catletYaml = $template -replace '{{ os_variant }}', $test.Name
    $catletYaml = $catletYaml -replace '{{ parent }}', $test.Parent
    # Deploy and test...
}
```

## Common Testing Pitfalls

### 1. Package Manager Availability

**Windows Server 2019 (build 17763):**
- ❌ Winget NOT supported
- ✅ Use Chocolatey as fallback

**Windows 10 1709+ (build 16299+):**
- ✅ Winget can be installed
- ✅ Chocolatey as backup option

**Windows 11:**
- ✅ Winget pre-installed

### 2. Error Message Reliability

**Don't trust success messages blindly:**
```powershell
# Log shows:
"Chocolatey installation failed with exit code: 1"
"VS Code installation completed successfully!"  # WRONG!
```

Always verify the actual state after installation.

### 3. Path Environment Variables

After installing tools, refresh PATH:
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + 
            [System.Environment]::GetEnvironmentVariable("Path","User")
```

## Testing Checklist

### Pre-Deployment
- [ ] Check eryph-zero service is running: `Get-Service eryph-zero`
- [ ] Verify parent genes are available in genepool
- [ ] Ensure EGS key is configured: `egs-tool.exe get-ssh-key`

### Deployment
- [ ] Deploy catlet with proper variables and `-Verbose` flag
- [ ] **BE PATIENT** - Windows 10/11 deployments can take 10+ minutes
- [ ] Do NOT timeout New-Catlet commands prematurely
- [ ] Note the operation ID from verbose output
- [ ] Wait for cloud-init completion (check logs)
- [ ] Update SSH configuration: `egs-tool.exe update-ssh-config`

### Verification
- [ ] Check cloudbase-init logs for errors
- [ ] Verify software is actually installed (not just exit codes)
- [ ] Test functionality (run --version, check services, etc.)
- [ ] Document unexpected behaviors or errors

### Post-Testing
- [ ] Clean up test catlets if needed
- [ ] Document compatibility matrix
- [ ] Note any OS-specific workarounds required

## Debugging Commands

### Check Installation Logs
```powershell
# View last 100 lines of cloudbase-init log
Get-Content "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log" -Tail 100

# Search for errors
Select-String -Path "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log" `
              -Pattern "ERROR|Failed|Exception"
```

### Verify Installation
```powershell
# Check if executable exists
Test-Path "C:\Program Files\AppName\app.exe"

# Check registry entries
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | 
    Where-Object DisplayName -like "*AppName*"

# Check services
Get-Service | Where-Object Name -like "*app*"
```

### Manual Testing
When automated installation fails, test manually to understand the issue:
```powershell
# Connect to catlet
ssh <catlet-id>.eryph.alt

# Try installation manually
choco install vscode -y --no-progress

# Check specific error messages
$Error[0].Exception.Message
```

## Best Practices Summary

1. **Trust but Verify** - Always verify actual installation state
2. **Use Correct Paths** - Know where logs and configs are located
3. **Handle Reboots** - Use cloudbase-init exit codes properly
4. **Test Across OS Versions** - Different Windows versions have different capabilities
5. **Document Everything** - Record what worked and what didn't
6. **Check Dependencies** - Ensure prerequisites (.NET, VC++ redistributables) are met
7. **Use Template Approach** - Maintain consistency across test scenarios

## Related Documentation

- [eryph Commands via Claude](./eryph-commands-via-claude.md)
- [eryph Knowledge Base](./eryph-knowledge.md)
- [Cloudbase-init Documentation](https://cloudbase-init.readthedocs.io/)
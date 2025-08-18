# Eryph Command Reference

## FOR ERYPH-EXECUTOR AGENT ONLY

This document contains exact command templates for the eryph-executor agent.
Main Claude and other agents should NOT use this document directly.

## PowerShell Catlet Commands

### Creating Catlets
```powershell
# Standard creation (pipeline preferred)
powershell -Command "Get-Content catlet.yaml | New-Catlet"

# With variables (ALWAYS use -SkipVariablesPrompt)
powershell -Command "Get-Content catlet.yaml | New-Catlet -SkipVariablesPrompt"

# With verbose output (to capture VmId)
powershell -Command "Get-Content catlet.yaml | New-Catlet -Verbose"
```

### Managing Catlets
```powershell
# List all catlets
powershell -Command "Get-Catlet"

# Get specific catlet by ID (use ID from New-Catlet output)
powershell -Command "Get-Catlet -Id '<catlet-id>'"

# Start catlet (ALWAYS use -Force and -Id)
powershell -Command "Start-Catlet -Id '<catlet-id>' -Force"

# Stop catlet (ALWAYS use -Force and -Id)
powershell -Command "Stop-Catlet -Id '<catlet-id>' -Force"

# Remove catlet (ALWAYS use -Force and -Id)
powershell -Command "Remove-Catlet -Id '<catlet-id>' -Force"

# Get catlet IP by ID
powershell -Command "Get-CatletIp -Id '<catlet-id>'"
```

### Operations Management
```powershell
# Check operation status (for long-running tasks)
powershell -Command "Get-EryphOperation -Id <operation-id>"

# Check eryph service
powershell -Command "Get-Service eryph-zero"
```

## EGS (Eryph Guest Services) Commands

### Setup Sequence (EXACT ORDER)
```bash
# 1. Register VM (use VmId from New-Catlet output)
egs-tool add-ssh-config <VmId>

# 2. Update SSH configuration for all VMs
egs-tool update-ssh-config

# 3. Check if guest services ready
egs-tool get-status <VmId>
```

### File Operations
```bash
# Upload single file
egs-tool upload-file <VmId> <local-path> <remote-path>

# Download file
egs-tool download-file <VmId> <remote-path> <local-path>
```

## SSH Commands

### CRITICAL: Always Use Full Path
```bash
# CORRECT - Windows OpenSSH
C:/Windows/System32/OpenSSH/ssh.exe <VmId>.hyper-v.alt -C "command"
C:/Windows/System32/OpenSSH/ssh.exe <catlet-id>.eryph.alt -C "command"

# WRONG - Never use bare ssh
ssh <catlet-id>  # DON'T DO THIS!
```

### Windows VM Testing
```bash
# Check cloudbase-init logs
C:/Windows/System32/OpenSSH/ssh.exe <VmId>.hyper-v.alt -C "powershell Get-Content 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log' -Tail 20"

# Check Windows features
C:/Windows/System32/OpenSSH/ssh.exe <VmId>.hyper-v.alt -C "powershell Get-WindowsFeature Web-Server"

# Test port connectivity
C:/Windows/System32/OpenSSH/ssh.exe <VmId>.hyper-v.alt -C "powershell Test-NetConnection localhost -Port 8080"
```

### Linux VM Testing
```bash
# Check cloud-init status
C:/Windows/System32/OpenSSH/ssh.exe <VmId>.hyper-v.alt -C "sudo cloud-init status"

# View cloud-init logs
C:/Windows/System32/OpenSSH/ssh.exe <VmId>.hyper-v.alt -C "sudo tail -50 /var/log/cloud-init-output.log"

# Check installed packages
C:/Windows/System32/OpenSSH/ssh.exe <VmId>.hyper-v.alt -C "dpkg -l | grep nginx"

# Test service
C:/Windows/System32/OpenSSH/ssh.exe <VmId>.hyper-v.alt -C "curl -s http://localhost"
```

## Build Commands

### Gene Building
```bash
# Install dependencies
pnpm install

# Build all genes
turbo build

# Build specific gene
turbo build --filter=genename

# Get local genepool path (requires admin)
.\Resolve-GenepoolPath.ps1

# Copy to local genepool (NEVER use push_packed.ps1 for testing!)
xcopy /E /I /Y genes\genename\.packed\* <genepool-path>\genename
```

### Changeset Management
```bash
# Create changeset for versioning
npx changeset

# Version packages
npx changeset version

# Publish workflow
pnpm publish-genesets
```

## Error Patterns

### NullReferenceException
**Cause:** Missing required flag
**Fix:** Add `-SkipVariablesPrompt` to New-Catlet/Test-Catlet

### SSH Connection Failed
**Cause:** Wrong SSH path
**Fix:** Use `C:/Windows/System32/OpenSSH/ssh.exe`

### Gene Not Found
**Cause:** Not in local genepool
**Fix:** Build and copy with xcopy command

### Operation Timeout
**Note:** Operation continues on server
**Fix:** Monitor with `Get-EryphOperation -Id <id>`

## Required Flags Summary

### Commands that MUST use -Force:
- Start-Catlet
- Stop-Catlet
- Remove-Catlet
- Update-Catlet
- Remove-CatletGene
- Remove-EryphProject
- Remove-CatletDisk

### Commands that MUST use -SkipVariablesPrompt:
- New-Catlet (when YAML has variables)
- Test-Catlet (when YAML has variables)
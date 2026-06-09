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

### Setup Sequence
```bash
# 1. Register VM (use VmId from New-Catlet output). This writes the .hyper-v.alt SSH
#    alias and exchanges keys via Hyper-V KVP — there is NO separate update step.
egs-tool add-ssh-config <VmId>

# 2. Check if guest services ready
egs-tool get-status <VmId>
```

`egs-tool` is self-documenting — run `egs-tool --help` (or `egs-tool catlet --help`) for the full command set.

### File Operations
```bash
# Upload single file
egs-tool upload-file <VmId> <local-path> <remote-path>

# Download file
egs-tool download-file <VmId> <remote-path> <local-path>
```

## SSH Commands

Use a plain `ssh` — the egs-tool config routes the `.hyper-v.alt` alias through a ProxyCommand, so
no full OpenSSH path is needed.

```bash
ssh <VmId>.hyper-v.alt -C "command"
```

### Windows VM Testing
```bash
# Read a provisioning/service log
ssh <VmId>.hyper-v.alt -C "powershell Get-Content 'C:\path\to\log' -Tail 20"

# Check Windows features
ssh <VmId>.hyper-v.alt -C "powershell Get-WindowsFeature Web-Server"

# Test port connectivity
ssh <VmId>.hyper-v.alt -C "powershell Test-NetConnection localhost -Port 8080"
```

### Linux VM Testing
```bash
# Check cloud-init status
ssh <VmId>.hyper-v.alt -C "sudo cloud-init status"

# View cloud-init logs
ssh <VmId>.hyper-v.alt -C "sudo tail -50 /var/log/cloud-init-output.log"

# Check installed packages
ssh <VmId>.hyper-v.alt -C "dpkg -l | grep nginx"

# Test service
ssh <VmId>.hyper-v.alt -C "curl -s http://localhost"
```

### Off-host access (over eryph)
From a machine that is **not** the Hyper-V host, use the catlet tunnel (catlet ID, not VmId):
```bash
egs-tool catlet add-ssh-config <catlet-id> --add-key
ssh <catlet-id>.eryph.alt -C "command"
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
**Cause:** EGS not configured yet, or the guest agent isn't ready
**Fix:** Run `egs-tool add-ssh-config <VmId>`, confirm `egs-tool get-status <VmId>` returns "available", then `ssh <VmId>.hyper-v.alt`

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
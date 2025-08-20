# Debugging Catlet Deployment Issues

## Overview
This document provides a systematic approach for detecting and analyzing errors in deployed catlets using the multi-agent orchestration system, particularly focusing on configuration application failures through cloudbase-init/cloud-init.

## Error Detection Process Using Agent Orchestration

### Step 1: Verify Catlet Status
**Use eryph-powershell-executor agent:**
```
Operation: get-catlet
Parameters: catlet_id
Returns: Catlet details including Id, VmId, Name, Status
```

### Step 2: Establish SSH Access
**Use egs-executor agent:**
```
Operation: setup-egs
Parameters: vmid (use VmId from Step 1, NOT catlet ID!)
Returns: SSH configuration status

Operation: test-egs
Parameters: vmid
Returns: "available" if successful
```

### Step 3: Check Expected Configuration Results

#### Windows Catlets
1. **Verify expected directories/files exist:**
**Use egs-executor agent:**
```
Operation: run-ssh
Parameters: 
  vmid: <VmId>
  command: "powershell Test-Path 'C:\\ExpectedPath'"
Returns: True/False
```

2. **If missing, check cloudbase-init service status:**
**Use egs-executor agent:**
```
Operation: run-ssh
Parameters:
  vmid: <VmId>
  command: "powershell Get-Service cloudbase-init"
Returns: Service status
```
- Status "Stopped" = service ran and completed
- Status "Running" = still processing
- Service not found = cloudbase-init not installed

3. **Locate and examine cloudbase-init logs:**
**Use egs-executor agent:**
```
# Check if log exists
Operation: run-ssh
Parameters:
  vmid: <VmId>
  command: "powershell Test-Path 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\log\\cloudbase-init.log'"

# Read log tail for errors
Operation: run-ssh
Parameters:
  vmid: <VmId>
  command: "powershell Get-Content 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\log\\cloudbase-init.log' -Tail 50"
```

#### Linux Catlets
1. **Check cloud-init status:**
**Use egs-executor agent:**
```
Operation: run-ssh
Parameters:
  vmid: <VmId>
  command: "cloud-init status"
```

2. **Examine cloud-init logs:**
**Use egs-executor agent:**
```
Operation: run-ssh
Parameters:
  vmid: <VmId>
  command: "sudo cat /var/log/cloud-init.log | tail -50"

Operation: run-ssh
Parameters:
  vmid: <VmId>
  command: "sudo cat /var/log/cloud-init-output.log | tail -50"
```

## Common Error Patterns

### Cloudbase-Init Errors

#### Script Processing Errors
**Error:** `TypeError: join() argument must be str, bytes, or os.PathLike object, not 'NoneType'`
- **Cause:** Shellscript fodder filename missing
- **Solution:** Ensure shellscript fodder has a filename matching script type

#### Variable Substitution Errors
**Error:** `Variable 'xxx' not found`
- **Cause:** Referenced variable not defined in catlet YAML
- **Solution:** Add missing variable to variables section

## Automated Error Detection Tools

### Windows: CloudInit.Analyzers.psm1
Located at: `tests\base-catlet\windows\CloudInit.Analyzers.psm1`

**Usage via agent orchestration:**

1. **Upload the module to VM:**
**Use egs-executor agent:**
```
Operation: upload-file
Parameters:
  vmid: <VmId>
  local_path: "D:\Source\Repos\eryph\eryph-genes\tests\base-catlet\windows\CloudInit.Analyzers.psm1"
  remote_path: "C:\Temp\CloudInit.Analyzers.psm1"
```

2. **Run the analyzer:**
**Use egs-executor agent:**
```
Operation: run-ssh
Parameters:
  vmid: <VmId>
  command: "powershell -Command \"Import-Module C:\\Temp\\CloudInit.Analyzers.psm1; Get-Content 'C:\\Program Files\\Cloudbase Solutions\\Cloudbase-Init\\log\\cloudbase-init.log' | Get-CloudbaseInitUserDataError\""
```

**Function: Get-CloudbaseInitUserDataError**
- Requires piped log content as input
- Parses cloudbase-init logs for user data errors
- Extracts stderr output from fodder execution
- Note: May not catch all error types (e.g., Python exceptions in userdata processing)

## Quick Diagnostic Checklist

1. ✅ Catlet deployed successfully? (Check with `Get-Catlet`)
2. ✅ Catlet running? (Status should be "Running")
3. ✅ EGS available? (`egs-tool get-status $vmId` returns "available")
4. ✅ Expected files/directories created?
5. ✅ Configuration service (cloudbase-init/cloud-init) completed?
6. ✅ Any errors in configuration logs?
7. ✅ Variables properly substituted?

## Error Resolution Workflow

1. **Identify error type** from logs
2. **Return to eryph-specialist** if content/YAML error
3. **Fix system state** if resource/permission error
4. **Redeploy catlet** after fixing configuration
5. **Verify fix** by checking expected results

## Key Points

- **Always use VmId for SSH/EGS operations**, not catlet ID
- **Check logs immediately** when configuration doesn't apply
- **Cloudbase-init stops after completion** - "Stopped" status is normal
- **Log locations vary** between Windows and Linux
- **Use analyzer tools** when available for faster diagnosis
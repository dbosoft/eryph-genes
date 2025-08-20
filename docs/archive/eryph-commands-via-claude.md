# Running eryph Commands via Claude Code

## How to Execute eryph Commands

**You have the Bash tool. Use it EXACTLY like this to run eryph commands:**

```
Bash(command='powershell -Command "Get-Catlet"')
```

**NO MODULE IMPORT! NO SETUP! The commands just work. They're already installed with eryph-zero.**

## CRITICAL: EXECUTE COMMANDS DIRECTLY - DO NOT BUILD SCRIPTS!

**WRONG APPROACH (DO NOT DO THIS):**
- DO NOT create PowerShell script files
- DO NOT build complex scripts
- DO NOT write functions
- DO NOT plan script architecture

**CORRECT APPROACH (DO THIS):**
- Execute commands DIRECTLY one by one
- Use the Bash tool to run each command immediately
- Show output after each command
- React to results in real-time

**Example of CORRECT execution:**
```
1. Run: Bash(command='powershell -Command "Get-Catlet | Where-Object Name -eq \"test-iis\""')
2. See result
3. If exists, run: Bash(command='powershell -Command "Get-Catlet | Where-Object Name -eq \"test-iis\" | Remove-Catlet -Force"')
4. Continue with next command...
```

## PowerShell NullReferenceException - "Der Objektverweis wurde nicht auf eine Objektinstanz festgelegt"

**CRITICAL:** This error ALMOST ALWAYS means:
- **A PowerShell prompt occurred** that couldn't be answered in non-interactive mode
- **You forgot required flags:**
  - For `New-Catlet`: Missing `-SkipVariablesPrompt` when YAML has variables
  - For `Test-Catlet`: Missing `-SkipVariablesPrompt` when YAML has variables
  - For various commands: Missing `-Force` flag

**Solution:** ALWAYS use `-SkipVariablesPrompt` with New-Catlet/Test-Catlet when the YAML contains variables, and provide variables via `-Variables @{varname = $value}`

## Handling Long-Running Operations (CRITICAL!)

**Eryph is a client/server architecture. When commands timeout in the client, they CONTINUE running on the server!**

**When a command times out:**
1. The operation is STILL RUNNING on the server
2. Gene downloads WILL CONTINUE
3. Catlets WILL BE CREATED
4. You MUST monitor the operation using `Get-EryphOperation`

**Best Practice for Long Operations:**
```powershell
# Use -Verbose to capture operation ID
$result = New-Catlet -Verbose ...
# If timeout occurs, extract operation ID from verbose output
# Monitor with: Get-EryphOperation -Id <operation-id>
# Wait for Status to change from "Running" to "Completed"
```

**Common long-running operations:**
- Downloading large genes (Windows images can be 8-10GB)
- Creating catlets with new genes
- First-time gene pulls from genepool

## Non-Interactive Execution for PowerShell Cmdlets

**ONLY FOR POWERSHELL CMDLETS: Use the `-Force` parameter with eryph PowerShell commands that have confirmation prompts.** As an AI agent, you cannot respond to interactive PowerShell cmdlet prompts, so you must bypass them with `-Force`.

**IMPORTANT: This `-Force` rule ONLY applies to PowerShell cmdlets, NOT to genepool path resolution or other user interactions where you must STOP and ask the user!**

## Which PowerShell cmdlets support -Force parameter

```powershell
# Commands that SHOULD use -Force to avoid interactive prompts:
Get-Catlet | Where-Object Name -eq "vm-name" | Start-Catlet -Force  # USE -Force!
Get-Catlet | Where-Object Name -eq "vm-name" | Stop-Catlet -Force   # USE -Force!
Get-Catlet | Where-Object Name -eq "vm-name" | Remove-Catlet -Force # USE -Force!
Get-Catlet | Where-Object Name -eq "vm-name" | Update-Catlet -Config $spec -Force
Remove-CatletGene -Unused -Force
Remove-EryphProject "project-name" -Force
Remove-CatletDisk -Id "disk-id" -Force

# Commands that DON'T have -Force parameter:
Get-Content catlet.yaml -Raw | New-Catlet -Verbose  # NO -Force (doesn't exist)
Get-Catlet | Where-Object Name -eq "vm-name" | Get-CatletIp  # NO -Force (doesn't exist)

# BEST syntax for New-Catlet (use pipeline):
Get-Content catlet.yaml -Raw | New-Catlet -Verbose

# New EGS process (no variables needed!):
Get-Content catlet.yaml -Raw | New-Catlet -Verbose

# Alternative with -InputObject (less preferred):
New-Catlet -Verbose -InputObject (Get-Content catlet.yaml -Raw)

# IMPORTANT: New-Catlet can take LONG time, especially for Windows 10/11!
# - DO NOT timeout the command prematurely
# - Large OS images (Win10/11) can take 10+ minutes to download and deploy
# - Use -Verbose to see operation ID
# - If timeout occurs, check operation status with the operation ID
```

**Note: Catlet commands use `-Id` parameter or pipeline input, NOT `-Name`**

## Eryph Guest Services (EGS) - Complete Guide

### What is EGS?
Eryph Guest Services provides credential-free, network-independent SSH access to catlets. The new version eliminates SSH key injection - authentication is handled automatically through Hyper-V integration.

### EGS Tools Overview

```cmd
# egs-tool.exe commands:
egs-tool add-ssh-config <VmId>    # Register VM and copy host key via Hyper-V
egs-tool update-ssh-config        # Generate SSH config for all registered VMs
egs-tool get-status <VmId>        # Check if guest services are available
```

### Connection Details
- **SSH Client**: **⚠️ CRITICAL: MUST use `C:/Windows/System32/OpenSSH/ssh.exe` - NOT just `ssh`!**
- **Hostname Formats** (all work):
  - `<catlet-id>.eryph.alt` (using catlet ID)
  - `<catlet-name>.eryph.alt` (using catlet name)
  - `<catlet-name>.<project>.eryph.alt` (full name with project)
- **No variables needed**: Authentication handled automatically
- Works for both Linux AND Windows catlets
- Connects as SYSTEM user on Windows

### Complete EGS Deployment Workflow

```bash
# Step 1: Deploy catlet with EGS fodder (NO VARIABLES NEEDED!)
powershell -Command "Get-Content test-name.yaml -Raw | New-Catlet -Verbose"
# OUTPUT EXAMPLE:
# Id              : 84a85969-346b-47f6-8612-d78be9606673
# Name            : test-name
# VmId            : 2a2d0357-d565-4d86-b2c7-8c041a814362  <-- Note this!
# Project         : default (4b4a3fcf-b5ed-4a9a-ab6e-03852752095e)
# Status          : Stopped

# Step 2: Register VM with EGS (use the VmId from step 1)
egs-tool add-ssh-config 2a2d0357-d565-4d86-b2c7-8c041a814362
# OUTPUT: An SSH configuration for the virtual machine has been generated...

# Step 3: Generate SSH configuration for all registered VMs
egs-tool update-ssh-config
# OUTPUT: SSH configurations have been updated. You can connect to the catlets as follows:
# Shows table with catlet names and SSH commands

# Step 4: Start the catlet
powershell -Command "Get-Catlet -Name 'test-name' | Start-Catlet -Force"

# Step 5: Wait for EGS to be available (use VmId from step 1)
egs-tool get-status 2a2d0357-d565-4d86-b2c7-8c041a814362
# Keep checking until it returns "available" (not "unknown")

# Step 6: Connect via SSH (MUST use Windows OpenSSH!)
# ⚠️ CRITICAL: Use the full path to Windows SSH
# You can use any of these formats:
C:/Windows/System32/OpenSSH/ssh.exe <catlet-id>.eryph.alt -C hostname
C:/Windows/System32/OpenSSH/ssh.exe <VmId>.hyper-v.alt -C hostname

# For commands with spaces, use proper quoting:
C:/Windows/System32/OpenSSH/ssh.exe <catlet-id>.eryph.alt -C "ipconfig /all"
```

### Extracting IDs from Output

When you deploy a catlet, note these IDs from the output:
```
Id    : 84a85969-346b-47f6-8612-d78be9606673  <-- Catlet ID (for SSH)
VmId  : 2a2d0357-d565-4d86-b2c7-8c041a814362  <-- VM ID (for egs-tool)
```

- **VM ID**: Use with `egs-tool add-ssh-config` and `egs-tool get-status`
- **Catlet ID or Name**: Use for SSH connections

### Adding EGS to Your Catlet YAML

#### Linux Catlet with EGS
```yaml
name: test-linux
parent: dbosoft/ubuntu-22.04/latest

fodder:
  # Add guest services for SSH access (NO VARIABLES NEEDED!)
  - source: gene:dbosoft/guest-services:latest:linux-install
  
  # Your test fodder here
  - name: my-setup
    type: cloud-config
    content:
      packages:
        - nginx
```

#### Windows Catlet with EGS
```yaml
name: test-windows
parent: dbosoft/winsrv2022-standard/starter

fodder:
  # Add guest services for SSH access (NO VARIABLES NEEDED!)
  - source: gene:dbosoft/guest-services:latest:win-install
  
  # Your test fodder here
  - name: my-setup
    type: shellscript
    filename: setup.ps1
    content: |
      Install-WindowsFeature -Name Web-Server
```

### Verification Commands with EGS

#### Windows Verification
```bash
# ⚠️ CRITICAL: Always use full path to Windows SSH!
# Check cloudbase-init logs (use catlet name or ID)
C:/Windows/System32/OpenSSH/ssh.exe <catlet-id>.eryph.alt -C "powershell Get-Content 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log' -Tail 20"

# Verify Windows features
C:/Windows/System32/OpenSSH/ssh.exe <catlet-id>.eryph.alt -C "powershell Get-WindowsFeature Web-Server"

# Test service
C:/Windows/System32/OpenSSH/ssh.exe <catlet-id>.eryph.alt -C "powershell Test-NetConnection localhost -Port 8080"
```

#### Linux Verification
```bash
# ⚠️ CRITICAL: Always use full path to Windows SSH!
# Check cloud-init status (use catlet name or ID)
C:/Windows/System32/OpenSSH/ssh.exe <catlet-id>.eryph.alt -C "sudo cloud-init status"

# Check cloud-init logs
C:/Windows/System32/OpenSSH/ssh.exe <catlet-id>.eryph.alt -C "sudo tail -50 /var/log/cloud-init-output.log"

# Verify packages
C:/Windows/System32/OpenSSH/ssh.exe <catlet-id>.eryph.alt -C "dpkg -l | grep nginx"

# Test service
C:/Windows/System32/OpenSSH/ssh.exe <catlet-id>.eryph.alt -C "curl -s http://localhost"
```

### Troubleshooting EGS

**EGS not available after 3 minutes?**
- Check if guest-services gene was included in fodder
- Verify the VM is actually running: `Get-Catlet | Where-Object Name -eq 'test-name'`
- Check if VM has an IP: `Get-CatletIp`
- Ensure the parent image supports EGS
- Did you run both `egs-tool add-ssh-config <VmId>` AND `egs-tool update-ssh-config`?

**SSH connection fails?**
- **⚠️ Are you using the FULL PATH `C:/Windows/System32/OpenSSH/ssh.exe`?** This is the #1 issue!
- Did you run `egs-tool add-ssh-config <VmId>` for this specific VM?
- Did you run `egs-tool update-ssh-config` after adding the VM?
- Check the SSH formats shown by `egs-tool update-ssh-config` output
- Valid hostname formats: `<catlet-id>.eryph.alt`, `<catlet-name>.eryph.alt`, `<catlet-name>.<project>.eryph.alt`
- Git SSH or WSL SSH won't work - MUST use Windows OpenSSH!

**Wrong user context?**
- Windows: EGS connects as SYSTEM user
- Linux: EGS connects as the user configured in cloud-init (usually admin or ubuntu)

**Key Commands Reference:**
```bash
# Deploy catlet and note the VmId from output
powershell -Command "Get-Content test.yaml | New-Catlet"
# Example output: VmId : 2a2d0357-d565-4d86-b2c7-8c041a814362

# Register VM with EGS (use VmId from above)
egs-tool add-ssh-config 2a2d0357-d565-4d86-b2c7-8c041a814362

# Generate SSH config and see available hostnames
egs-tool update-ssh-config

# Check if available (use VmId)
egs-tool get-status 2a2d0357-d565-4d86-b2c7-8c041a814362

# Connect (MUST use full path! Can use catlet name or ID)
C:/Windows/System32/OpenSSH/ssh.exe <catlet-id>.eryph.alt -C hostname
```

## Common Command Patterns

### Clean Up Pattern
```powershell
Bash: powershell -Command "Get-Catlet | Where-Object Name -eq 'test-name' | Stop-Catlet -Force -ErrorAction SilentlyContinue"
Bash: powershell -Command "Get-Catlet | Where-Object Name -eq 'test-name' | Remove-Catlet -Force -ErrorAction SilentlyContinue"
```

### Deploy Pattern (use pipelines for cleaner code!)
```powershell
# Deploy catlet
Get-Content catlet.yaml -Raw | New-Catlet -Verbose

# Start catlet (with -Force!)
Get-Catlet | Where-Object Name -eq 'my-vm' | Start-Catlet -Force

# Get IP
Get-Catlet | Where-Object Name -eq 'my-vm' | Get-CatletIp

# Stop and remove
Get-Catlet | Where-Object Name -eq 'my-vm' | Stop-Catlet -Force
Get-Catlet | Where-Object Name -eq 'my-vm' | Remove-Catlet -Force
```

### Service Check Pattern
```powershell
# 1. Check service is running
powershell -Command "Get-Service eryph-zero"

# 2. Deploy the catlet using PIPELINE (cleaner syntax!)
powershell -Command "Get-Content test.yaml -Raw | New-Catlet -Verbose"

# 3. Wait for operation to complete (check Status field)
powershell -Command "Get-Catlet | Where-Object Name -eq 'test-vm'"

# 4. Start the catlet using PIPELINE with -Force
powershell -Command "Get-Catlet | Where-Object Name -eq 'test-vm' | Start-Catlet -Force"

# 5. Get IP address using PIPELINE (may take a moment after starting)
powershell -Command "Start-Sleep -Seconds 10; Get-Catlet | Where-Object Name -eq 'test-vm' | Get-CatletIp"
```

## Understanding Command Output

**Empty output from Get-Catlet**
- If Get-Catlet returns nothing, it simply means no VMs exist yet
- This is normal for a fresh eryph installation
- NOT an error - just no catlets to list

## Command Execution Errors

**Issue: "Access Denied" or permission errors**
```powershell
# Check if running as administrator
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
# If False, restart PowerShell as admin
```

**Issue: "Cannot find eryph commands"**
```powershell
# Check if eryph-zero is installed
Get-Service eryph-zero -ErrorAction SilentlyContinue
# If null, eryph-zero is not installed

# Check if service is running
(Get-Service eryph-zero).Status
# Should be "Running"
```

**Issue: Commands hang or timeout**
```powershell
# Check operations in progress
Get-EryphOperation
# May need to wait for operations to complete
```

## Test-Catlet: Validating Configuration Before Deployment

**Test-Catlet is a powerful PowerShell cmdlet that validates your catlet configuration WITHOUT creating a VM.**

### Why Use Test-Catlet?
1. **Validates syntax** - Catches YAML errors before deployment
2. **Checks gene resolution** - Ensures all referenced genes exist
3. **Tests variable substitution** - Verifies variables are properly defined
4. **Shows inheritance chain** - Displays full configuration after parent merging
5. **No resources used** - Doesn't create VM or consume resources

### Basic Usage
```powershell
# Test from file
Get-Content my-catlet.yaml | Test-Catlet

# Test with file path
Test-Catlet -Config "my-catlet.yaml"

# Test with inline YAML
Test-Catlet -InputObject @"
name: test-vm
parent: dbosoft/ubuntu-22.04/starter
cpu: 4
memory: 4096
"@
```

### Testing with Variables
```powershell
# Define variables for testing
$testVars = @{
    sshPublicKey = "ssh-rsa AAAAB3..."
    appName = "myapp"
    enableFeature = "true"
}

# Test with variables
Get-Content catlet.yaml | Test-Catlet -Variables $testVars -SkipVariablesPrompt

# Or with quick mode (skips some validations for speed)
Get-Content catlet.yaml | Test-Catlet -Quick
```

## SIMPLE WORKFLOW - JUST RUN THESE COMMANDS

**Examples:**

User: "List my VMs"
```
You: [Run] Bash: powershell -Command "Get-Catlet"
[Look at output]
[Tell user what you see]
```

User: "Create a VM"
```
[Then run] Bash: powershell -Command "$spec = Get-Content vm.yaml -Raw; New-Catlet -InputObject $spec -Verbose"
[Look at output]
[Tell user what happened]
```

**DO NOT:**
- Import any modules
- Look for modules
- Install anything
- Write complex scripts

**JUST DO:**
- Run the simple PowerShell commands directly
- They're already there
- No setup needed
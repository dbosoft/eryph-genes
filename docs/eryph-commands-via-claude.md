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

# With variables for EGS:
$egsKey = (egs-tool.exe get-ssh-key | Out-String) -replace "[\r\n]", ""
Get-Content catlet.yaml -Raw | New-Catlet -Verbose -Variables @{ egskey = $egsKey } -SkipVariablesPrompt

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
Eryph Guest Services provides credential-free, network-independent SSH access to catlets. This dramatically simplifies testing by eliminating complex credential management.

### One-Time EGS Setup

```cmd
# 1. Install egs-tool - usually already installed
# If not installed, get from: https://github.com/eryph-org/guest-services

# 2. Get the EGS SSH public key
egs-tool.exe get-ssh-key
# Copy this key - you'll use it in all test catlets

# 3. Update SSH config (run after creating/starting catlets)
egs-tool.exe update-ssh-config
```

### EGS Key Facts
- `egs-tool.exe` is a CMD tool, not PowerShell
- The SSH key has line breaks that need fixing when used in variables
- Update SSH config AFTER catlets are created/started
- Works for both Linux AND Windows catlets
- Connects as SYSTEM user on Windows

### Connection Details
- **Format**: `cmd /c ssh <catlet-id>.eryph.alt -C <command>`
- **CRITICAL**: Must use `cmd /c` for SSH commands!
- Always use `-C` flag for commands (not interactive shell)
- Use catlet ID, not VM ID for SSH connection
- The `.eryph.alt` domain is automatically configured by EGS

### Checking EGS Availability
```powershell
# IMPORTANT: Use VM-ID, not catlet ID!
$vmId = (Get-Catlet | Where-Object Name -eq 'test-name').VmId

# Poll until available
while ((egs-tool.exe get-status $vmId) -ne "available") {
    Write-Host "Waiting for guest services..."
    Start-Sleep -Seconds 5
}
```

### Complete EGS Deployment Workflow

```powershell
# Step 1: Get EGS SSH key and fix line break issue
# CRITICAL: This EXACT format is required - DO NOT modify!
# IMPORTANT: Remove ALL line breaks (the key type already has the space)
$egsKey = (egs-tool.exe get-ssh-key | Out-String) -replace "[\r\n]", ""

# Step 2: Deploy with variables (note -SkipVariablesPrompt)
Get-Content test-name.yaml -Raw | New-Catlet -Verbose -Variables @{ egskey = $egsKey } -SkipVariablesPrompt

# IMPORTANT for Bash/Claude users:
# Use this bash-safe command (no backticks needed!):
# powershell -Command '$egsKey = (egs-tool.exe get-ssh-key | Out-String) -replace "[\r\n]", ""; Get-Content test.yaml -Raw | New-Catlet -Verbose -Variables @{ egskey = $egsKey } -SkipVariablesPrompt'
# 
# KEY POINTS:
# - Use single quotes for the whole command to avoid bash interpretation
# - Use -replace "[\r\n]" instead of .Replace() to avoid backticks
# - Remove ALL line breaks (the key type already has the needed space)
# - The key should have only ONE space between type and data

# Step 3: Start catlet
Get-Catlet | Where-Object Name -eq 'test-name' | Start-Catlet -Force

# Step 4: Wait for EGS to be available (use VM-ID!)
$vmId = (Get-Catlet | Where-Object Name -eq 'test-name').VmId
while ((egs-tool.exe get-status $vmId) -ne "available") {
    Write-Host "Waiting for guest services..."
    Start-Sleep -Seconds 5
}
Write-Host "Guest services are available!"

# Step 5: Update SSH config after catlet is running
egs-tool.exe update-ssh-config

# Step 6: Connect via SSH (use catlet ID and Windows SSH!)
$catletId = (Get-Catlet | Where-Object Name -eq 'test-name').Id
# IMPORTANT: Use Windows SSH, not Git SSH or WSL SSH
$windowsSsh = "C:\Windows\System32\OpenSSH\ssh.exe"
& $windowsSsh "$catletId.eryph.alt" hostname
```

### Adding EGS to Your Catlet YAML

#### Linux Catlet with EGS
```yaml
name: test-linux
parent: dbosoft/ubuntu-22.04/latest

variables: 
- name: egskey
  secret: true

fodder:
  # Add guest services for SSH access
  - source: gene:dbosoft/guest-services:linux-install
    variables:
      - name: sshPublicKey
        value: '{{ egskey }}'
  
  # Your test fodder here
  - name: my-setup
    type: cloud-config
    content: |
      packages:
        - nginx
```

#### Windows Catlet with EGS
```yaml
name: test-windows
parent: dbosoft/winsrv2022-standard/starter

variables:
- name: egskey
  secret: true

fodder:
  # Add guest services for SSH access (note single quotes!)
  - source: gene:dbosoft/guest-services:win-install
    variables:
      - name: sshPublicKey
        value: '{{ egskey }}'
  
  # Your test fodder here
  - name: my-setup
    type: shellscript
    filename: setup.ps1
    content: |
      Install-WindowsFeature -Name Web-Server
```

### Verification Commands with EGS

#### Windows Verification
```powershell
$catletId = (Get-Catlet | Where-Object Name -eq 'test-name').Id

# Check cloudbase-init logs
cmd /c ssh "$catletId.eryph.alt" -C "powershell Get-Content 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log' -Tail 20"

# Verify Windows features
cmd /c ssh "$catletId.eryph.alt" -C "powershell Get-WindowsFeature Web-Server"

# Test service
cmd /c ssh "$catletId.eryph.alt" -C "powershell Test-NetConnection localhost -Port 8080"
```

#### Linux Verification
```powershell
$catletId = (Get-Catlet | Where-Object Name -eq 'test-name').Id

# Check cloud-init status
cmd /c ssh "$catletId.eryph.alt" -C "sudo cloud-init status"

# Check cloud-init logs
cmd /c ssh "$catletId.eryph.alt" -C "sudo tail -50 /var/log/cloud-init-output.log"

# Verify packages
cmd /c ssh "$catletId.eryph.alt" -C "dpkg -l | grep nginx"

# Test service
cmd /c ssh "$catletId.eryph.alt" -C "curl -s http://localhost"
```

### Troubleshooting EGS

**EGS not available after 3 minutes?**
- Check if guest-services gene was included in fodder
- Verify the VM is actually running: `Get-Catlet | Where-Object Name -eq 'test-name'`
- Check if VM has an IP: `Get-CatletIp`
- Ensure the parent image supports EGS

**SSH connection fails?**
- Did you run `egs-tool.exe update-ssh-config` after starting the catlet?
- Are you using the catlet ID (not VM ID) for SSH?
- Are you using Windows SSH (`C:\Windows\System32\OpenSSH\ssh.exe`)? Git SSH or WSL SSH won't resolve `.eryph.alt` domains!
- Is the `.eryph.alt` domain included?

**Wrong user context?**
- Windows: EGS connects as SYSTEM user
- Linux: EGS connects as the user configured in cloud-init (usually admin or ubuntu)

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
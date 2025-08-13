# eryph-genes Test Utilities

This directory contains connection helper scripts and modules for testing eryph catlets and genes. These are **connection helpers**, not automated test suites - they establish connectivity and then YOU verify the catlet manually.

## Scripts

### Test-LinuxCatlet.ps1

Deploys a Linux catlet and establishes SSH connectivity for manual testing.

**Features:**
- Automatically generates SSH key for authentication
- Injects SSH key via starter-food gene
- Waits for VM boot and tests connectivity
- Returns connection information for manual verification
- Keeps VM running by default (use `-Cleanup` to remove)

**Usage:**
```powershell
# Deploy with inline fodder
$spec = @"
name: test-nginx
parent: dbosoft/ubuntu-22.04/latest
fodder:
- name: install-nginx
  type: cloud-config
  content: |
    packages:
      - nginx
"@

$result = .\Test-LinuxCatlet.ps1 -CatletSpec $spec

# Use returned connection info
ssh -i $result.SSHKeyPath admin@$result.IPAddress
```

**Parameters:**
- `CatletSpec` - Path to YAML file or YAML content as string
- `TestName` - Name for the test catlet (default: linux-test)
- `WaitSeconds` - Time to wait for boot (default: 20 seconds)
- `Cleanup` - Remove VM after deployment (default: false)

### Test-WindowsCatlet.ps1

Deploys a Windows catlet and establishes PowerShell Remoting connectivity for manual testing.

**Features:**
- Sets up credentials automatically (no credential popups!)
- Ensures PowerShell Remoting is enabled via fodder
- Waits for VM boot and tests connectivity
- Returns connection information for manual verification
- Keeps VM running by default (use `-Cleanup` to remove)

**Usage:**
```powershell
# Deploy with inline fodder
$spec = @"
name: test-iis
parent: dbosoft/winsrv2022-standard/latest
fodder:
- source: gene:dbosoft/starter-food:win-starter
- name: install-iis
  type: powershell
  content: |
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
"@

$result = .\Test-WindowsCatlet.ps1 -CatletSpec $spec

# Create PS session with returned credentials
$session = New-PSSession `
    -ComputerName $result.IPAddress `
    -Credential $result.Credentials `
    -UseSSL -Authentication Basic `
    -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
```

**Parameters:**
- `CatletSpec` - Path to YAML file or YAML content as string
- `Credentials` - PSCredential object (default: admin/InitialPassw0rd)
- `TestName` - Name for the test catlet (default: windows-test)
- `WaitSeconds` - Time to wait for boot (default: 120 seconds)
- `Cleanup` - Remove VM after deployment (default: false)

## Modules

### Eryph.SSH.psm1

PowerShell module for SSH connectivity to Linux VMs.

**Functions:**
- `New-SSHKey` - Generates SSH key pair
- `Invoke-SSH` - Executes commands via SSH
- `Install-SSHClient` - Installs OpenSSH client on Windows

**Example:**
```powershell
Import-Module .\Eryph.SSH.psm1

# Generate SSH key
$publicKey = New-SSHKey -KeyFilePath "$env:TEMP\test-key" -Force

# Execute command via SSH
$result = Invoke-SSH `
    -Command "sudo cloud-init status" `
    -Hostname "192.168.1.100" `
    -Username "admin" `
    -KeyFilePath "$env:TEMP\test-key"
```

### Eryph.InvokeCommand.psm1

PowerShell module for Windows Remote Management (WinRM) connectivity.

**Functions:**
- `Invoke-CommandWinRM` - Executes commands via WinRM with retry logic

**Example:**
```powershell
Import-Module .\Eryph.InvokeCommand.psm1

# Execute command via WinRM
$cred = New-Object PSCredential("admin", (ConvertTo-SecureString "password" -AsPlainText -Force))
$result = Invoke-CommandWinRM `
    -ComputerName "192.168.1.100" `
    -Credentials $cred `
    -ScriptBlock { Get-Service } `
    -Retry `
    -TimeoutInSeconds 300
```

## Test Templates

### linux.yaml

Template for Linux catlet testing with SSH key variable injection.

```yaml
name: catlettest
parent: {{cut}}

variables:
  - name: sshKey
    required: true

fodder:
- source: gene:dbosoft/starter-food:linux-starter
  variables:
    - name: sshPublicKey
      value: "{{ sshKey }}"
```

### windows.yaml

Template for Windows catlet testing with remote access enabled.

```yaml
name: catlettest
parent: {{cut}}

fodder:
- source: gene:dbosoft/starter-food:win-starter

- name: RemoteAccess
  type: powershell
  content: |
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
    Enable-PSRemoting -Force
    Get-NetFirewallRule -name *ICMP4* | Set-NetFirewallRule -Enabled True -Profile Private
```

## Manual Verification Steps

After establishing connectivity with the helper scripts, perform these manual verification steps:

### For Linux VMs

1. **Check cloud-init status:**
   ```bash
   sudo cloud-init status
   ```

2. **View cloud-init logs:**
   ```bash
   sudo cat /var/log/cloud-init-output.log
   sudo grep -i error /var/log/cloud-init*.log
   ```

3. **Verify fodder execution:**
   - Check installed packages
   - Verify services are running
   - Check created files/directories

### For Windows VMs

1. **Check cloudbase-init logs:**
   ```powershell
   Get-Content "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log" -Tail 50
   ```

2. **Look for completion:**
   ```powershell
   Select-String -Path "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\*.log" `
                 -Pattern "execution finished|error|failed"
   ```

3. **Verify fodder execution:**
   - Check installed Windows features
   - Verify services are running
   - Check registry keys/files

## Cleanup

Always clean up test resources when done:

```powershell
# Stop and remove catlet
Get-Catlet | Where-Object Name -eq "test-name" | Stop-Catlet -Force
Get-Catlet | Where-Object Name -eq "test-name" | Remove-Catlet -Force

# Remove SSH keys (Linux)
Remove-Item "$env:TEMP\eryph-test*" -Force
```

## Troubleshooting

### Connection Timeout

If the helper scripts timeout after 3 minutes:
- Check if starter-food is included (provides credentials/SSH)
- Verify the parent image is valid
- Check if VM got an IP address: `Get-Catlet | Get-CatletIp`
- Verify eryph-zero service is running: `Get-Service eryph-zero`

### Fodder Not Executing

If fodder doesn't execute as expected:
- Check cloud-init/cloudbase-init logs for errors
- Try running fodder commands directly in the VM
- Verify fodder YAML syntax
- Check if required variables are provided

### PowerShell Remoting Issues

If you get credential popups or connection failures:
- Ensure you're using the helper scripts (they handle credentials properly)
- Verify WinRM is enabled in the fodder
- Check firewall rules allow WinRM traffic
- Use `-UseSSL` and proper session options

## Best Practices

1. **Always use helper scripts** for initial deployment and connectivity
2. **Keep VMs running** during development (don't use `-Cleanup`)
3. **Check logs first** when debugging issues
4. **Test fodder inline** before creating standalone genes
5. **Clean up resources** when done testing
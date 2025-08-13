<#
.SYNOPSIS
Deploys a Linux catlet and establishes SSH connectivity for testing

.DESCRIPTION
This script is a connection helper that:
- Deploys a Linux catlet with SSH key injection
- Waits for boot and gets IP address
- Tests basic SSH connectivity
- Returns connection information for manual testing

The actual verification (cloud-init logs, fodder execution, etc.) should be done manually.

.PARAMETER CatletSpec
Path to the catlet YAML specification file or the specification as a string

.PARAMETER TestName
Name for the test catlet (default: linux-test)

.PARAMETER WaitSeconds
Time to wait for VM to boot before testing (default: 20)

.PARAMETER Cleanup
Remove the test VM after deployment (default: false - VM stays running)

.EXAMPLE
.\Test-LinuxCatlet.ps1 -CatletSpec test-ubuntu.yaml

.EXAMPLE
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
# Use $result.SSHKeyPath and $result.IPAddress for manual testing
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$CatletSpec,
    
    [string]$TestName = "linux-test",
    
    [int]$WaitSeconds = 20,
    
    [switch]$Cleanup
)

$ErrorActionPreference = "Stop"

# Import SSH module
Import-Module "$PSScriptRoot\Eryph.SSH.psm1" -Force

Write-Host "=== Linux Catlet Connection Helper ===" -ForegroundColor Cyan

# Generate SSH key for testing
Write-Host "Generating SSH key for testing..." -ForegroundColor Yellow
$sshKeyPath = "$env:TEMP\eryph-test-$([Guid]::NewGuid())"
$publicKey = New-SSHKey -KeyFilePath $sshKeyPath -Force

# Prepare result object
$result = @{
    Success = $false
    CatletName = $TestName
    IPAddress = $null
    SSHKeyPath = $sshKeyPath
    Username = "admin"
    ConnectionCommand = $null
    Message = ""
}

try {
    # Prepare catlet specification
    Write-Host "Preparing catlet specification..." -ForegroundColor Yellow
    
    if (Test-Path $CatletSpec) {
        $specContent = Get-Content $CatletSpec -Raw
    } else {
        $specContent = $CatletSpec
    }
    
    # Parse YAML to check if SSH key variable is needed
    if ($specContent -match 'sshKey|sshPublicKey') {
        # Spec expects SSH key as variable
        $variables = @{sshKey = $publicKey}
    } else {
        # Need to inject SSH key into fodder
        Write-Host "Adding SSH key injection via starter-food..." -ForegroundColor Yellow
        $specContent = $specContent -replace '(fodder:)', @"
variables:
- name: testSSHKey
  required: true
  secret: true

`$1
- source: gene:dbosoft/starter-food:linux-starter
  variables:
  - name: sshPublicKey
    value: "{{ testSSHKey }}"
"@
        $variables = @{testSSHKey = $publicKey}
    }
    
    # Update catlet name
    $specContent = $specContent -replace 'name:\s*\S+', "name: $TestName"
    
    # Remove existing test VM if present
    $existingCatlet = Get-Catlet | Where-Object Name -eq $TestName
    if ($existingCatlet) {
        Write-Host "Removing existing test catlet..." -ForegroundColor Yellow
        $existingCatlet | Stop-Catlet -Force -ErrorAction SilentlyContinue
        $existingCatlet | Remove-Catlet -Force
        Start-Sleep -Seconds 5
    }
    
    # Deploy catlet
    Write-Host "Deploying catlet '$TestName'..." -ForegroundColor Yellow
    $catlet = $specContent | New-Catlet -Variables $variables -SkipVariablesPrompt
    
    if (-not $catlet) {
        throw "Failed to create catlet"
    }
    
    # Start the catlet
    Write-Host "Starting catlet..." -ForegroundColor Yellow
    $catlet | Start-Catlet -Force
    
    Write-Host "Waiting $WaitSeconds seconds for VM to boot..." -ForegroundColor Yellow
    Start-Sleep -Seconds $WaitSeconds
    
    # Get IP address
    Write-Host "Getting catlet IP address..." -ForegroundColor Yellow
    $ipInfo = $catlet | Get-CatletIp
    $ip = $ipInfo.IpAddress
    
    if (-not $ip) {
        throw "Could not get IP address for catlet"
    }
    
    $result.IPAddress = $ip
    
    # Test basic SSH connectivity
    Write-Host "Testing SSH connectivity to $ip..." -ForegroundColor Yellow
    
    $maxRetries = 5
    $retryCount = 0
    $connected = $false
    
    while ($retryCount -lt $maxRetries -and -not $connected) {
        try {
            $testResult = Invoke-SSH -Command "echo 'connected'" `
                -Hostname $ip `
                -Username "admin" `
                -KeyFilePath $sshKeyPath `
                -ErrorAction Stop
            
            if ($testResult -match "connected") {
                $connected = $true
            }
        }
        catch {
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Host "  Attempt $retryCount/$maxRetries failed, retrying..." -ForegroundColor Yellow
                Start-Sleep -Seconds 10
            }
        }
    }
    
    if ($connected) {
        $result.Success = $true
        $result.ConnectionCommand = "ssh -i `"$sshKeyPath`" admin@$ip"
        $result.Message = "SSH connection established successfully"
        
        Write-Host "`n=== Connection Established ===" -ForegroundColor Green
        Write-Host "Catlet Name: $TestName" -ForegroundColor Cyan
        Write-Host "IP Address: $ip" -ForegroundColor Cyan
        Write-Host "SSH Key: $sshKeyPath" -ForegroundColor Cyan
        Write-Host "Username: admin" -ForegroundColor Cyan
        Write-Host "`nConnect with:" -ForegroundColor Yellow
        Write-Host "  ssh -i `"$sshKeyPath`" admin@$ip" -ForegroundColor White
        Write-Host "`nOr use Invoke-SSH from PowerShell:" -ForegroundColor Yellow
        Write-Host "  Import-Module `"$PSScriptRoot\Eryph.SSH.psm1`"" -ForegroundColor White
        Write-Host "  Invoke-SSH -Command 'your-command' -Hostname $ip -Username admin -KeyFilePath `"$sshKeyPath`"" -ForegroundColor White
        
        Write-Host "`n=== Manual Verification Steps ===" -ForegroundColor Yellow
        Write-Host "1. Check cloud-init status:" -ForegroundColor White
        Write-Host "   sudo cloud-init status" -ForegroundColor Gray
        Write-Host "2. View cloud-init logs:" -ForegroundColor White
        Write-Host "   sudo cat /var/log/cloud-init-output.log" -ForegroundColor Gray
        Write-Host "3. Check for errors:" -ForegroundColor White
        Write-Host "   sudo grep -i error /var/log/cloud-init*.log" -ForegroundColor Gray
        Write-Host "4. Verify your fodder executed:" -ForegroundColor White
        Write-Host "   Check installed packages, services, files, etc." -ForegroundColor Gray
        
    } else {
        $result.Message = "Could not establish SSH connection after $maxRetries attempts"
        throw $result.Message
    }
    
} catch {
    Write-Error $_
    $result.Message = $_.Exception.Message
} finally {
    if ($Cleanup) {
        Write-Host "`nCleaning up..." -ForegroundColor Yellow
        
        $testCatlet = Get-Catlet | Where-Object Name -eq $TestName
        if ($testCatlet) {
            $testCatlet | Stop-Catlet -Force -ErrorAction SilentlyContinue
            $testCatlet | Remove-Catlet -Force -ErrorAction SilentlyContinue
        }
        
        if (Test-Path $sshKeyPath) {
            Remove-Item "$sshKeyPath*" -Force
        }
        
        Write-Host "Cleanup completed" -ForegroundColor Green
    } else {
        Write-Host "`n=== Resources Kept Running ===" -ForegroundColor Yellow
        Write-Host "VM '$TestName' is still running for manual testing" -ForegroundColor White
        Write-Host "SSH key kept at: $sshKeyPath" -ForegroundColor White
        Write-Host "`nTo clean up later:" -ForegroundColor Yellow
        Write-Host "  Get-Catlet | Where-Object Name -eq '$TestName' | Stop-Catlet -Force" -ForegroundColor Gray
        Write-Host "  Get-Catlet | Where-Object Name -eq '$TestName' | Remove-Catlet -Force" -ForegroundColor Gray
        Write-Host "  Remove-Item `"$sshKeyPath*`" -Force" -ForegroundColor Gray
    }
}

# Return the result object
return $result
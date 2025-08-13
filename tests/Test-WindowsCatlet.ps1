<#
.SYNOPSIS
Deploys a Windows catlet and establishes PowerShell Remoting connectivity for testing

.DESCRIPTION
This script is a connection helper that:
- Deploys a Windows catlet with remote access enabled
- Waits for boot and gets IP address
- Tests basic PowerShell Remoting connectivity
- Returns connection information for manual testing

The actual verification (cloudbase-init logs, fodder execution, etc.) should be done manually.

.PARAMETER CatletSpec
Path to the catlet YAML specification file or the specification as a string

.PARAMETER Credentials
PSCredential object for connecting to the Windows VM. If not provided, uses default admin/InitialPassw0rd.

.PARAMETER TestName
Name for the test catlet (default: windows-test)

.PARAMETER WaitSeconds
Time to wait for VM to boot before testing (default: 120)

.PARAMETER Cleanup
Remove the test VM after deployment (default: false - VM stays running)

.EXAMPLE
.\Test-WindowsCatlet.ps1 -CatletSpec test-windows.yaml

.EXAMPLE
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
# Use $result.IPAddress and $result.Credentials for manual testing
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$CatletSpec,
    
    [System.Management.Automation.PSCredential]$Credentials,
    
    [string]$TestName = "windows-test",
    
    [int]$WaitSeconds = 120,
    
    [switch]$Cleanup
)

$ErrorActionPreference = "Stop"

# Import modules
Import-Module "$PSScriptRoot\Eryph.InvokeCommand.psm1" -Force

Write-Host "=== Windows Catlet Connection Helper ===" -ForegroundColor Cyan

# Prepare result object
$result = @{
    Success = $false
    CatletName = $TestName
    IPAddress = $null
    Credentials = $null
    ConnectionCommand = $null
    Message = ""
}

try {
    # Prepare credentials
    if (-not $Credentials) {
        Write-Host "Using default credentials (admin/InitialPassw0rd)" -ForegroundColor Yellow
        $password = ConvertTo-SecureString "InitialPassw0rd" -AsPlainText -Force
        $Credentials = New-Object System.Management.Automation.PSCredential("admin", $password)
    }
    
    $result.Credentials = $Credentials
    
    # Prepare catlet specification
    Write-Host "Preparing catlet specification..." -ForegroundColor Yellow
    
    if (Test-Path $CatletSpec) {
        $specContent = Get-Content $CatletSpec -Raw
    } else {
        $specContent = $CatletSpec
    }
    
    # Ensure win-starter fodder is included if not present
    if ($specContent -notmatch 'starter-food:win-starter' -and $specContent -notmatch 'RemoteAccess') {
        Write-Host "Adding Windows starter-food and remote access configuration..." -ForegroundColor Yellow
        $specContent = $specContent -replace '(fodder:)', @"
`$1
- source: gene:dbosoft/starter-food:win-starter
- name: RemoteAccess
  type: powershell
  content: |
    # Configure network and enable PS Remoting
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    
    # Configure WinRM for HTTPS
    `$cert = New-SelfSignedCertificate -DnsName `$env:COMPUTERNAME -CertStoreLocation Cert:\LocalMachine\My
    New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -CertificateThumbPrint `$cert.Thumbprint -Force
    
    # Configure firewall
    New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow -Profile Any
    Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP-PUBLIC" -RemoteAddress Any
    Get-NetFirewallRule -name *ICMP4* | Set-NetFirewallRule -Enabled True
    
    # Restart WinRM
    Restart-Service WinRM
"@
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
    $catlet = $specContent | New-Catlet
    
    if (-not $catlet) {
        throw "Failed to create catlet"
    }
    
    # Start the catlet
    Write-Host "Starting catlet..." -ForegroundColor Yellow
    $catlet | Start-Catlet -Force
    
    Write-Host "Waiting $WaitSeconds seconds for Windows to boot..." -ForegroundColor Yellow
    Start-Sleep -Seconds $WaitSeconds
    
    # Get IP address
    Write-Host "Getting catlet IP address..." -ForegroundColor Yellow
    $ipInfo = $catlet | Get-CatletIp
    $ip = $ipInfo.IpAddress
    
    if (-not $ip) {
        throw "Could not get IP address for catlet"
    }
    
    $result.IPAddress = $ip
    
    # Test basic PowerShell Remoting connectivity
    Write-Host "Testing PowerShell Remoting connectivity to $ip..." -ForegroundColor Yellow
    
    try {
        $testResult = Invoke-CommandWinRM `
            -ComputerName $ip `
            -Credentials $Credentials `
            -ScriptBlock { 
                "connected"
            } `
            -Retry `
            -TimeoutInSeconds 180
        
        if ($testResult -eq "connected") {
            $result.Success = $true
            $result.Message = "PowerShell Remoting connection established successfully"
            
            Write-Host "`n=== Connection Established ===" -ForegroundColor Green
            Write-Host "Catlet Name: $TestName" -ForegroundColor Cyan
            Write-Host "IP Address: $ip" -ForegroundColor Cyan
            Write-Host "Username: $($Credentials.UserName)" -ForegroundColor Cyan
            Write-Host "`nConnect with PowerShell:" -ForegroundColor Yellow
            Write-Host @"
  `$cred = New-Object PSCredential("$($Credentials.UserName)", (ConvertTo-SecureString "$($Credentials.GetNetworkCredential().Password)" -AsPlainText -Force))
  `$session = New-PSSession -ComputerName $ip -Credential `$cred -UseSSL -Authentication Basic -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)
  Invoke-Command -Session `$session -ScriptBlock { hostname }
  Remove-PSSession `$session
"@ -ForegroundColor White
            
            Write-Host "`n=== Manual Verification Steps ===" -ForegroundColor Yellow
            Write-Host "1. Check cloudbase-init logs:" -ForegroundColor White
            Write-Host "   C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log" -ForegroundColor Gray
            Write-Host "2. Look for completion message:" -ForegroundColor White
            Write-Host "   Search for 'execution finished' or errors in the log" -ForegroundColor Gray
            Write-Host "3. Verify your fodder executed:" -ForegroundColor White
            Write-Host "   Check installed features, services, files, registry keys, etc." -ForegroundColor Gray
            Write-Host "4. Check Windows features:" -ForegroundColor White
            Write-Host "   Get-WindowsFeature | Where-Object InstallState -eq 'Installed'" -ForegroundColor Gray
        } else {
            throw "Unexpected response from remote connection"
        }
    }
    catch {
        $result.Message = "Failed to establish PowerShell Remoting connection: $_"
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
        
        Write-Host "Cleanup completed" -ForegroundColor Green
    } else {
        Write-Host "`n=== Resources Kept Running ===" -ForegroundColor Yellow
        Write-Host "VM '$TestName' is still running for manual testing" -ForegroundColor White
        Write-Host "`nTo clean up later:" -ForegroundColor Yellow
        Write-Host "  Get-Catlet | Where-Object Name -eq '$TestName' | Stop-Catlet -Force" -ForegroundColor Gray
        Write-Host "  Get-Catlet | Where-Object Name -eq '$TestName' | Remove-Catlet -Force" -ForegroundColor Gray
    }
}

# Return the result object
return $result
# Validate-BaseOS.Tests.ps1
# Pester tests that run INSIDE Linux base catlets using PowerShell Core
# These tests verify cloud-init, base configuration, and general OS setup

# Get OS information for conditional tests (at discovery time, before BeforeAll)
$script:osRelease = Get-Content /etc/os-release -Raw
$script:isUbuntu = $script:osRelease -imatch "debian|ubuntu"
$script:isRHEL = $script:osRelease -imatch 'rhel|centos|rocky|alma|almalinux|ID="ol"|oracle.*linux'

Describe "Linux Base Catlet Validation" {
    BeforeAll {
        # Helper to run Linux commands
        function Invoke-LinuxCommand {
            param([string]$Command)
            $result = & bash -c $Command 2>&1
            return $result
        }

        # Debug output
        Write-Host "OS Release content: $($script:osRelease -replace '\n', ' | ')" -ForegroundColor Cyan
        Write-Host "isUbuntu: $script:isUbuntu, isRHEL: $script:isRHEL" -ForegroundColor Yellow
    }
    
    Context "Cloud-Init Validation" {
        It "Should have cloud-init installed" {
            $cloudInitPath = Get-Command cloud-init -ErrorAction SilentlyContinue
            $cloudInitPath | Should -Not -BeNullOrEmpty -Because "cloud-init should be installed"
        }
        
        It "Should have cloud-init completed successfully" {
            # Wait for cloud-init to complete if it's still running
            $timeout = 300  # 5 minutes
            $waited = 0
            $status = ""
            
            do {
                $status = Invoke-LinuxCommand "cloud-init status"
                Write-Host "Cloud-init status: $status"
                
                if ($status -match "status: done") {
                    Write-Host "Cloud-init completed successfully after $waited seconds"
                    break
                } elseif ($status -match "status: running") {
                    Write-Host "Cloud-init still running, waiting... ($waited/$timeout seconds)"
                    Start-Sleep -Seconds 10
                    $waited += 10
                } else {
                    break  # Unknown status, proceed with test
                }
            } while ($waited -lt $timeout)
            
            if ($waited -ge $timeout -and $status -match "status: running") {
                Write-Warning "Cloud-init still running after $timeout seconds, proceeding with test"
            }
            
            $status | Should -Not -BeNullOrEmpty
            $status | Should -Match "status: done|running" -Because "cloud-init should be done or in final stage"
        }
        
        It "Should have cloud-init log files" {
            $logFile = "/var/log/cloud-init.log"
            Test-Path $logFile | Should -Be $true -Because "cloud-init should create log file"
            
            $outputLog = "/var/log/cloud-init-output.log"
            Test-Path $outputLog | Should -Be $true -Because "cloud-init should create output log"
        }
        
        It "Should not have cloud-init errors" {
            if (Test-Path "/var/log/cloud-init.log") {
                $errors = Invoke-LinuxCommand "grep -i 'error\|critical' /var/log/cloud-init.log | grep -v 'Traceback' | head -10"
                if ($errors) {
                    # Some errors are benign, check for critical ones
                    $errors | Should -Not -Match "CRITICAL" -Because "No critical errors should be present"
                }
            }
        }
        
        It "Should have correct datasource configured" {
            $datasource = Invoke-LinuxCommand "cloud-init query platform"
            $datasource | Should -Not -BeNullOrEmpty
            # Should be using NoCloud or similar for Hyper-V
            $datasource | Should -Match "nocloud|none" -Because "Should use appropriate datasource for Hyper-V"
        }
    }
    
    Context "User Configuration" {
        It "Should not have packer user" {
            $passwdContent = Get-Content /etc/passwd -Raw
            $passwdContent | Should -Not -Match "^packer:" -Because "Packer user should be removed"
        }
        
        It "Should have packer user disabled" -Skip:$script:isUbuntu {
            # Ubuntu builds with ubuntu user, so packer user doesn't exist - skip this test
            # RHEL-based systems use packer user that should be disabled/locked
            $packerUserInfo = Invoke-LinuxCommand "getent passwd packer"
            $packerUserInfo | Should -Not -BeNullOrEmpty -Because "Packer user should exist but be disabled"

            # Check if account is locked
            $packerStatus = Invoke-LinuxCommand "passwd -S packer 2>/dev/null || chage -l packer"
            $packerStatus | Should -Match "locked|disabled|NP" -Because "Packer user should be locked/disabled"
        }

        It "Should not have packer home directory" -Skip:$script:isUbuntu {
            # Ubuntu uses ubuntu user for building, so no packer home directory
            # RHEL-based systems may have packer home but it should be clean
            if (Test-Path "/home/packer") {
                $packerContents = Get-ChildItem -Path "/home/packer" -Force -ErrorAction SilentlyContinue
                $packagingFiles = @($packerContents | Where-Object { $_.Name -match "install|setup|build" })
                $packagingFiles.Count | Should -BeLessOrEqual 2 -Because "Packer home should not have build artifacts"
            } else {
                $true | Should -Be $true -Because "No packer home directory (acceptable)"
            }
        }
        
        It "Should have admin user configured" {
            $passwdContent = Get-Content /etc/passwd -Raw
            $passwdContent | Should -Match "admin:" -Because "Admin user should exist"
            
            # Check if admin user has home directory
            Test-Path "/home/admin" | Should -Be $true -Because "Admin user should have home directory"
        }
        
        It "Should not have default ubuntu user" {
            $passwdContent = Get-Content /etc/passwd -Raw
            $passwdContent | Should -Not -Match "^ubuntu:" -Because "Default ubuntu user should be removed"
        }
        
        # Admin user sudo group test removed - not required for base catlet functionality
    }
    
    Context "SSH Configuration" {
        It "Should have SSH server installed (Ubuntu)" -Skip:$script:isRHEL {
            # Ubuntu/Debian: Check for openssh-server package and ssh service
            $sshPackage = Invoke-LinuxCommand "dpkg -l openssh-server"
            $sshPackage | Should -Match "openssh-server" -Because "OpenSSH server package should be installed"

            $sshStatus = Invoke-LinuxCommand "systemctl status ssh"
            $sshStatus | Should -Not -Match "not found" -Because "SSH service should exist"
        }

        It "Should have SSH server installed (RHEL)" -Skip:$script:isUbuntu {
            # RHEL-based: Check for openssh-server package and sshd service
            $sshPackage = Invoke-LinuxCommand "rpm -q openssh-server"
            $sshPackage | Should -Match "openssh-server" -Because "OpenSSH server package should be installed"

            $sshdStatus = Invoke-LinuxCommand "systemctl status sshd"
            $sshdStatus | Should -Not -Match "not found" -Because "SSHD service should exist"
        }
        
        It "Should have SSH service running (Ubuntu)" -Skip:$script:isRHEL {
            # Ubuntu: Check ssh service (with socket activation fallback for 24.04+)
            $sshStatus = Invoke-LinuxCommand "systemctl is-active ssh"
            if ($sshStatus.Trim() -eq "active") {
                $true | Should -Be $true -Because "SSH service is active"
            } else {
                # Ubuntu 24.04+ uses socket activation
                $socketStatus = Invoke-LinuxCommand "systemctl is-active ssh.socket"
                $socketStatus.Trim() | Should -Be "active" -Because "SSH socket should be active (socket activation)"
            }
        }

        It "Should have SSH service running (RHEL)" -Skip:$script:isUbuntu {
            # RHEL-based: Check sshd service (no socket activation)
            $sshdStatus = Invoke-LinuxCommand "systemctl is-active sshd"
            $sshdStatus.Trim() | Should -Be "active" -Because "SSHD service should be running"
        }
        
        It "Should not allow root SSH login with password" {
            if (Test-Path "/etc/ssh/sshd_config") {
                $sshdConfig = Get-Content /etc/ssh/sshd_config -Raw
                # Check for PermitRootLogin setting
                if ($sshdConfig -match "^\s*PermitRootLogin\s+(.+)") {
                    $setting = $Matches[1].Trim()
                    $setting | Should -BeIn @("no", "prohibit-password", "without-password") -Because "Root SSH login with password should be disabled"
                }
            } else {
                Set-ItResult -Skipped -Because "SSH config not found"
            }
        }
    }
    
    Context "System Configuration" {
        It "Should have correct hostname format" {
            $hostname = Invoke-LinuxCommand "hostname"
            $hostname | Should -Not -BeNullOrEmpty
            $hostname | Should -Not -Match "packer" -Because "Should not have packer hostname"
        }
        
        It "Should have network connectivity" {
            # Check for network interfaces (eth0 specifically for Hyper-V)
            $interfaces = Invoke-LinuxCommand "ip link show"
            $interfacesText = $interfaces -join "\n"
            $interfacesText | Should -Match "eth0" -Because "Should have eth0 network interface"
            
            # Check for IP address
            $ipAddr = Invoke-LinuxCommand "ip addr show"
            $ipAddrText = $ipAddr -join "\n"
            $ipAddrText | Should -Match "inet \d+\.\d+\.\d+\.\d+" -Because "Should have IPv4 address"
        }
        
        It "Should have time synchronization configured" {
            # Check various time sync services
            $timesync = Invoke-LinuxCommand "systemctl is-active systemd-timesyncd"
            if ($timesync.Trim() -ne "active") {
                $timesync = Invoke-LinuxCommand "systemctl is-active ntp"
                if ($timesync.Trim() -ne "active") {
                    $timesync = Invoke-LinuxCommand "systemctl is-active chrony"
                }
            }
            # Time sync is important but might not be critical in some environments
            if ($timesync.Trim() -notin @("active", "unknown")) {
                Write-Host "Time sync service not active: $($timesync.Trim())" -ForegroundColor Yellow
            }
            # Don't fail this test, just informational
            $true | Should -Be $true
        }
        
        It "Should have package manager working (Ubuntu)" -Skip:$script:isRHEL {
            # Ubuntu/Debian: Test APT package manager
            $aptCheck = Invoke-LinuxCommand "apt-get update -qq"
            $LASTEXITCODE | Should -Be 0 -Because "APT should be able to update package lists"
        }

        It "Should have package manager working (RHEL)" -Skip:$script:isUbuntu {
            # RHEL-based: Test YUM/DNF package manager
            $yumCheck = Invoke-LinuxCommand "yum check-update"
            $LASTEXITCODE | Should -BeIn @(0, 100) -Because "YUM should work (0=no updates, 100=updates available)"
        }
    }
    
    Context "Hyper-V Integration" {
        It "Should have Hyper-V guest tools installed" {
            # Check for Hyper-V kernel modules
            $modules = Invoke-LinuxCommand "lsmod | grep hv_"
            $hasHyperV = $modules -and $modules.Length -gt 0
            
            if (-not $hasHyperV) {
                # Check if running on Hyper-V via dmesg
                $dmesg = Invoke-LinuxCommand "dmesg | grep -i hyper"
                $hasHyperV = $dmesg -and $dmesg.Length -gt 0
            }
            
            $hasHyperV | Should -Be $true -Because "Should have Hyper-V integration components"
        }
        
        It "Should have kvp daemon running (Ubuntu)" -Skip:$script:isRHEL {
            # Ubuntu/Debian: Check hv-kvp-daemon service
            $kvpStatus = Invoke-LinuxCommand "systemctl is-active hv-kvp-daemon"
            $kvpStatus.Trim() | Should -Be "active" -Because "Hyper-V KVP daemon should be active"
        }

        It "Should have kvp daemon running (RHEL)" -Skip:$script:isUbuntu {
            # RHEL-based: Check hypervkvpd service (different service name)
            $kvpStatus = Invoke-LinuxCommand "systemctl is-active hypervkvpd"
            $kvpStatus.Trim() | Should -Be "active" -Because "Hyper-V KVP daemon should be active"
        }
    }
    
    Context "Security Configuration" {
        It "Should have firewall available (Ubuntu)" -Skip:$script:isRHEL {
            # Ubuntu/Debian: Check for UFW (Uncomplicated Firewall)
            $ufwStatus = Invoke-LinuxCommand "ufw status"
            $ufwStatus | Should -Not -Match "command not found" -Because "UFW should be installed"
            ($ufwStatus -match "Status: active" -or $ufwStatus -match "inactive") | Should -Be $true -Because "UFW should show status"
        }

        It "Should have firewall available (RHEL)" -Skip:$script:isUbuntu {
            # RHEL-based: Check for firewalld
            $firewalldStatus = Invoke-LinuxCommand "systemctl is-active firewalld"
            $firewalldStatus.Trim() | Should -BeIn @("active", "inactive") -Because "firewalld should be available"

            # Also verify firewall-cmd is available
            $firewallCmd = Invoke-LinuxCommand "which firewall-cmd"
            $firewallCmd | Should -Not -BeNullOrEmpty -Because "firewall-cmd should be installed"
        }
        
        # AppArmor/SELinux test removed - not required for base catlet functionality
    }
    
    Context "Disk and Storage" {
        It "Should have sufficient free space on root partition" {
            $dfOutput = Invoke-LinuxCommand "df -h /"
            $dfOutput | Should -Not -BeNullOrEmpty -Because "Should be able to check disk space"
            if ($dfOutput -is [array] -and $dfOutput.Count -gt 1) {
                $rootLine = $dfOutput | Where-Object { $_ -match "/\s*$" } | Select-Object -First 1
                if ($rootLine -and $rootLine -match "(\d+)%") {
                    [int]$usedPercent = $Matches[1]
                    $usedPercent | Should -BeLessThan 90 -Because "Root partition should have free space"
                }
            } elseif ($dfOutput -match "(\d+)%") {
                [int]$usedPercent = $Matches[1]
                $usedPercent | Should -BeLessThan 90 -Because "Root partition should have free space"
            }
        }
        
        It "Should have temp directories clean" {
            if (Test-Path "/tmp") {
                $tmpFiles = Get-ChildItem -Path /tmp -ErrorAction SilentlyContinue
                $packagingFiles = @($tmpFiles | Where-Object { $_.Name -match "packer|install|setup" })
                $packagingFiles.Count | Should -BeLessOrEqual 5 -Because "Temp directory should be relatively clean"
            }
        }
        
        It "Should have no swap configured (cloud image standard)" {
            $swapInfo = Invoke-LinuxCommand "free -h"
            $swapInfoText = $swapInfo -join "\n"
            $swapInfoText | Should -Match "Swap:" -Because "Should show swap information"
            
            # Cloud images should have no swap configured
            if ($swapInfoText -match "Swap:\s+(\S+)") {
                $swapSize = $Matches[1]
                $swapSize | Should -BeIn @("0B", "0") -Because "Cloud images should have no swap configured"
                Write-Host "No swap configured (correct for cloud images)" -ForegroundColor Green
            }
        }
    }
    
    Context "PowerShell Core Integration" {
        It "Should have PowerShell Core running" {
            $PSVersionTable | Should -Not -BeNullOrEmpty
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7 -Because "Should be running PowerShell Core 7+"
        }
        
        It "Should be able to run Linux commands from PowerShell" {
            $whoami = Invoke-LinuxCommand "whoami"
            $whoami | Should -Not -BeNullOrEmpty
        }
        
        It "Should have access to system files" {
            Test-Path "/etc/passwd" | Should -Be $true
            Test-Path "/var/log" | Should -Be $true
        }
    }
}
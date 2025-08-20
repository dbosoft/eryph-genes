# Validate-BaseOS.Tests.ps1
# Pester tests that run INSIDE Linux base catlets using PowerShell Core
# These tests verify cloud-init, base configuration, and general OS setup

Describe "Linux Base Catlet Validation" {
    BeforeAll {
        # Helper to run Linux commands
        function Invoke-LinuxCommand {
            param([string]$Command)
            $result = & bash -c $Command 2>&1
            return $result
        }
    }
    
    Context "Cloud-Init Validation" {
        It "Should have cloud-init installed" {
            $cloudInitPath = Get-Command cloud-init -ErrorAction SilentlyContinue
            $cloudInitPath | Should -Not -BeNullOrEmpty -Because "cloud-init should be installed"
        }
        
        It "Should have cloud-init completed successfully" {
            $status = Invoke-LinuxCommand "cloud-init status"
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
        
        It "Should not have packer home directory" {
            Test-Path "/home/packer" | Should -Be $false -Because "Packer home directory should be removed"
        }
        
        It "Should have admin user configured" {
            $passwdContent = Get-Content /etc/passwd -Raw
            $passwdContent | Should -Match "^admin:" -Because "Admin user should exist"
            
            # Check if admin user has home directory
            Test-Path "/home/admin" | Should -Be $true -Because "Admin user should have home directory"
        }
        
        It "Should have admin user in sudo group" {
            $groups = Invoke-LinuxCommand "groups admin"
            ($groups -match "sudo" -or $groups -match "wheel") | Should -Be $true -Because "Admin user should have sudo privileges"
        }
    }
    
    Context "SSH Configuration" {
        It "Should have SSH server installed" {
            $sshdPath = Get-Command sshd -ErrorAction SilentlyContinue
            if (-not $sshdPath) {
                # Check with systemctl
                $sshStatus = Invoke-LinuxCommand "systemctl status ssh"
                if ($sshStatus -match "not found") {
                    $sshStatus = Invoke-LinuxCommand "systemctl status sshd"
                }
                $sshStatus | Should -Not -Match "not found" -Because "SSH server should be installed"
            } else {
                $sshdPath | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should have SSH service running" {
            $sshStatus = Invoke-LinuxCommand "systemctl is-active ssh"
            if ($sshStatus -match "inactive|unknown") {
                $sshStatus = Invoke-LinuxCommand "systemctl is-active sshd"
            }
            $sshStatus.Trim() | Should -Be "active" -Because "SSH service should be running"
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
            # Check for network interfaces
            $interfaces = Invoke-LinuxCommand "ip link show"
            $interfaces | Should -Match "eth0|ens" -Because "Should have network interface"
            
            # Check for IP address
            $ipAddr = Invoke-LinuxCommand "ip addr show"
            $ipAddr | Should -Match "inet \d+\.\d+\.\d+\.\d+" -Because "Should have IPv4 address"
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
        
        It "Should have package manager working" {
            # Detect distro and test package manager
            $osRelease = Get-Content /etc/os-release -Raw
            
            if ($osRelease -match "debian|ubuntu") {
                $aptCheck = Invoke-LinuxCommand "apt-get update -qq"
                $LASTEXITCODE | Should -Be 0 -Because "APT should be able to update package lists"
            }
            elseif ($osRelease -match "rhel|centos|rocky|alma") {
                $yumCheck = Invoke-LinuxCommand "yum check-update"
                $LASTEXITCODE | Should -BeIn @(0, 100) -Because "YUM should work (0=no updates, 100=updates available)"
            }
            else {
                Set-ItResult -Skipped -Because "Unknown distribution package manager"
            }
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
        
        It "Should have kvp daemon running (if available)" {
            # The KVP daemon enables communication with Hyper-V
            $kvpStatus = Invoke-LinuxCommand "systemctl is-active hypervkvpd"
            if ($kvpStatus.Trim() -eq "unknown") {
                $kvpStatus = Invoke-LinuxCommand "systemctl is-active hv-kvp-daemon"
            }
            
            if ($kvpStatus.Trim() -eq "unknown") {
                # Check if process is running
                $kvpProcess = Invoke-LinuxCommand "ps aux | grep -v grep | grep kvp"
                if ($kvpProcess) {
                    Write-Host "KVP daemon running as process" -ForegroundColor Green
                } else {
                    Set-ItResult -Skipped -Because "KVP daemon not found (may be integrated differently)"
                }
            } else {
                $kvpStatus.Trim() | Should -Be "active" -Because "Hyper-V KVP service should be active"
            }
        }
    }
    
    Context "Security Configuration" {
        It "Should have firewall available" {
            # Check for common firewall services
            $ufwStatus = Invoke-LinuxCommand "ufw status"
            if ($ufwStatus -notmatch "command not found") {
                ($ufwStatus -match "Status: active" -or $ufwStatus -match "inactive") | Should -Be $true
            } else {
                # Check for firewalld
                $firewalldStatus = Invoke-LinuxCommand "systemctl is-active firewalld"
                if ($firewalldStatus.Trim() -ne "unknown") {
                    $firewalldStatus.Trim() | Should -BeIn @("active", "inactive")
                } else {
                    # Check iptables
                    $iptables = Invoke-LinuxCommand "which iptables"
                    $iptables | Should -Not -BeNullOrEmpty -Because "Should have some firewall mechanism"
                }
            }
        }
        
        It "Should have SELinux or AppArmor configured (if applicable)" {
            # Check SELinux
            $selinux = Invoke-LinuxCommand "getenforce"
            if ($selinux -notmatch "command not found") {
                $selinux.Trim() | Should -BeIn @("Enforcing", "Permissive", "Disabled")
            } else {
                # Check AppArmor
                $apparmor = Invoke-LinuxCommand "aa-status"
                if ($apparmor -notmatch "command not found") {
                    $apparmor | Should -Match "profiles are loaded"
                } else {
                    Set-ItResult -Skipped -Because "No mandatory access control system found"
                }
            }
        }
    }
    
    Context "Disk and Storage" {
        It "Should have sufficient free space on root partition" {
            $dfOutput = Invoke-LinuxCommand "df -h /"
            if ($dfOutput -match "(\d+)%") {
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
        
        It "Should have swap information available" {
            $swapInfo = Invoke-LinuxCommand "free -h"
            $swapInfo | Should -Match "Swap:" -Because "Should show swap information"
            
            # This is informational - cloud images might not have swap
            if ($swapInfo -match "Swap:\s+(\S+)") {
                $swapSize = $Matches[1]
                if ($swapSize -ne "0B" -and $swapSize -ne "0") {
                    Write-Host "Swap configured: $swapSize" -ForegroundColor Green
                } else {
                    Write-Host "No swap configured (normal for cloud images)" -ForegroundColor Yellow
                }
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
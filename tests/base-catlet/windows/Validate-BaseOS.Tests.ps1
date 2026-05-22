# Validate-BaseOS.Tests.ps1
# Pester tests that run INSIDE Windows base catlets to validate the base OS image.
# Verify sysprep, eryph guest services (egs-service — the cloudbase-init
# replacement, see eryph/guest-services), and general OS configuration.

Describe "Windows Base Catlet Validation" {
    
    Context "Sysprep Validation" {
        It "Should have sysprep log file" {
            $sysprepLogPath = "C:\Windows\Temp\sysprep.log"
            Test-Path $sysprepLogPath | Should -Be $true -Because "Sysprep should create a log file"
        }
        
        It "Should have completed sysprep successfully" {
            $sysprepLogPath = "C:\Windows\Temp\sysprep.log"
            if (Test-Path $sysprepLogPath) {
                $sysprepLog = Get-Content $sysprepLogPath -Raw
                $sysprepLog | Should -Not -BeNullOrEmpty
                $sysprepLog | Should -Match "CHECKPOINT_04: Shutdown" -Because "Sysprep should reach shutdown checkpoint"
                $sysprepLog | Should -Not -Match "ERROR|FAILED" -Because "Sysprep should complete without errors"
            } else {
                Set-ItResult -Skipped -Because "Sysprep log not found"
            }
        }
        
        It "Should not have packer user account" {
            $packerUser = Get-LocalUser -Name packer -ErrorAction SilentlyContinue
            $packerUser | Should -BeNullOrEmpty -Because "Packer user should be removed during image preparation"
        }
        
        It "Should not have packer user profile" {
            $packerProfile = "C:\Users\packer"
            Test-Path $packerProfile | Should -Be $false -Because "Packer user profile should be cleaned up"
        }
    }
    
    Context "Eryph Guest Services Validation" {
        # eryph/guest-services ships egs-service as the cloudbase-init
        # replacement on Windows catlets. Provisioning runs at first boot;
        # state.json + per-script logs only appear on a deployed catlet
        # (those checks belong in Test-PackedBaseCatlet.Tests.ps1).
        # At base-OS validation time we verify the install, the service,
        # and that the Application event log is clean.

        It "Should have egs-service installed" {
            Test-Path "C:\Program Files\eryph\guest-services\bin\egs-service.exe" |
                Should -Be $true -Because "egs-service is the base-catlet provisioning agent"
        }

        It "Should have eryph-guest-services Windows service" {
            $svc = Get-Service -Name eryph-guest-services -ErrorAction SilentlyContinue
            $svc | Should -Not -BeNullOrEmpty
            $svc.StartType | Should -Be 'Automatic'
            # Status can be Running OR Stopped at base-catlet time — sysprep'd
            # images typically capture the service before it has anything to do.
            $svc.Status | Should -BeIn @('Running', 'Stopped')
        }

        It "Should have written entries to the Application event log under source 'egs-service'" {
            # Packer's chef run starts the service (sc.exe start), so an
            # initial startup entry is present even on a base image with no
            # user-data.
            $events = Get-WinEvent -LogName Application -ProviderName 'egs-service' `
                                    -MaxEvents 50 -ErrorAction SilentlyContinue
            $events | Should -Not -BeNullOrEmpty -Because "egs-service emits a startup entry on first run"
        }

        It "Should have no Error-level events from egs-service" {
            $errors = Get-WinEvent -LogName Application -ProviderName 'egs-service' `
                                    -ErrorAction SilentlyContinue |
                      Where-Object { $_.LevelDisplayName -eq 'Error' }
            $errors | Should -BeNullOrEmpty -Because "base catlet must have no egs errors"
        }

        It "Should NOT have cloudbase-init installed (replaced by egs-service)" {
            Test-Path "C:\Program Files\Cloudbase Solutions\Cloudbase-Init" |
                Should -Be $false -Because "the eryph-genes Windows pipeline no longer installs cbi"
            Get-Service -Name cloudbase-init -ErrorAction SilentlyContinue |
                Should -BeNullOrEmpty
        }
    }
    
    Context "Windows Configuration" {

        
        It "Should have network connectivity" {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            $adapters | Should -Not -BeNullOrEmpty -Because "Should have at least one active network adapter"
        }
        
        It "Should have correct time zone configured" {
            $timeZone = Get-TimeZone
            $timeZone | Should -Not -BeNullOrEmpty
            # Time zone should be set (not just default)
            $timeZone.Id | Should -Not -BeNullOrEmpty
        }
        
    }
    
    Context "Disk and Storage" {
        It "Should have sufficient free space on C: drive" {
            $disk = Get-PSDrive C
            $freeGB = [math]::Round($disk.Free / 1GB, 2)
            $freeGB | Should -BeGreaterThan 5 -Because "Should have at least 5GB free space"
        }
        
        It "Should have temp directories clean" {
            $tempFiles = Get-ChildItem -Path $env:TEMP -ErrorAction SilentlyContinue
            $packagingFiles = $tempFiles | Where-Object { $_.Name -match "packer|install|setup" }
            $packagingFiles.Count | Should -BeLessOrEqual 5 -Because "Temp directory should be relatively clean"
        }
    }
}
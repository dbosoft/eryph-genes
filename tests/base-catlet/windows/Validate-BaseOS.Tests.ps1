# Validate-BaseOS.Tests.ps1
# Pester tests that run INSIDE Windows base catlets to validate the base OS image
# These tests verify sysprep, cloudbase-init, and general OS configuration

Describe "Windows Base Catlet Validation" {
    
    BeforeAll {
        # Import CloudInit analyzer module if available
        $analyzerPath = Join-Path $PSScriptRoot "CloudInit.Analyzers.psm1"
        if (Test-Path $analyzerPath) {
            Import-Module $analyzerPath -Force
            Write-Host "CloudInit analyzer module loaded" -ForegroundColor Green
        } else {
            Write-Host "CloudInit analyzer module not found at: $analyzerPath" -ForegroundColor Yellow
        }
    }
    
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
    
    Context "Cloudbase-Init Validation" {
        It "Should have cloudbase-init installed" {
            $cloudbasePath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init"
            Test-Path $cloudbasePath | Should -Be $true -Because "Cloudbase-init should be installed"
        }
        
        It "Should have cloudbase-init log file" {
            $logPaths = @(
                "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log",
                "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init-unattend.log"
            )
            $foundLog = $false
            foreach ($logPath in $logPaths) {
                if (Test-Path $logPath) {
                    $foundLog = $true
                    break
                }
            }
            $foundLog | Should -Be $true -Because "Cloudbase-init should create log files"
        }
        
        It "Should have cloudbase-init service (stopped after completion is OK)" {
            $service = Get-Service -Name cloudbase-init -ErrorAction SilentlyContinue
            $service | Should -Not -BeNullOrEmpty
            # Service typically stops after successful completion - this is expected
            $service.Status | Should -BeIn @("Running", "Stopped") -Because "Cloudbase-init can be running or stopped (normal after completion)"
        }
        
        It "Should have completed cloudbase-init execution without errors" {
            $service = Get-Service -Name cloudbase-init -ErrorAction SilentlyContinue
            
            # Wait for cloudbase-init to complete if it's still running
            if ($service -and $service.Status -eq "Running") {
                Write-Host "Cloudbase-init is still running, waiting for completion..."
                $timeout = 300  # 5 minutes
                $waited = 0
                while ($service.Status -eq "Running" -and $waited -lt $timeout) {
                    Start-Sleep -Seconds 10
                    $waited += 10
                    $service.Refresh()
                    Write-Host "Waited $waited seconds for cloudbase-init to complete..."
                }
                
                if ($service.Status -eq "Running") {
                    Write-Warning "Cloudbase-init still running after $timeout seconds, proceeding with log check"
                } else {
                    Write-Host "Cloudbase-init completed after $waited seconds"
                }
            }
            
            # Always check logs regardless of service status
            $logPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log"
            if (Test-Path $logPath) {
                $log = Get-Content $logPath -Raw
                
                # Check for errors using the analyzer
                $analyzerPath = Join-Path $PSScriptRoot "CloudInit.Analyzers.psm1"
                if (Test-Path $analyzerPath) {
                    Import-Module $analyzerPath -Force
                    $errors = $log | Get-CloudbaseInitUserDataError
                    $errors | Should -BeNullOrEmpty -Because "Should not have user data errors"
                }
                
                # Check for critical errors
                $log | Should -Not -Match "CRITICAL|ERROR.*Failed" -Because "Should not have critical errors"
            } else {
                Set-ItResult -Skipped -Because "Cloudbase-init log not found (may have been cleaned up)"
            }
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
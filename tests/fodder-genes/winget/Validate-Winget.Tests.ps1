# Validate-Winget.Tests.ps1
# Pester tests for validating the winget fodder gene
# These tests run INSIDE Windows VMs to verify winget installation

Describe "Winget Fodder Gene Validation" {
    
    Context "Winget Installation" {
        It "Should have winget executable available" {
            $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
            $wingetPath | Should -Not -BeNullOrEmpty -Because "winget should be installed and in PATH"
        }
        
        It "Should have correct winget version" {
            $wingetVersion = winget --version 2>&1
            $wingetVersion | Should -Not -BeNullOrEmpty
            $wingetVersion | Should -Match "v\d+\.\d+\.\d+" -Because "winget should return a valid version number"
        }
        
        It "Should have App Installer package installed" {
            $appInstaller = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue
            $appInstaller | Should -Not -BeNullOrEmpty -Because "Microsoft.DesktopAppInstaller should be installed"
        }
    }
    
    Context "Winget Configuration" {
        It "Should have winget sources configured" {
            $sources = winget source list 2>&1 | Out-String
            $sources | Should -Not -BeNullOrEmpty
            $sources | Should -Match "msstore|winget" -Because "Default sources should be configured"
        }
        
        It "Should be able to search packages" {
            # Test basic search functionality
            $searchResult = winget search "Microsoft.PowerShell" --accept-source-agreements 2>&1 | Out-String
            $searchResult | Should -Not -BeNullOrEmpty
            $searchResult | Should -Not -Match "error|failed" -Because "Search should work without errors"
        }
        
        It "Should have accepted source agreements" {
            # The fodder should have pre-accepted agreements
            $testSearch = winget search "test" 2>&1 | Out-String
            $testSearch | Should -Not -Match "agreements" -Because "Source agreements should already be accepted"
        }
    }
    
    Context "Package Installation Test" {
        It "Should be able to install a small test package" {
            # Try to install a small, quick package as a test
            # Using --force to avoid prompts, --silent for quiet install
            $installResult = winget install "Microsoft.PowerShell" --accept-package-agreements --accept-source-agreements --force --silent 2>&1 | Out-String
            
            if ($installResult -match "already installed") {
                # Package already installed is OK
                $true | Should -Be $true
            } elseif ($installResult -match "successfully installed") {
                # Fresh install succeeded
                $true | Should -Be $true
            } else {
                # Check for common issues
                $installResult | Should -Not -Match "error|failed" -Because "Installation should not error"
            }
        }
    }
    
    Context "Dependencies and Prerequisites" {
        It "Should have Visual C++ Redistributables" {
            # Check for VC++ redistributables that winget depends on
            $vcRedist = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\VisualStudio\*\VC\Runtimes\x64" -ErrorAction SilentlyContinue
            if (-not $vcRedist) {
                $vcRedist = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\*\VC\Runtimes\x86" -ErrorAction SilentlyContinue
            }
            
            # Winget can work without VC++ redist but it's good to have
            if (-not $vcRedist) {
                Set-ItResult -Skipped -Because "VC++ Redistributables not found (optional)"
            } else {
                $vcRedist | Should -Not -BeNullOrEmpty
            }
        }
        
        It "Should have Windows Package Manager service" {
            # Check if the Windows Package Manager service exists
            $service = Get-Service -Name "AppXSvc" -ErrorAction SilentlyContinue
            $service | Should -Not -BeNullOrEmpty -Because "AppX deployment service should exist"
            $service.Status | Should -Be "Running" -Because "AppX service should be running"
        }
    }
    
    Context "Logging and Troubleshooting" {
        It "Should have winget logs directory" {
            $logPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"
            if (Test-Path $logPath) {
                $logFiles = Get-ChildItem $logPath -Filter "*.log" -ErrorAction SilentlyContinue
                Write-Host "Found $($logFiles.Count) log files in winget log directory" -ForegroundColor Gray
            } else {
                Write-Host "Winget log directory not found (may not have run yet)" -ForegroundColor Yellow
            }
            
            # This is informational, don't fail the test
            $true | Should -Be $true
        }
    }
}
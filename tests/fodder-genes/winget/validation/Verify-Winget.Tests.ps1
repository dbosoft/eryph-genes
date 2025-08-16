# Verify-Winget.Tests.ps1
# Pester tests that run INSIDE the VM to validate winget installation
# Pester is imported by path - no module complexity needed

Describe "Winget Installation" {
    Context "Core Components" {
        It "Should have winget executable in PATH" {
            $winget = Get-Command winget -ErrorAction SilentlyContinue
            $winget | Should -Not -BeNullOrEmpty
            $winget.Source | Should -Exist
        }
        
        It "Should return valid version format" {
            $version = winget --version 2>&1
            $version | Should -Not -BeNullOrEmpty
            $version | Should -Match "v\d+\.\d+\.\d+"
        }
        
        It "Should have Microsoft.DesktopAppInstaller package" {
            $package = Get-AppxPackage Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue
            $package | Should -Not -BeNullOrEmpty
            $package.Status | Should -Be "Ok"
        }
        
        It "Should have minimum version 1.19 or higher" {
            $version = winget --version 2>&1
            if ($version -match "v(\d+)\.(\d+)") {
                $major = [int]$Matches[1]
                $minor = [int]$Matches[2]
                ($major -gt 1 -or ($major -eq 1 -and $minor -ge 19)) | Should -Be $true
            }
        }
    }
    
    Context "Dependencies" {
        It "Should have VCLibs installed" {
            $vclibs = Get-AppxPackage Microsoft.VCLibs* | 
                Where-Object { $_.Version -match "^14\." }
            $vclibs | Should -Not -BeNullOrEmpty
            $vclibs.Count | Should -BeGreaterThan 0
        }
        
        It "Should have UI.Xaml if on Windows 11" {
            $osVersion = [System.Environment]::OSVersion.Version
            if ($osVersion.Build -ge 22000) {
                # Windows 11 should have UI.Xaml
                $xaml = Get-AppxPackage Microsoft.UI.Xaml* -ErrorAction SilentlyContinue
                $xaml | Should -Not -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because "Not Windows 11"
            }
        }
    }
    
    Context "Functionality" {
        It "Should list configured sources" {
            $sources = winget source list 2>&1 | Out-String
            $sources | Should -Not -BeNullOrEmpty
            # Should have at least msstore or winget source
            ($sources -match "msstore" -or $sources -match "winget") | Should -Be $true
        }
        
        It "Should be able to search packages" {
            $searchResult = winget search "Microsoft.PowerShell" --accept-source-agreements 2>&1 | Out-String
            $searchResult | Should -Not -BeNullOrEmpty
            $searchResult | Should -Match "Microsoft\.PowerShell"
        }
        
        It "Should be able to show package details" {
            $showResult = winget show "Microsoft.PowerShell" --accept-source-agreements 2>&1 | Out-String
            $showResult | Should -Not -BeNullOrEmpty
            $showResult | Should -Not -Match "No package found"
            $showResult | Should -Match "Publisher|Version|Description"
        }
        
        It "Should list installed packages without error" {
            # This might return "No installed package found" which is OK
            $listResult = winget list --accept-source-agreements 2>&1 | Out-String
            $listResult | Should -Not -Match "error|failed" -Because "Command should not error"
        }
        
        It "Should have winget settings accessible" {
            $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
            # Settings file may not exist until first modified, but parent directory should
            $parentDir = Split-Path $settingsPath -Parent
            Test-Path $parentDir | Should -Be $true
        }
    }
    
    Context "Environment Integration" {
        It "Should be accessible from PowerShell" {
            $result = powershell.exe -Command "winget --version" 2>&1
            $result | Should -Match "v\d+"
        }
        
        It "Should be accessible from CMD" {
            $result = cmd.exe /c "winget --version" 2>&1
            $result | Should -Match "v\d+"
        }
        
        It "Should have proper PATH registration" {
            $path = $env:Path -split ';'
            $wingetInPath = $path | Where-Object { $_ -match "WindowsApps|Microsoft\.DesktopAppInstaller" }
            $wingetInPath | Should -Not -BeNullOrEmpty
        }
    }
}
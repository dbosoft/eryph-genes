[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [PSCustomObject]$TestConfig,
    
    [Parameter(Mandatory=$true)]
    [string]$BaseOS,
    
    [switch]$KeepVM
)

BeforeAll {
    Import-Module $PSScriptRoot\..\..\EryphTestHelpers.psm1 -Force
    $script:geneName = $TestConfig.gene
    $script:osConfig = $TestConfig.supportedOS | Where-Object { $_.parent -eq $BaseOS }
}

Describe "Fodder Gene: $geneName on $BaseOS" -Skip:(-not $osConfig.enabled) {
    BeforeAll {
        Write-Information "Testing $geneName on $BaseOS" -InformationAction Continue
        if ($osConfig.notes) {
            Write-Information "Note: $($osConfig.notes)" -InformationAction Continue
        }
        
        # Create test catlet with winget fodder
        $catletName = "test-winget-$(Get-Random -Maximum 9999)"
        $yaml = @"
name: $catletName
parent: $BaseOS

fodder:
  - source: gene:dbosoft/guest-services:latest:win-install
  - source: gene:dbosoft/winget:latest:install
"@
        
        Write-Information "Creating catlet: $catletName" -InformationAction Continue
        $script:catlet = $yaml | New-Catlet -SkipVariablesPrompt
        $script:vmId = $catlet.VmId
        
        # Setup EGS connection
        Setup-EGSConnection -VmId $vmId
        
        # Start catlet
        Write-Information "Starting catlet" -InformationAction Continue
        $catlet | Start-Catlet -Force
        
        # Wait for catlet to be ready
        $script:catletReady = Wait-CatletReady -VmId $vmId -TimeoutMinutes ($TestConfig.timeout / 60)
    }
    
    Context "Phase A: Host-Based Validation" -Skip:(-not $catletReady) {
        It "Should complete installation without critical errors" {
            $logs = Get-CloudbaseInitLog -VmId $vmId
            $logs | Should -Not -BeNullOrEmpty
            $logs | Should -Not -Match "ERROR.*winget.*critical"
        }
        
        It "Should show winget installation success in logs" {
            $logs = Get-CloudbaseInitLog -VmId $vmId
            # Check for success indicators
            $logs | Should -Match "Winget.*install|App Installer.*install|DesktopAppInstaller"
        }
        
        It "Should handle VCLibs dependencies correctly" {
            $logs = Get-CloudbaseInitLog -VmId $vmId
            # Check for common dependency error that should NOT appear
            $logs | Should -Not -Match "0x80073D19|0x80073CF3"
        }
    }
    
    Context "Phase B: In-Catlet Validation" -Skip:(-not $catletReady) {
        BeforeAll {
            # Copy test suite (Pester + validation tests) to catlet
            Write-Information "Copying test suite to catlet..." -InformationAction Continue
            $script:testSuite = Copy-TestSuiteToVM -VmId $vmId -TestSourcePath "$PSScriptRoot\validation" -OsType "windows"
        }
        
        It "Should pass all Pester validation tests" {
            # Run Pester tests in VM
            $result = Invoke-PesterInVM -VmId $vmId -TestPath "$($testSuite.TestRoot)\validation" -OsType "windows"
            $result | Should -Match "VALIDATION_PASSED"
        }
        
        It "Should have winget accessible (quick check)" {
            # Quick sanity check outside of Pester
            $wingetPath = Invoke-EGSCommand -VmId $vmId -Command "where.exe winget 2>nul"
            $wingetPath | Should -Not -BeNullOrEmpty
            $wingetPath | Should -Match "winget.exe"
        }
        
        It "Should be able to run specific test file" {
            # Can also run the runner script directly for specific tests
            $result = Invoke-EGSCommand -VmId $vmId -Command "powershell -ExecutionPolicy Bypass -File '$($testSuite.RunnerPath)' -TestPattern 'Verify-Winget.Tests.ps1'"
            # Check exit code (0 = all passed)
            $exitCode = Invoke-EGSCommand -VmId $vmId -Command "echo `$LASTEXITCODE"
            [int]$exitCode | Should -Be 0 -Because "All tests should pass"
        }
    }
    
    AfterAll {
        if ($catlet -and -not $KeepVM) {
            Write-Information "Removing test catlet" -InformationAction Continue
            $catlet | Remove-Catlet -Force -ErrorAction SilentlyContinue
        }
    }
}
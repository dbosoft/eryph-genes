# Test-PackedBaseCatlet.Tests.ps1
# Host-side Pester tests for validating packed base catlets
# These tests validate a PRE-DEPLOYED catlet (deployment handled by orchestrator)

param(
    [Parameter(Mandatory=$true)]
    [string]$Geneset,
    
    [Parameter(Mandatory=$true)]
    [string]$GenepoolPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OsType,
    
    [switch]$KeepVM,
    
    # Pre-deployed catlet information (passed by orchestrator)
    [Parameter(Mandatory=$true)]
    [string]$CatletId,
    
    [Parameter(Mandatory=$true)]
    [string]$VmId,
    
    [Parameter(Mandatory=$true)]
    [bool]$GenesetExistedBefore,
    
    [Parameter(Mandatory=$true)]
    [string]$GensetTargetPath
)

BeforeAll {
    # Import helpers
    Import-Module $PSScriptRoot\tests\EryphTestHelpers.psm1 -Force
    
    # Get the pre-deployed catlet
    $script:catlet = Get-Catlet -Id $CatletId
    $script:vmId = $VmId
    
    Write-Information "Validating pre-deployed catlet - ID: $CatletId, VmId: $VmId" -InformationAction Continue
}

Describe "Packed Base Catlet: $Geneset" -Tag "BaseCatlet" {
    
    Context "Gene Availability" {
        It "Should have geneset available in genepool" {
            Test-Path $GensetTargetPath | Should -Be $true -Because "Geneset should be copied to genepool"
        }
        
        It "Should have packed files in geneset" {
            $files = Get-ChildItem $GensetTargetPath -ErrorAction SilentlyContinue
            $files | Should -Not -BeNullOrEmpty -Because "Geneset should contain packed files"
            
            # The genepool contains compressed/hashed files that will be decompressed on-demand
            # We just need to verify files exist, not their specific names
            $files.Count | Should -BeGreaterThan 0 -Because "Should have at least one packed file"
        }
    }
    
    Context "Catlet Validation" {
        It "Should have pre-deployed catlet available" {
            $catlet | Should -Not -BeNullOrEmpty -Because "Catlet should be pre-deployed by orchestrator"
            $catlet.Id | Should -Be $CatletId -Because "Should match the deployed catlet ID"
            $catlet.VmId | Should -Be $VmId -Because "Should match the deployed VM ID"
        }
        
        It "Should have catlet in running state" {
            $currentCatlet = Get-Catlet -Id $CatletId
            $currentCatlet.Status | Should -BeIn @("Running", "Converging") -Because "Catlet should be running"
        }
        
        It "Should be accessible via EGS" {
            $hostname = Invoke-EGSCommand -VmId $vmId -Command "hostname"
            $hostname | Should -Not -BeNullOrEmpty -Because "Should be able to execute commands via EGS"
        }
    }
    
    Context "In-VM Validation Tests" {
        BeforeAll {
            # Check if validation tests exist for this OS
            $script:localTestsPath = Join-Path $PSScriptRoot "tests\base-catlet\$OsType"
            $script:hasValidationTests = Test-Path $localTestsPath
            
            if ($hasValidationTests) {
                Write-Information "Copying validation test suite to VM" -InformationAction Continue
                $script:testSuite = Copy-TestSuiteToVM -VmId $vmId -TestSourcePath $localTestsPath -OsType $OsType
            }
        }
        
        It "Should have validation tests available" {
            $hasValidationTests | Should -Be $true -Because "Validation tests should exist for $OsType"
        }
        
        It "Should run and pass all in-VM validation tests" {
            if (-not $hasValidationTests) {
                Set-ItResult -Skipped -Because "No validation tests available for $OsType"
                return
            }
            
            # Run tests using the runner script
            $command = if ($OsType -eq "windows") {
                "powershell -File $($testSuite.RunnerPath)"
            } else {
                "pwsh $($testSuite.RunnerPath)"
            }
            
            Write-Host "`n========================================" -ForegroundColor Magenta
            Write-Host " IN-VM VALIDATION TESTS" -ForegroundColor Magenta
            Write-Host "========================================" -ForegroundColor Magenta
            
            $output = Invoke-EGSCommand -VmId $vmId -Command $command
            
            # Display the full Pester output from inside the VM
            foreach ($line in $output) {
                Write-Host $line
            }
            
            # Join output for better analysis
            $outputText = $output -join "`n"
            
            # Check for Pester execution
            $outputText | Should -Match "Starting discovery" -Because "Pester should start test discovery"
            $outputText | Should -Match "Tests completed in" -Because "Pester should complete execution"
            
            # Check for test summary in output
            $outputText | Should -Match "Test Summary:" -Because "Should have test summary from runner script"
            
            Write-Host "========================================" -ForegroundColor Magenta
            
            # Parse and validate test results for assertions
            if ($outputText -match "Tests Passed: (\d+), Failed: (\d+)") {
                $passed = [int]$Matches[1]
                $failed = [int]$Matches[2]
                
                # All tests should pass
                $failed | Should -Be 0 -Because "All in-VM validation tests should pass"
                $passed | Should -BeGreaterThan 0 -Because "Should have run at least one test"
            } elseif ($outputText -match "Test Summary: Total=(\d+) Passed=(\d+) Failed=(\d+)") {
                # Alternative format from runner.ps1
                $total = [int]$Matches[1]
                $passed = [int]$Matches[2]
                $failed = [int]$Matches[3]
                
                # All tests should pass
                $failed | Should -Be 0 -Because "All in-VM validation tests should pass"
                $passed | Should -BeGreaterThan 0 -Because "Should have run at least one test"
            } else {
                throw "Could not parse test results from output"
            }
            
            # Check exit code (0 = success)
            $exitCode = Invoke-EGSCommand -VmId $vmId -Command "echo `$LASTEXITCODE"
            [int]$exitCode | Should -Be 0 -Because "Test runner should exit with 0 for success"
        }
    }
    
    # Note: Cleanup is handled by the orchestrator, not here
}
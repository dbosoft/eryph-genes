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
    
    Context "Provisioning State (egs-service)" -Skip:($OsType -ne 'windows') {
        # egs-service writes C:\ProgramData\eryph\provisioning\state.json at the
        # end of first-boot provisioning. This is the authoritative signal that
        # the embedded provisioning agent ran successfully and replaced
        # cloudbase-init. Each completed handler also drops a semaphore under
        # provisioning\instance\<id>\sem\.
        BeforeAll {
            # EGS SSH does not run commands through a cmd.exe wrapper, so shell
            # builtins like `type` fail silently. Invoke powershell.exe directly
            # and avoid inner quotes - PowerShell forwards bare tokens cleanly
            # through `& ssh.exe -C $Command`.
            # Poll: EGS reports "available" as soon as the SSH server is up,
            # which can be before egs-service finishes the Final stage. Wait
            # until state.json shows Final completed, with a hard timeout.
            $readCmd = 'powershell -NoProfile -Command Get-Content -LiteralPath C:\ProgramData\eryph\provisioning\state.json -Raw'
            $deadline = (Get-Date).AddSeconds(120)
            $script:provisioningState = $null
            $script:provisioningStateRaw = $null
            while ((Get-Date) -lt $deadline) {
                $stateRaw = Invoke-EGSCommand -VmId $vmId -Command $readCmd
                $script:provisioningStateRaw = ($stateRaw -join "`n").Trim()
                if ($provisioningStateRaw) {
                    try {
                        $script:provisioningState = $provisioningStateRaw | ConvertFrom-Json
                    } catch {
                        $script:provisioningState = $null
                    }
                    if ($provisioningState -and (@($provisioningState.completedStages) -contains 'Final')) {
                        break
                    }
                }
                Start-Sleep -Seconds 2
            }
        }

        It "Should have provisioning state.json on disk" {
            $provisioningStateRaw | Should -Not -BeNullOrEmpty -Because "egs-service writes state.json at end of provisioning"
        }

        It "Should have completed all four provisioning stages" {
            # Force array shape — ConvertFrom-Json yields a string when a JSON
            # array has a single element, and `Should -Contain` unrolls the
            # pipeline in ways that break across both cases. The -contains
            # operator on a forced array is consistent.
            $stages = @($provisioningState.completedStages)
            ($stages -contains 'Local')   | Should -BeTrue -Because "Local stage must complete"
            ($stages -contains 'Network') | Should -BeTrue -Because "Network stage must complete"
            ($stages -contains 'Config')  | Should -BeTrue -Because "Config stage must complete"
            ($stages -contains 'Final')   | Should -BeTrue -Because "Final stage must complete"
        }

        It "Should have completed at least one provisioning handler" {
            $provisioningState.completedHandlers.Count | Should -BeGreaterThan 0
        }

        It "Should report no failed handlers / errors in state.json" {
            # state.json is success-only on a clean run. Any property whose name
            # starts with failed/error/failure appearing means egs-service began
            # reporting failures.
            $failureProps = $provisioningState.PSObject.Properties.Name |
                Where-Object { $_ -match '^(failed|errors?|failures?)' }
            $failureProps | Should -BeNullOrEmpty
        }

        It "Should have eryph-guest-services in Running state" {
            # The EGS interactive shell is PowerShell, where `sc` is an alias for Set-Content
            # (so `sc query …` silently produces no output). Query the service as a cmdlet via
            # powershell.exe instead, following the bare-token convention used above.
            $svcOutput = Invoke-EGSCommand -VmId $vmId -Command 'powershell -NoProfile -Command Get-Service eryph-guest-services'
            ($svcOutput -join "`n") | Should -Match 'Running'
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
                "pwsh -File $($testSuite.RunnerPath)"
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
            # Pester 5 prints "Starting discovery", Pester 6 prints "Running tests from N files"
            $outputText | Should -Match "Starting discovery|Running tests from" -Because "Pester should start test discovery"
            $outputText | Should -Match "Tests completed in" -Because "Pester should complete execution"
            
            # Check for test summary in output
            $outputText | Should -Match "Test Summary:" -Because "Should have test summary from runner script"
            
            Write-Host "========================================" -ForegroundColor Magenta
            
            # Parse and validate test results for assertions
            if ($outputText -match "Tests Passed: (\d+),\s*Failed: (\d+)") {
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
            
        }
    }
    
    # Note: Cleanup is handled by the orchestrator, not here
}
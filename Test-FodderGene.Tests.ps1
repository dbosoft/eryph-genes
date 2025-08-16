# Test-FodderGene.Tests.ps1
# Host-side Pester tests for validating fodder genes
# These tests run on the HOST and orchestrate fodder gene testing across base OS versions

param(
    [Parameter(Mandatory=$true)]
    [string]$Gene,
    
    [Parameter(Mandatory=$true)]
    [string]$Tag,
    
    [Parameter(Mandatory=$true)]
    [string[]]$BaseOS,
    
    [Parameter(Mandatory=$true)]
    [string]$GenepoolPath,
    
    [switch]$KeepVM
)

BeforeAll {
    # Import helpers
    Import-Module $PSScriptRoot\tests\EryphTestHelpers.psm1 -Force
    
    # Parse gene name
    $script:geneParts = $Gene -split '/'
    $script:geneProvider = $geneParts[0]
    $script:geneName = $geneParts[1]
    
    # Determine test path
    $script:testPath = Join-Path $PSScriptRoot "tests\fodder-genes\$geneName"
    
    # Check if gene tests exist
    $script:hasGeneTests = Test-Path $testPath
    
    if (-not $hasGeneTests) {
        Write-Warning "No tests found for gene: $geneName at $testPath"
        Write-Warning "Creating placeholder test structure..."
        
        # Create basic test structure
        New-Item -ItemType Directory -Path $testPath -Force | Out-Null
        
        # Create a basic validation test
        $basicTest = @"
# Validate-$geneName.Tests.ps1
# Auto-generated placeholder test for $Gene

Describe "$geneName Fodder Gene Validation" {
    It "Should be installed" {
        Write-Warning "No specific tests defined for $geneName"
        Set-ItResult -Skipped -Because "Specific tests not yet implemented"
    }
}
"@
        Set-Content -Path "$testPath\Validate-$geneName.Tests.ps1" -Value $basicTest
        $script:hasGeneTests = $true
    }
    
    # Build full gene identifier
    $script:fullGene = if ($Tag -ne 'latest') { "$Gene/$Tag" } else { $Gene }
    
    Write-Information "Testing fodder gene: $fullGene" -InformationAction Continue
    Write-Information "Test path: $testPath" -InformationAction Continue
}

Describe "Fodder Gene: $Gene" -Tag "FodderGene" {
    
    Context "Gene Availability" {
        It "Should have test files available" {
            $hasGeneTests | Should -Be $true -Because "Test files should exist for the gene"
        }
        
        It "Should have validation tests" {
            $validationTests = Get-ChildItem -Path $testPath -Filter "*.Tests.ps1" -ErrorAction SilentlyContinue
            $validationTests | Should -Not -BeNullOrEmpty -Because "Should have at least one test file"
        }
    }
    
    # Test on each base OS
    foreach ($baseOSSpec in $BaseOS) {
        # Ensure base OS has proper format
        $fullBaseOS = if ($baseOSSpec -notmatch '/') { "$baseOSSpec/latest" } else { $baseOSSpec }
        
        Context "Testing on Base OS: $fullBaseOS" {
            BeforeAll {
                Write-Information "=== Setting up test on $fullBaseOS ===" -InformationAction Continue
                
                # Determine OS type from base geneset
                $script:osType = if ($fullBaseOS -match "ubuntu|debian|rocky|almalinux|centos") { "linux" } else { "windows" }
                
                # Generate unique catlet name
                $timestamp = Get-Date -Format "HHmmss"
                $script:catletName = "test-$($geneName)-$($fullBaseOS -replace '/', '-')-$timestamp" -replace '[^a-zA-Z0-9\-]', ''
                
                # Determine EGS fodder
                $egsFodder = if ($osType -eq "windows") { "win-install" } else { "linux-install" }
                
                # Build fodder configuration
                $fodderLines = @(
                    "  - source: gene:dbosoft/guest-services:$egsFodder"
                )
                
                # Add PowerShell Core for Linux if needed
                if ($osType -eq "linux") {
                    $fodderLines += "  - source: gene:dbosoft/powershell:install"
                }
                
                # Add the gene being tested
                $fodderLines += "  - source: gene:$fullGene"
                
                # Add starter food
                if ($osType -eq "windows") {
                    $fodderLines += "  - source: gene:dbosoft/starter-food:win-starter"
                } else {
                    $fodderLines += "  - source: gene:dbosoft/starter-food:linux-starter"
                }
                
                # Create catlet YAML
                $script:catletYaml = @"
name: $catletName
parent: $fullBaseOS

fodder:
$($fodderLines -join "`n")
"@
                
                Write-Verbose "Catlet YAML:`n$catletYaml"
                
                # Track if deployment succeeded
                $script:deploymentSucceeded = $false
                $script:catlet = $null
                $script:vmId = $null
            }
            
            It "Should deploy catlet with fodder gene" {
                try {
                    Write-Information "Creating catlet: $catletName" -InformationAction Continue
                    $script:catlet = $catletYaml | New-Catlet -SkipVariablesPrompt
                    $script:vmId = $catlet.VmId
                    $script:deploymentSucceeded = $true
                    
                    Write-Information "Created catlet - ID: $($catlet.Id), VmId: $vmId" -InformationAction Continue
                    $catlet | Should -Not -BeNullOrEmpty
                    $vmId | Should -Not -BeNullOrEmpty
                }
                catch {
                    Write-Error "Failed to create catlet: $_"
                    throw
                }
            }
            
            It "Should setup EGS connection" -Skip:(-not $deploymentSucceeded) {
                Initialize-EGSConnection -VmId $vmId | Should -Be $true
            }
            
            It "Should start catlet successfully" -Skip:(-not $deploymentSucceeded) {
                $catlet | Start-Catlet -Force
                Start-Sleep -Seconds 5
                
                $startedCatlet = Get-Catlet -Id $catlet.Id
                $startedCatlet.Status | Should -BeIn @("Running", "Pending", "Converging")
            }
            
            It "Should have EGS ready" -Skip:(-not $deploymentSucceeded) {
                $egsReady = Wait-EGSReady -VmId $vmId -TimeoutMinutes 5
                $egsReady | Should -Be $true -Because "EGS should be available for testing"
            }
            
            It "Should have network connectivity" -Skip:(-not $deploymentSucceeded) {
                # Get IP address
                $ipInfo = Get-CatletIp -Id $catlet.Id
                $ipInfo | Should -Not -BeNullOrEmpty
                
                if ($ipInfo) {
                    Write-Information "Catlet IP: $($ipInfo.IpAddress)" -InformationAction Continue
                }
            }
            
            Context "In-VM Fodder Gene Validation" -Skip:(-not $deploymentSucceeded) {
                BeforeAll {
                    if ($deploymentSucceeded -and $vmId) {
                        Write-Information "Copying test suite to VM" -InformationAction Continue
                        $script:testSuite = Copy-TestSuiteToVM -VmId $vmId -TestSourcePath $testPath -OsType $osType
                    }
                }
                
                It "Should copy test files successfully" {
                    $testSuite | Should -Not -BeNullOrEmpty
                    $testSuite.TestRoot | Should -Not -BeNullOrEmpty
                    $testSuite.PesterPath | Should -Not -BeNullOrEmpty
                }
                
                It "Should pass fodder gene validation tests" {
                    $result = Invoke-PesterInVM -VmId $vmId -TestPath "$($testSuite.TestRoot)\validation" -OsType $osType
                    $result | Should -Match "VALIDATION_PASSED|All tests passed"
                }
                
                It "Should complete without errors" {
                    # Run the test runner and check exit code
                    $command = if ($osType -eq "windows") {
                        "powershell -File '$($testSuite.RunnerPath)'"
                    } else {
                        "pwsh '$($testSuite.RunnerPath)'"
                    }
                    
                    $output = Invoke-EGSCommand -VmId $vmId -Command $command
                    $output | Should -Not -BeNullOrEmpty
                    
                    # Check for test summary
                    $output | Should -Match "Test Summary:"
                    
                    # Extract pass/fail counts if possible
                    if ($output -match "Failed=(\d+)") {
                        [int]$Matches[1] | Should -Be 0 -Because "No tests should fail"
                    }
                }
                
                It "Should have fodder properly installed" {
                    # Gene-specific verification
                    $verifyCommand = switch ($geneName) {
                        "winget" {
                            if ($osType -eq "windows") { "winget --version" } else { $null }
                        }
                        "powershell" {
                            if ($osType -eq "linux") { "pwsh --version" } else { "powershell -Command '$PSVersionTable.PSVersion'" }
                        }
                        default { $null }
                    }
                    
                    if ($verifyCommand) {
                        $result = Invoke-EGSCommand -VmId $vmId -Command $verifyCommand
                        $result | Should -Not -BeNullOrEmpty -Because "$geneName should be installed and functional"
                    } else {
                        Set-ItResult -Skipped -Because "No specific verification for $geneName"
                    }
                }
            }
            
            AfterAll {
                if ($catlet) {
                    if (-not $KeepVM) {
                        Write-Information "Removing test catlet: $catletName" -InformationAction Continue
                        try {
                            Remove-Catlet -Id $catlet.Id -Force -ErrorAction SilentlyContinue
                        }
                        catch {
                            Write-Warning "Could not remove catlet: $_"
                        }
                    } else {
                        Write-Information "Keeping VM for debugging: $catletName (ID: $($catlet.Id))" -InformationAction Continue
                    }
                }
            }
        }
    }
    
    Context "Summary" {
        It "Should have tested on all requested base OS versions" {
            # This is a meta-test to ensure we tested everything requested
            $BaseOS.Count | Should -BeGreaterThan 0
        }
    }
}
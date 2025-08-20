# Invoke-FodderGeneTest.ps1
# Standardized test runner for fodder genes
# Uses convention-based discovery to minimize boilerplate

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$GeneTag,  # Full gene tag like "dbosoft/winget/latest"
    
    [Parameter(Mandatory=$true)]
    [string]$GeneName,  # Gene name for path resolution
    
    [switch]$KeepVM,    # Keep VMs after testing for debugging
    
    [scriptblock]$CustomValidation = $null,  # Optional custom validation logic
    
    [scriptblock]$BeforeAllTests = $null,    # Optional setup hook
    
    [scriptblock]$AfterAllTests = $null      # Optional cleanup hook
)

# This script is designed to be called from individual Test-{Gene}.Tests.ps1 files
# It handles all the common patterns while allowing customization through hooks

$ErrorActionPreference = 'Stop'

# Resolve test directory for this gene
$testRoot = Join-Path $PSScriptRoot "fodder-genes\$GeneName"
if (-not (Test-Path $testRoot)) {
    throw "Test directory not found for gene '$GeneName': $testRoot"
}

Write-Information "Test directory: $testRoot" -InformationAction Continue

# Import helper module
$helperPath = Join-Path $PSScriptRoot "EryphTestHelpers.psm1"
if (-not (Test-Path $helperPath)) {
    throw "Helper module not found at: $helperPath"
}
Import-Module $helperPath -Force

# Load test matrix configuration
$matrixPath = Join-Path $testRoot "test-matrix.psd1"
if (-not (Test-Path $matrixPath)) {
    throw "Test matrix configuration not found at: $matrixPath"
}
$testMatrix = Import-PowerShellDataFile $matrixPath

# Parse gene tag
$parts = $GeneTag -split '/'
$geneProvider = if ($parts.Count -ge 1) { $parts[0] } else { "dbosoft" }
$geneNameFromTag = if ($parts.Count -ge 2) { $parts[1] } else { $GeneName }
$geneVersion = if ($parts.Count -ge 3) { $parts[2] } else { "latest" }

# Validate gene name consistency
if ($geneNameFromTag -ne $GeneName) {
    Write-Warning "Gene name from tag '$geneNameFromTag' doesn't match parameter '$GeneName'"
}

Write-Information "Testing gene: $GeneTag" -InformationAction Continue
Write-Information "Test suites: $($testMatrix.TestSuites.Count)" -InformationAction Continue

# Execute BeforeAllTests hook if provided
if ($BeforeAllTests) {
    Write-Information "Executing BeforeAllTests hook..." -InformationAction Continue
    & $BeforeAllTests
}

# Check for custom validation file
$customValidationFile = Join-Path $testRoot "Custom-$GeneName-Validation.ps1"
if ((Test-Path $customValidationFile) -and (-not $CustomValidation)) {
    Write-Information "Loading custom validation from: $customValidationFile" -InformationAction Continue
    $CustomValidation = [scriptblock]::Create((Get-Content $customValidationFile -Raw))
}

# Main test execution within Pester context
Describe "$GeneName Gene [$GeneTag]" {
    
    # Execute all test suites defined in the matrix
    foreach ($suite in $testMatrix.TestSuites) {
        
        Context "Suite: $($suite.Name) - $($suite.Description)" {
            
            # Create test cases for each OS in the matrix
            $testCases = $suite.OSMatrix | ForEach-Object {
                @{
                    OSVersion = $_
                    SuiteName = $suite.Name
                    CatletSpec = $suite.CatletSpec
                    HostTests = $suite.HostTests
                    InVMTests = $suite.InVMTests
                }
            }
            
            It "Should validate on <OSVersion>" -TestCases $testCases {
                param(
                    $OSVersion,
                    $SuiteName,
                    $CatletSpec,
                    $HostTests,
                    $InVMTests
                )
                
                # Load catlet specification
                $specPath = Join-Path $testRoot $CatletSpec
                if (-not (Test-Path $specPath)) {
                    throw "Catlet specification not found: $specPath"
                }
                $catletYaml = Get-Content $specPath -Raw
                
                # Prepare test file paths
                $inVMTestPaths = @()
                if ($InVMTests -and $InVMTests.Count -gt 0) {
                    $inVMTestPaths = $InVMTests | ForEach-Object {
                        Join-Path $testRoot $_
                    }
                    
                    # Verify all test files exist
                    foreach ($testPath in $inVMTestPaths) {
                        if (-not (Test-Path $testPath)) {
                            throw "Test file not found: $testPath"
                        }
                    }
                }
                
                # Prepare host tests (convert to hashtable if ordered)
                $hostTestsTable = @{}
                if ($HostTests) {
                    if ($HostTests -is [System.Collections.Specialized.OrderedDictionary]) {
                        # Convert OrderedDictionary to regular hashtable
                        foreach ($key in $HostTests.Keys) {
                            $hostTestsTable[$key] = $HostTests[$key]
                        }
                    } elseif ($HostTests -is [hashtable]) {
                        $hostTestsTable = $HostTests
                    }
                }
                
                # Use the Invoke-TestSuite helper function with automatic validation
                $result = Invoke-TestSuite `
                    -SuiteName $SuiteName `
                    -CatletSpec $catletYaml `
                    -OSVersion $OSVersion `
                    -GeneTag $GeneTag `
                    -InVMTests $inVMTestPaths `
                    -HostTests $hostTestsTable `
                    -KeepVM:$KeepVM `
                    -ThrowOnFailure
                
                # Execute custom validation if provided
                if ($CustomValidation) {
                    Write-Information "Executing custom validation..." -InformationAction Continue
                    try {
                        $customResult = & $CustomValidation -VmId $result.VmId -TestResult $result
                        if ($customResult -and $customResult.Failed -gt 0) {
                            throw "Custom validation failed: $($customResult.Errors -join '; ')"
                        }
                    } catch {
                        throw "Custom validation error: $_"
                    }
                }
                
                # Verify tests actually ran
                $result.Passed | Should -BeGreaterThan 0 -Because "Should have executed at least one test"
            }
        }
    }
}

# Execute AfterAllTests hook if provided
if ($AfterAllTests) {
    Write-Information "Executing AfterAllTests hook..." -InformationAction Continue
    & $AfterAllTests
}

# Summary
Write-Information "" -InformationAction Continue
Write-Information "========================================" -InformationAction Continue
Write-Information "$GeneName gene testing completed for: $GeneTag" -InformationAction Continue
Write-Information "========================================" -InformationAction Continue
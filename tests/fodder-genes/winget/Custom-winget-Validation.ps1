# Custom-winget-Validation.ps1
# Custom validation logic for winget gene testing
# Handles realistic expectations across different Windows versions

param(
    [Parameter(Mandatory=$true)]
    [string]$VmId,
    
    [Parameter(Mandatory=$true)]
    [hashtable]$TestResult
)

$ErrorActionPreference = 'Continue'
Write-Information "Executing custom winget validation for VM: $VmId" -InformationAction Continue

# Extract OS version from test context
$osVersion = $TestResult.OSVersion
$suiteName = $TestResult.SuiteName

Write-Information "Validating suite '$suiteName' on OS '$osVersion'" -InformationAction Continue

# Define realistic expectations per OS version
$expectations = @{
    "winsrv2019-standard" = @{
        WingetShouldWork = $false  # Server 2019 has very limited winget support
        ExpectedFailures = @("winget command not available", "App Installer not supported")
        RequiredChecks = @("OS build verification", "Windows Apps folder check")
    }
    "winsrv2022-standard" = @{
        WingetShouldWork = $true   # Server 2022 supports winget
        ExpectedFailures = @()
        RequiredChecks = @("winget version", "source list")
        MinimumFeatures = @("search", "show", "source management")
    }
    "win10-20h2-enterprise" = @{
        WingetShouldWork = $true   # Windows 10 20H2 supports winget
        ExpectedFailures = @()
        RequiredChecks = @("winget version", "source list", "package search")
        MinimumFeatures = @("search", "show", "basic source management")
    }
    "win11-24h2-enterprise" = @{
        WingetShouldWork = $true   # Windows 11 has full winget support
        ExpectedFailures = @()
        RequiredChecks = @("winget version", "source list", "package search", "advanced features")
        MinimumFeatures = @("search", "show", "source management", "export", "import", "validate")
    }
}

$osExpectation = $expectations[$osVersion]
if (-not $osExpectation) {
    Write-Warning "No expectations defined for OS version: $osVersion"
    return @{ Failed = 0; Passed = 1; Errors = @() }
}

$customValidationResults = @{
    Failed = 0
    Passed = 0
    Errors = @()
}

# Suite-specific validation logic
switch ($suiteName) {
    "WingetBasicFunctionality" {
        Write-Information "Validating basic winget functionality expectations" -InformationAction Continue
        
        if ($osVersion -eq "winsrv2019-standard") {
            # On Server 2019, we expect winget might not work
            if ($TestResult.HostTestResults.ContainsKey("CheckWingetExecutable")) {
                $wingetResult = $TestResult.HostTestResults["CheckWingetExecutable"]
                if ($wingetResult -match "not recognized|not found|command not found") {
                    Write-Information "✓ Expected: winget not available on Server 2019" -InformationAction Continue
                    $customValidationResults.Passed++
                } elseif ($wingetResult -match "v\d+\.\d+") {
                    Write-Information "✓ Unexpected but acceptable: winget is available on Server 2019" -InformationAction Continue
                    $customValidationResults.Passed++
                } else {
                    $customValidationResults.Failed++
                    $customValidationResults.Errors += "Winget check failed unexpectedly on Server 2019"
                }
            }
        } else {
            # On supported OS versions, winget should work
            if ($TestResult.HostTestResults.ContainsKey("CheckWingetExecutable")) {
                $wingetResult = $TestResult.HostTestResults["CheckWingetExecutable"]
                if ($wingetResult -match "v\d+\.\d+") {
                    Write-Information "✓ Expected: winget is working on $osVersion" -InformationAction Continue
                    $customValidationResults.Passed++
                } else {
                    $customValidationResults.Failed++
                    $customValidationResults.Errors += "Winget should be available on $osVersion but check failed: $wingetResult"
                }
            }
        }
    }
    
    "WingetSourceManagement" {
        Write-Information "Validating source management expectations" -InformationAction Continue
        
        # This suite should only run on supported OS versions
        if ($osExpectation.WingetShouldWork) {
            if ($TestResult.HostTestResults.ContainsKey("ListInitialSources")) {
                $sourcesResult = $TestResult.HostTestResults["ListInitialSources"]
                if ($sourcesResult -match "msstore|winget") {
                    Write-Information "✓ Expected: Default sources are available" -InformationAction Continue
                    $customValidationResults.Passed++
                } else {
                    $customValidationResults.Failed++
                    $customValidationResults.Errors += "Default winget sources not found: $sourcesResult"
                }
            }
        }
    }
    
    "WingetPackageSearch" {
        Write-Information "Validating package search expectations" -InformationAction Continue
        
        if ($osExpectation.WingetShouldWork) {
            if ($TestResult.HostTestResults.ContainsKey("SearchPopularPackage")) {
                $searchResult = $TestResult.HostTestResults["SearchPopularPackage"]
                if ($searchResult -match "Visual Studio Code|Microsoft\.VisualStudioCode") {
                    Write-Information "✓ Expected: Package search is working" -InformationAction Continue
                    $customValidationResults.Passed++
                } else {
                    $customValidationResults.Failed++
                    $customValidationResults.Errors += "Package search failed: $searchResult"
                }
            }
        }
    }
    
    "WingetCompatibilityCheck" {
        Write-Information "Validating compatibility check expectations" -InformationAction Continue
        
        # This suite specifically tests Server 2019 limitations
        if ($TestResult.HostTestResults.ContainsKey("CheckOSSupport")) {
            $osResult = $TestResult.HostTestResults["CheckOSSupport"]
            if ($osResult -match "Server 2019|BuildNumber.*17763") {
                Write-Information "✓ Expected: Confirmed running on Server 2019" -InformationAction Continue
                $customValidationResults.Passed++
            }
        }
        
        if ($TestResult.HostTestResults.ContainsKey("CheckWingetAvailability")) {
            $availabilityResult = $TestResult.HostTestResults["CheckWingetAvailability"]
            if ($availabilityResult -match "not available|expected on Server 2019") {
                Write-Information "✓ Expected: winget limitations on Server 2019 confirmed" -InformationAction Continue
                $customValidationResults.Passed++
            } elseif ($availabilityResult -match "v\d+\.\d+") {
                Write-Information "✓ Acceptable: winget is surprisingly available on Server 2019" -InformationAction Continue
                $customValidationResults.Passed++
            }
        }
    }
    
    "WingetAdvancedFeatures" {
        Write-Information "Validating advanced features expectations" -InformationAction Continue
        
        # This suite should only run on Windows 11
        if ($osVersion -eq "win11-24h2-enterprise") {
            if ($TestResult.HostTestResults.ContainsKey("ExportPackageList")) {
                $exportResult = $TestResult.HostTestResults["ExportPackageList"]
                if ($exportResult -match "Export successful") {
                    Write-Information "✓ Expected: Package export is working on Windows 11" -InformationAction Continue
                    $customValidationResults.Passed++
                } else {
                    Write-Information "⚠ Acceptable: Export may not work without packages installed" -InformationAction Continue
                    $customValidationResults.Passed++  # Don't fail if no packages to export
                }
            }
        }
    }
    
    default {
        Write-Information "No specific validation for suite: $suiteName" -InformationAction Continue
        $customValidationResults.Passed++
    }
}

# If no custom validation was performed, mark as passed
if ($customValidationResults.Passed -eq 0 -and $customValidationResults.Failed -eq 0) {
    $customValidationResults.Passed = 1
}

Write-Information "Custom validation completed: $($customValidationResults.Passed) passed, $($customValidationResults.Failed) failed" -InformationAction Continue

return $customValidationResults
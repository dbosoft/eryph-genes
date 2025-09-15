# Test-PackedBaseCatlet.ps1
# Orchestrator script for testing packed base catlets
# This script runs the Pester tests but is NOT itself a Pester test

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Geneset,
    
    [Parameter(Mandatory=$true)]
    [string]$GenepoolPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OsType,
    
    [Parameter(Mandatory=$false)]
    [switch]$KeepVM
)

$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
$ProgressPreference = "SilentlyContinue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Testing Packed Base Catlet" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Geneset: $Geneset" -ForegroundColor White
Write-Host "OS Type: $OsType" -ForegroundColor White
Write-Host "Genepool: $GenepoolPath" -ForegroundColor White
Write-Host ""

# Check if Pester 5 is available
$pester = Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } | Select-Object -First 1
if (-not $pester) {
    Write-Error "Pester 5.x or higher is required. Please install: Install-Module Pester -Force"
    exit 1
}

Write-Information "Using Pester $($pester.Version)" -InformationAction Continue

# Import Pester explicitly to ensure v5
Import-Module Pester -MinimumVersion 5.0 -Force

# Import helper module
$helperModule = Join-Path $PSScriptRoot "tests\EryphTestHelpers.psm1"
if (-not (Test-Path $helperModule)) {
    Write-Error "Helper module not found: $helperModule"
    exit 1
}
Import-Module $helperModule -Force

# Path to the actual test file
$testFile = Join-Path $PSScriptRoot "Test-PackedBaseCatlet.Tests.ps1"

if (-not (Test-Path $testFile)) {
    Write-Error "Test file not found: $testFile"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host " PHASE 1: Gene Setup and Deployment" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Setup paths for gene copying
$geneSource = Join-Path $PSScriptRoot "genes" -Resolve
$GenesetSourcePath = Join-Path $geneSource $Geneset.Replace('/', '\')
$GenesetPackagedPath = Join-Path $GenesetSourcePath ".packed"
$gensetTargetPath = Join-Path $GenepoolPath $Geneset.Replace('/', '\')

# Verify source exists
if (-not (Test-Path $GenesetPackagedPath)) {
    Write-Error "Packed geneset not found at: $GenesetPackagedPath"
    exit 1
}

Write-Information "Geneset source: $GenesetPackagedPath" -InformationAction Continue
Write-Information "Geneset target: $gensetTargetPath" -InformationAction Continue

# Remove previous test catlet if exists
Write-Information "Cleaning up any previous test catlets..." -InformationAction Continue
$oldCatlets = Get-Catlet | Where-Object Name -eq catlettest
if ($oldCatlets) {
    Write-Information "Found $($oldCatlets.Count) existing test catlet(s), removing..." -InformationAction Continue
    $oldCatlets | Remove-Catlet -Force -ErrorAction SilentlyContinue
    Write-Information "Test catlets removed" -InformationAction Continue
}

# Check if geneset exists in genepool and handle accordingly
$genesetExistedBefore = $false
if (Test-Path $gensetTargetPath -PathType Container) {
    Write-Information "Geneset already exists in genepool: $gensetTargetPath" -InformationAction Continue
    $genesetExistedBefore = $true
    
    # Delete existing content to ensure clean test with our packed version
    Write-Information "Removing existing geneset content for clean test..." -InformationAction Continue
    try {
        Remove-Item "$gensetTargetPath\*" -Force -Recurse
        Write-Information "Existing content removed successfully" -InformationAction Continue
    }
    catch {
        Write-Warning "Could not remove all existing content: $_"
    }
}
else {
    Write-Information "Geneset NOT found in genepool, will create new..." -InformationAction Continue
    
    # Create directory structure
    $parentPath = Split-Path $gensetTargetPath -Parent
    if (-not (Test-Path $parentPath)) {
        Write-Information "Creating parent directory: $parentPath" -InformationAction Continue
        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
    }
    
    Write-Information "Creating target directory: $gensetTargetPath" -InformationAction Continue
    New-Item -ItemType Directory -Path $gensetTargetPath -Force | Out-Null
}

# Copy ONLY the contents of .packed folder to genepool
Write-Information "Copying .packed contents from: $GenesetPackagedPath" -InformationAction Continue
Write-Information "Copying to: $gensetTargetPath" -InformationAction Continue

# List what we're copying
$packedFiles = Get-ChildItem "$GenesetPackagedPath\*"
Write-Information "Found $($packedFiles.Count) files in .packed: $($packedFiles.Name -join ', ')" -InformationAction Continue

# Copy ONLY the .packed folder contents
Copy-Item "$GenesetPackagedPath\*" -Destination $gensetTargetPath -Force -Recurse

# Verify copy worked
$copiedFiles = Get-ChildItem $gensetTargetPath
Write-Information "Copied $($copiedFiles.Count) files to genepool: $($copiedFiles.Name -join ', ')" -InformationAction Continue

if ($copiedFiles.Count -eq 0) {
    Write-Error "Failed to copy .packed contents to genepool"
    exit 1
}

Write-Information "Successfully copied .packed contents to genepool" -InformationAction Continue

# Deploy test catlet
Write-Information "=== DEPLOYING TEST CATLET ===" -InformationAction Continue

# Create test catlet configuration
$catletYaml = @"
name: catlettest
parent: $Geneset

fodder:
"@

if ($OsType -eq "windows") {
    # Add starter food for Windows
    $catletYaml += @"

  - source: gene:dbosoft/starter-food:win-starter
"@
} else {
    # Add PowerShell Core for Linux
    $catletYaml += @"

  - source: gene:dbosoft/powershell/next:linux-install
  - source: gene:dbosoft/starter-food:linux-starter
"@
}

Write-Verbose "Catlet YAML:`n$catletYaml"

# Deploy catlet
Write-Information "Creating catlet..." -InformationAction Continue
try {
    $catlet = $catletYaml | New-Catlet -SkipVariablesPrompt
    $vmId = $catlet.VmId
    Write-Information "Created catlet - ID: $($catlet.Id), VmId: $vmId" -InformationAction Continue
}
catch {
    Write-Error "DEPLOYMENT FAILED: Could not create catlet - $_"
    exit 1
}

# Setup EGS
Write-Information "Setting up EGS connection..." -InformationAction Continue
if (-not (Initialize-EGSConnection -VmId $vmId)) {
    Write-Error "Failed to setup EGS connection - extracting diagnostics..." -ErrorAction Continue
    
    # Extract diagnostics when EGS setup fails
    $diagnosticsPath = Join-Path $PSScriptRoot "diagnostics\$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($Geneset.Replace('/','-'))_egs-setup-failed"
    Write-Information "Extracting diagnostics to: $diagnosticsPath" -InformationAction Continue
    
    if ($OsType -eq "windows") {
        try {
            # Use our diagnostic extraction script (Windows only)
            $extractScript = Join-Path $PSScriptRoot "Extract-CatletDiagnostics.ps1"
            if (Test-Path $extractScript) {
                Write-Information "Extracting Windows diagnostics..." -InformationAction Continue
                & $extractScript -CatletId $catlet.Id -OutputPath $diagnosticsPath -KeepCatlet:$KeepVM
                Write-Information "Windows diagnostics extracted successfully" -InformationAction Continue
            } else {
                Write-Warning "Windows diagnostic extraction script not found at: $extractScript"
                if (-not $KeepVM) {
                    Remove-Catlet -Id $catlet.Id -Force -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            Write-Warning "Failed to extract diagnostics: $_"
            if (-not $KeepVM) {
                Remove-Catlet -Id $catlet.Id -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        Write-Information "Skipping diagnostic extraction for Linux catlet (Windows-only feature)" -InformationAction Continue
        if (-not $KeepVM) {
            Remove-Catlet -Id $catlet.Id -Force -ErrorAction SilentlyContinue
        }
    }
    
    exit 1
}

# Start catlet
Write-Information "Starting catlet..." -InformationAction Continue
try {
    $catlet | Start-Catlet -Force
    Start-Sleep -Seconds 5
    
    $startedCatlet = Get-Catlet -Id $catlet.Id
    if ($startedCatlet.Status -notin @("Running", "Pending", "Converging")) {
        throw "Catlet is in unexpected state: $($startedCatlet.Status)"
    }
    Write-Information "Catlet started successfully" -InformationAction Continue
}
catch {
    Write-Error "Failed to start catlet: $_ - extracting diagnostics..."  -ErrorAction Continue
    
    # Extract diagnostics when catlet fails to start
    $diagnosticsPath = Join-Path $PSScriptRoot "diagnostics\$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($Geneset.Replace('/','-'))_startup-failed"
    Write-Information "Extracting diagnostics to: $diagnosticsPath" -InformationAction Continue
    
    if ($OsType -eq "windows") {
        try {
            # Use our diagnostic extraction script (Windows only)
            $extractScript = Join-Path $PSScriptRoot "Extract-CatletDiagnostics.ps1"
            if (Test-Path $extractScript) {
                Write-Information "Extracting Windows diagnostics..." -InformationAction Continue
                & $extractScript -CatletId $catlet.Id -OutputPath $diagnosticsPath -KeepCatlet:$KeepVM
                Write-Information "Windows diagnostics extracted successfully" -InformationAction Continue
            } else {
                Write-Warning "Windows diagnostic extraction script not found at: $extractScript"
                if (-not $KeepVM) {
                    Remove-Catlet -Id $catlet.Id -Force -ErrorAction SilentlyContinue
                }
            }
        }
        catch {
            Write-Warning "Failed to extract diagnostics: $_"
            if (-not $KeepVM) {
                Remove-Catlet -Id $catlet.Id -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        Write-Information "Skipping diagnostic extraction for Linux catlet (Windows-only feature)" -InformationAction Continue
        if (-not $KeepVM) {
            Remove-Catlet -Id $catlet.Id -Force -ErrorAction SilentlyContinue
        }
    }
    
    exit 1
}

# Wait for EGS readiness
Write-Information "Waiting for EGS to be ready..." -InformationAction Continue
if (-not (Wait-EGSReady -VmId $vmId -TimeoutMinutes 10)) {
    Write-Error "EGS not ready after 10 minutes - extracting diagnostics..." -ErrorAction Continue
    
    # Call diagnostic extraction script (Windows only)
    $diagnosticsPath = Join-Path $PSScriptRoot "diagnostics\$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($Geneset.Replace('/','-'))"
    if ($OsType -eq "windows") {
        Write-Information "Extracting Windows diagnostics..." -InformationAction Continue
        & "$PSScriptRoot\Extract-CatletDiagnostics.ps1" -CatletId $catlet.Id -OutputPath $diagnosticsPath -KeepCatlet:$KeepVM
    } else {
        Write-Information "Skipping diagnostic extraction for Linux catlet (Windows-only feature)" -InformationAction Continue
        if (-not $KeepVM) {
            Remove-Catlet -Id $catlet.Id -Force -ErrorAction SilentlyContinue
        }
    }
    
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " PHASE 2: Running Validation Tests" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Configure Pester to run ONLY the test file, not auto-discover
$config = New-PesterConfiguration
$config.Run.Path = $testFile
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.Should.ErrorAction = 'Continue'

# Pass parameters to the test using TestData (including deployed catlet info)
$config.Run.Container = New-PesterContainer -Path $testFile -Data @{
    Geneset = $Geneset
    GenepoolPath = $GenepoolPath
    OsType = $OsType
    KeepVM = $KeepVM
    # Pre-deployed catlet information
    CatletId = $catlet.Id
    VmId = $vmId
    GenesetExistedBefore = $genesetExistedBefore
    GensetTargetPath = $gensetTargetPath
}

Write-Information "Running tests from: $testFile" -InformationAction Continue
Write-Host ""

# Run the tests
$result = Invoke-Pester -Configuration $config

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host " PHASE 3: Cleanup" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Cleanup catlet
if (-not $KeepVM) {
    Write-Information "Removing test catlet..." -InformationAction Continue
    try {
        Remove-Catlet -Id $catlet.Id -Force -ErrorAction SilentlyContinue
        Write-Information "Test catlet removed successfully" -InformationAction Continue
    }
    catch {
        Write-Warning "Could not remove test catlet: $_"
    }
} else {
    Write-Information "Keeping VM for debugging as requested (ID: $($catlet.Id))" -InformationAction Continue
}

# Cleanup genepool based on whether it existed before
if (-not $genesetExistedBefore -and (Test-Path $gensetTargetPath)) {
    # We created this geneset directory, so remove it completely
    Write-Information "Removing temporary test geneset directory from genepool" -InformationAction Continue
    try {
        Remove-Item $gensetTargetPath -Recurse -Force -ErrorAction Stop
        Write-Information "Temporary geneset directory removed successfully" -InformationAction Continue
    }
    catch {
        Write-Warning "Could not remove temporary geneset directory (may be in use): $_"
    }
}
elseif ($genesetExistedBefore) {
    # The geneset existed before, we only replaced its contents
    Write-Information "Geneset existed before test - leaving directory in place with test content" -InformationAction Continue
}

# Display summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Tests: $($result.TotalCount)" -ForegroundColor White
Write-Host "Passed: $($result.PassedCount)" -ForegroundColor Green
Write-Host "Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { "Red" } else { "Green" })
Write-Host "Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
Write-Host "Duration: $($result.Duration.TotalSeconds.ToString('F2'))s" -ForegroundColor Gray

# Save results if TestResults directory exists
$resultsDir = Join-Path $PSScriptRoot "TestResults"
if (Test-Path $resultsDir) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $resultsFile = Join-Path $resultsDir "PackedBaseCatlet_${Geneset.Replace('/','-')}_${timestamp}.xml"
    
    # Export results
    $result | Export-NUnitReport -Path $resultsFile
    Write-Information "Test results saved to: $resultsFile" -InformationAction Continue
}

# Exit with appropriate code for CI/CD
if ($result.FailedCount -gt 0) {
    exit 1
}
exit 0
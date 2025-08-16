# Test-FodderGene.ps1
# Orchestrator script for testing fodder genes across multiple base OS versions
# This script runs the Pester tests but is NOT itself a Pester test

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Fodder gene name (e.g., dbosoft/winget)")]
    [string]$Gene,
    
    [Parameter(Position=1, HelpMessage="Tag/version to test (defaults to 'latest')")]
    [string]$Tag = "latest",
    
    [Parameter(Mandatory=$true, HelpMessage="Base OS genesets to test against")]
    [string[]]$BaseOS,
    
    [Parameter(HelpMessage="Keep the VMs after testing for debugging")]
    [switch]$KeepVM,
    
    [Parameter(HelpMessage="Path to local genepool (auto-resolved if not specified)")]
    [string]$GenepoolPath
)

$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
$ProgressPreference = "SilentlyContinue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Testing Fodder Gene" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Gene:     $Gene$(if ($Tag -ne 'latest') { "/$Tag" })" -ForegroundColor White
Write-Host "Base OS:  $($BaseOS -join ', ')" -ForegroundColor White
Write-Host "Keep VMs: $($KeepVM.IsPresent)" -ForegroundColor White
Write-Host ""

# Resolve genepool path if not provided
if (-not $GenepoolPath) {
    Write-Host "Resolving genepool path..." -ForegroundColor Yellow
    
    # Check if we have a cached path
    $cachedPath = Join-Path $PSScriptRoot ".claude\genepool-path.txt"
    if (Test-Path $cachedPath) {
        $GenepoolPath = Get-Content $cachedPath -Raw | ForEach-Object { $_.Trim() }
        Write-Host "Using cached genepool path: $GenepoolPath" -ForegroundColor Green
    } else {
        # Try to resolve it
        $resolveScript = Join-Path $PSScriptRoot "Resolve-GenepoolPath.ps1"
        if (Test-Path $resolveScript) {
            Write-Host "Running genepool resolver (requires admin)..." -ForegroundColor Yellow
            try {
                $GenepoolPath = & $resolveScript
                
                # Cache the result
                $cacheDir = Join-Path $PSScriptRoot ".claude"
                if (-not (Test-Path $cacheDir)) {
                    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
                }
                Set-Content -Path $cachedPath -Value $GenepoolPath -Force
                Write-Host "Genepool path resolved and cached: $GenepoolPath" -ForegroundColor Green
            } catch {
                Write-Error "Failed to resolve genepool path. Please run as Administrator or provide -GenepoolPath"
                exit 1
            }
        } else {
            Write-Error "Cannot resolve genepool path. Please provide -GenepoolPath parameter"
            exit 1
        }
    }
}

# Verify genepool path exists
if (-not (Test-Path $GenepoolPath)) {
    Write-Error "Genepool path does not exist: $GenepoolPath"
    exit 1
}

Write-Host "Genepool: $GenepoolPath" -ForegroundColor White
Write-Host ""

# Check if running as administrator (required for egs-tool)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Warning "Not running as Administrator. Some operations may fail."
    Write-Warning "For best results, run PowerShell as Administrator."
    Write-Host ""
}

# Check if Pester 5 is available
$pester = Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } | Select-Object -First 1
if (-not $pester) {
    Write-Error "Pester 5.x or higher is required. Please install: Install-Module Pester -Force"
    exit 1
}

Write-Information "Using Pester $($pester.Version)" -InformationAction Continue

# Import Pester explicitly to ensure v5
Import-Module Pester -MinimumVersion 5.0 -Force

# Path to the actual test file
$testFile = Join-Path $PSScriptRoot "Test-FodderGene.Tests.ps1"

if (-not (Test-Path $testFile)) {
    Write-Error "Test file not found: $testFile"
    exit 1
}

# Configure Pester to run ONLY the test file, not auto-discover
$config = New-PesterConfiguration
$config.Run.Path = $testFile
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.Should.ErrorAction = 'Continue'

# Pass parameters to the test using TestData
$config.Run.Container = New-PesterContainer -Path $testFile -Data @{
    Gene = $Gene
    Tag = $Tag
    BaseOS = $BaseOS
    GenepoolPath = $GenepoolPath
    KeepVM = $KeepVM
}

Write-Information "Running tests from: $testFile" -InformationAction Continue
Write-Host ""

# Run the tests
$result = Invoke-Pester -Configuration $config

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
    $resultsFile = Join-Path $resultsDir "FodderGene_${Gene.Replace('/','-')}_${timestamp}.xml"
    
    # Export results
    $result | Export-NUnitReport -Path $resultsFile
    Write-Information "Test results saved to: $resultsFile" -InformationAction Continue
}

# Exit with appropriate code for CI/CD
if ($result.FailedCount -gt 0) {
    exit 1
}
exit 0
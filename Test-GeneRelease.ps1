# Test-GeneRelease.ps1
# Release testing orchestrator for fodder genes
# Runs tests for genes before publishing to genepool

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, ParameterSetName="Single")]
    [string]$GenesetTag,  # e.g., "dbosoft/winget/v1.2.3" or "dbosoft/winget/latest"
    
    [Parameter(Mandatory=$true, ParameterSetName="Batch")]
    [string[]]$GenesetTags,  # Multiple genes to test
    
    [Parameter(Mandatory=$true, ParameterSetName="BuildOutput")]
    [string]$BuildPath,  # Path to .packed folder after build
    
    [Parameter()]
    [switch]$KeepVM,  # Keep test VMs for debugging
    
    [Parameter()]
    [string]$GenepoolPath,  # Local genepool path (auto-resolved if not specified)
    
    [Parameter()]
    [switch]$StopOnFailure  # Stop testing if any gene fails
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Gene Release Testing" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Helper function to parse geneset tag
function Parse-GenesetTag {
    param([string]$Tag)
    
    $parts = $Tag -split '/'
    return @{
        Provider = if ($parts.Count -ge 1) { $parts[0] } else { "dbosoft" }
        Gene = if ($parts.Count -ge 2) { $parts[1] } else { throw "Gene name required" }
        Version = if ($parts.Count -ge 3) { $parts[2] } else { "latest" }
        Full = $Tag
    }
}

# Resolve genepool path if not provided
if (-not $GenepoolPath) {
    Write-Information "Resolving genepool path..."
    
    # Check for cached path
    $cachedPath = Join-Path $PSScriptRoot ".claude\genepool-path.txt"
    if (Test-Path $cachedPath) {
        $GenepoolPath = Get-Content $cachedPath -Raw | ForEach-Object { $_.Trim() }
        Write-Information "Using cached genepool path: $GenepoolPath"
    } else {
        # Try to resolve using script
        $resolveScript = Join-Path $PSScriptRoot "Resolve-GenepoolPath.ps1"
        if (Test-Path $resolveScript) {
            Write-Warning "Genepool path not found. Running resolver (requires admin)..."
            try {
                $GenepoolPath = & $resolveScript
                
                # Cache the path
                $cacheDir = Split-Path $cachedPath -Parent
                if (-not (Test-Path $cacheDir)) {
                    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
                }
                $GenepoolPath | Out-File $cachedPath -Encoding UTF8
                
                Write-Information "Resolved genepool path: $GenepoolPath"
            } catch {
                throw "Failed to resolve genepool path: $_"
            }
        } else {
            throw "Cannot resolve genepool path. Please provide -GenepoolPath parameter."
        }
    }
}

# Handle build output scenario
if ($BuildPath) {
    if (-not (Test-Path $BuildPath)) {
        throw "Build path not found: $BuildPath"
    }
    
    # Infer gene information from path
    # Expected structure: genes\{genename}\.packed\{tag}
    $pathParts = $BuildPath -split '[\\/]'
    $packIndex = $pathParts.IndexOf('.packed')
    
    if ($packIndex -lt 1) {
        throw "Invalid build path structure. Expected: genes\{genename}\.packed\{tag}"
    }
    
    $geneName = $pathParts[$packIndex - 1]
    $tag = if ($packIndex + 1 -lt $pathParts.Count) { $pathParts[$packIndex + 1] } else { "latest" }
    
    $GenesetTag = "dbosoft/$geneName/$tag"
    
    Write-Information "Testing built gene: $GenesetTag"
    Write-Information "Build path: $BuildPath"
    
    # Copy to local genepool for testing
    $targetPath = Join-Path $GenepoolPath "dbosoft\$geneName\$tag"
    Write-Information "Copying to local genepool: $targetPath"
    
    if (Test-Path $targetPath) {
        Write-Warning "Removing existing gene in genepool..."
        Remove-Item $targetPath -Recurse -Force
    }
    
    # Use xcopy for robust copying
    $xcopyArgs = @("/E", "/I", "/Y", "/Q")
    $result = xcopy $BuildPath $targetPath $xcopyArgs
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to copy gene to genepool"
    }
    
    Write-Information "Gene copied to local genepool successfully"
}

# Determine which genes to test
$tagsToTest = if ($GenesetTags) { 
    $GenesetTags 
} else { 
    @($GenesetTag) 
}

Write-Information "Genes to test: $($tagsToTest.Count)"
$tagsToTest | ForEach-Object { Write-Information "  - $_" }
Write-Host ""

# Track results
$results = @()
$allPassed = $true

# Test each gene
foreach ($tag in $tagsToTest) {
    $parsed = Parse-GenesetTag -Tag $tag
    
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host " Testing: $($parsed.Full)" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    
    # Find test file for this gene
    $testPath = Join-Path $PSScriptRoot "tests\fodder-genes\$($parsed.Gene)\Test-$($parsed.Gene).Tests.ps1"
    
    if (-not (Test-Path $testPath)) {
        Write-Warning "No tests found for $($parsed.Gene) at: $testPath"
        Write-Warning "Skipping gene: $($parsed.Full)"
        
        $results += [PSCustomObject]@{
            Gene = $parsed.Full
            Status = "Skipped"
            Passed = 0
            Failed = 0
            Duration = [TimeSpan]::Zero
            Error = "No test file found"
        }
        continue
    }
    
    Write-Information "Running tests from: $testPath"
    
    try {
        # Configure Pester
        $config = New-PesterConfiguration
        $config.Run.Path = $testPath
        $config.Run.PassThru = $true
        $config.Output.Verbosity = 'Detailed'
        $config.Should.ErrorAction = 'Continue'
        
        # Pass parameters via container
        $container = New-PesterContainer -Path $testPath -Data @{
            GeneTag = $parsed.Full
            KeepVM = $KeepVM
        }
        $config.Run.Container = $container
        
        # Run tests
        $testResult = Invoke-Pester -Configuration $config
        
        # Record results
        $results += [PSCustomObject]@{
            Gene = $parsed.Full
            Status = if ($testResult.FailedCount -eq 0) { "Passed" } else { "Failed" }
            Passed = $testResult.PassedCount
            Failed = $testResult.FailedCount
            Skipped = $testResult.SkippedCount
            Duration = $testResult.Duration
            Error = $null
        }
        
        if ($testResult.FailedCount -gt 0) {
            $allPassed = $false
            
            if ($StopOnFailure) {
                Write-Error "Test failed for $($parsed.Full). Stopping due to -StopOnFailure."
                break
            }
        }
        
    } catch {
        Write-Error "Failed to test $($parsed.Full): $_"
        
        $results += [PSCustomObject]@{
            Gene = $parsed.Full
            Status = "Error"
            Passed = 0
            Failed = 0
            Duration = [TimeSpan]::Zero
            Error = $_.ToString()
        }
        
        $allPassed = $false
        
        if ($StopOnFailure) {
            break
        }
    }
    
    Write-Host ""
}

# Display summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Release Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$totalPassed = ($results | Measure-Object -Property Passed -Sum).Sum
$totalFailed = ($results | Measure-Object -Property Failed -Sum).Sum
$totalSkipped = ($results | Measure-Object -Property Skipped -Sum).Sum

foreach ($result in $results) {
    $statusSymbol = switch ($result.Status) {
        "Passed" { "✓"; break }
        "Failed" { "✗"; break }
        "Skipped" { "⊘"; break }
        "Error" { "!"; break }
        default { "?"; break }
    }
    
    $color = switch ($result.Status) {
        "Passed" { "Green"; break }
        "Failed" { "Red"; break }
        "Skipped" { "Yellow"; break }
        "Error" { "Magenta"; break }
        default { "Gray"; break }
    }
    
    $message = "$statusSymbol $($result.Gene): "
    if ($result.Status -eq "Skipped" -or $result.Status -eq "Error") {
        $message += $result.Error
    } else {
        $message += "$($result.Passed) passed, $($result.Failed) failed"
        if ($result.Skipped -gt 0) {
            $message += ", $($result.Skipped) skipped"
        }
        $message += " ($($result.Duration.TotalSeconds.ToString('F2'))s)"
    }
    
    Write-Host $message -ForegroundColor $color
}

Write-Host ""
Write-Host "Total: $totalPassed passed, $totalFailed failed" -ForegroundColor $(if ($totalFailed -eq 0) { "Green" } else { "Red" })
if ($totalSkipped -gt 0) {
    Write-Host "       $totalSkipped skipped" -ForegroundColor Yellow
}

# Exit with appropriate code
if (-not $allPassed) {
    Write-Host ""
    Write-Error "Release testing failed. Do not publish these genes."
    exit 1
} else {
    Write-Host ""
    Write-Host "All tests passed! Genes are ready for release." -ForegroundColor Green
    exit 0
}
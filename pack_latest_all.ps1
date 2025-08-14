#Requires -Version 5.1

<#
.SYNOPSIS
    Packs all "latest" geneset tags found in the genes folder
.DESCRIPTION
    Searches for all geneset-tag.json files in "latest" folders and executes
    eryph-packer "geneset-tag pack <geneset-tag> --workdir genes" for each
#>

$ErrorActionPreference = "Stop"

# Get the script's directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$genesPath = Join-Path $scriptPath "genes"

Write-Host "Searching for latest geneset tags in: $genesPath" -ForegroundColor Cyan

# Find all geneset-tag.json files in "latest" folders
$latestTags = Get-ChildItem -Path $genesPath -Filter "geneset-tag.json" -Recurse | 
    Where-Object { $_.Directory.Name -eq "latest" }

if ($latestTags.Count -eq 0) {
    Write-Host "No latest geneset tags found." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($latestTags.Count) latest geneset tag(s):" -ForegroundColor Green
$latestTags | ForEach-Object {
    # Extract the geneset-tag path (e.g., dbosoft/winconfig/latest)
    $relativePath = $_.Directory.FullName.Replace("$genesPath\", "").Replace("\", "/")
    Write-Host "  - $relativePath" -ForegroundColor Gray
}

Write-Host "`nStarting pack operations..." -ForegroundColor Cyan

$successCount = 0
$failureCount = 0
$failures = @()

foreach ($tagFile in $latestTags) {
    # Extract the geneset-tag identifier (e.g., dbosoft/winconfig/latest)
    $relativePath = $tagFile.Directory.FullName.Replace("$genesPath\", "").Replace("\", "/")
    
    Write-Host "`nPacking: $relativePath" -ForegroundColor Yellow
    
    try {
        $arguments = @(
            "geneset-tag",
            "pack",
            $relativePath,
            "--workdir",
            "genes"
        )
        
        $result = & eryph-packer @arguments 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Successfully packed $relativePath" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "  ✗ Failed to pack $relativePath" -ForegroundColor Red
            Write-Host "    Error: $result" -ForegroundColor Red
            $failureCount++
            $failures += $relativePath
        }
    }
    catch {
        Write-Host "  ✗ Exception while packing $relativePath" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Red
        $failureCount++
        $failures += $relativePath
    }
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "Total geneset tags processed: $($latestTags.Count)" -ForegroundColor White
Write-Host "Successfully packed: $successCount" -ForegroundColor Green
Write-Host "Failed: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { "Red" } else { "Gray" })

if ($failures.Count -gt 0) {
    Write-Host "`nFailed geneset tags:" -ForegroundColor Red
    $failures | ForEach-Object {
        Write-Host "  - $_" -ForegroundColor Red
    }
    exit 1
}

Write-Host "`nAll latest geneset tags packed successfully!" -ForegroundColor Green
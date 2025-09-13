#Requires -Version 5.1

<#
.SYNOPSIS
    Checks ref consistency between local geneset-tag.json files and the genepool API
.DESCRIPTION
    Finds all geneset-tag.json files with a "ref" attribute and verifies that
    the reference matches what's published in the genepool API
#>

$ErrorActionPreference = "Stop"

# Get the script's directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$genesPath = Join-Path $scriptPath "genes"

$apiBaseUrl = "https://genepool-api.eryph.io/v1"

Write-Host "Checking ref consistency between local genes and genepool" -ForegroundColor Cyan
Write-Host "Searching in: $genesPath" -ForegroundColor Gray
Write-Host ""

# Find all geneset-tag.json files, excluding .packed folders
$tagFiles = Get-ChildItem -Path $genesPath -Filter "geneset-tag.json" -Recurse | 
    Where-Object { $_.FullName -notmatch "\.packed" }

if ($tagFiles.Count -eq 0) {
    Write-Host "No geneset-tag.json files found (excluding .packed folders)." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($tagFiles.Count) geneset-tag.json file(s) (excluding .packed folders)" -ForegroundColor Green

# Process each tag file
$tagsWithRef = @()
$mismatches = @()
$errorList = @()
$checkedCount = 0

foreach ($tagFile in $tagFiles) {
    try {
        # Read and parse the JSON file
        $content = Get-Content $tagFile.FullName -Raw | ConvertFrom-Json
        
        # Check if it has a ref attribute
        if ($content.ref) {
            # Extract the geneset path from the directory structure
            # e.g., genes\dbosoft\starter-food\latest -> dbosoft/starter-food/latest
            $relativePath = $tagFile.Directory.FullName.Replace("$genesPath\", "").Replace("\", "/")
            
            # Split to get geneset and tag
            $pathParts = $relativePath -split "/"
            if ($pathParts.Count -ge 3) {
                $org = $pathParts[0]
                $geneset = $pathParts[1]
                $tag = $pathParts[2]
                
                $genesetName = "$org/$geneset"
                $fullName = "$genesetName/$tag"
                
                $tagInfo = @{
                    FullName = $fullName
                    Geneset = $genesetName
                    Tag = $tag
                    LocalRef = $content.ref
                    FilePath = $tagFile.FullName
                }
                
                $tagsWithRef += $tagInfo
            }
        }
    }
    catch {
        Write-Host "  X Error reading $($tagFile.FullName): $_" -ForegroundColor Red
        $errorList += @{
            File = $tagFile.FullName
            Error = $_.ToString()
        }
    }
}

if ($tagsWithRef.Count -eq 0) {
    Write-Host "No geneset-tag.json files with 'ref' attribute found." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($tagsWithRef.Count) tag(s) with ref attribute" -ForegroundColor Green
Write-Host ""
Write-Host "Checking consistency with genepool API..." -ForegroundColor Cyan
Write-Host ""

foreach ($tagInfo in $tagsWithRef) {
    $checkedCount++
    Write-Host "[$checkedCount/$($tagsWithRef.Count)] Checking $($tagInfo.FullName)..." -ForegroundColor Gray
    
    try {
        # Build API URL
        $apiUrl = "$apiBaseUrl/genesets/$($tagInfo.Geneset)/tag/$($tagInfo.Tag)?expand=manifest"
        
        # Make API request
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -ErrorAction Stop
        
        if ($response.value -and $response.value.manifest -and $response.value.manifest.ref) {
            $remoteRef = $response.value.manifest.ref
            
            if ($tagInfo.LocalRef -eq $remoteRef) {
                Write-Host "  OK Consistent: ref = $($tagInfo.LocalRef)" -ForegroundColor Green
            }
            else {
                Write-Host "  X MISMATCH!" -ForegroundColor Red
                Write-Host "    Local:  $($tagInfo.LocalRef)" -ForegroundColor Yellow
                Write-Host "    Remote: $remoteRef" -ForegroundColor Yellow
                
                $mismatches += @{
                    Geneset = $tagInfo.FullName
                    LocalRef = $tagInfo.LocalRef
                    RemoteRef = $remoteRef
                    FilePath = $tagInfo.FilePath
                }
            }
        }
        elseif ($response.value -and $response.value.manifest -and -not $response.value.manifest.ref) {
            Write-Host "  ! Remote manifest has no ref (local: $($tagInfo.LocalRef))" -ForegroundColor Yellow
            $mismatches += @{
                Geneset = $tagInfo.FullName
                LocalRef = $tagInfo.LocalRef
                RemoteRef = "(no ref in remote)"
                FilePath = $tagInfo.FilePath
            }
        }
        else {
            Write-Host "  ! Unexpected API response structure" -ForegroundColor Yellow
            $errorList += @{
                File = $tagInfo.FilePath
                Error = "Unexpected API response structure"
            }
        }
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 'NotFound') {
            Write-Host "  ! Not found in genepool (local ref: $($tagInfo.LocalRef))" -ForegroundColor Yellow
            $errorList += @{
                File = $tagInfo.FilePath
                Error = "Geneset tag not found in genepool"
            }
        }
        else {
            Write-Host "  X API Error: $_" -ForegroundColor Red
            $errorList += @{
                File = $tagInfo.FilePath
                Error = $_.ToString()
            }
        }
    }
}

# Summary
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "Total geneset tags checked: $checkedCount" -ForegroundColor White
Write-Host "Consistent: $($checkedCount - $mismatches.Count - $errorList.Count)" -ForegroundColor Green
Write-Host "Mismatches: $($mismatches.Count)" -ForegroundColor $(if ($mismatches.Count -gt 0) { "Red" } else { "Gray" })
Write-Host "Errors: $($errorList.Count)" -ForegroundColor $(if ($errorList.Count -gt 0) { "Yellow" } else { "Gray" })

if ($mismatches.Count -gt 0) {
    Write-Host ""
    Write-Host "REF MISMATCHES:" -ForegroundColor Red
    Write-Host ("=" * 70) -ForegroundColor Red
    foreach ($mismatch in $mismatches) {
        Write-Host ""
        Write-Host "Geneset: $($mismatch.Geneset)" -ForegroundColor White
        Write-Host "  File:   $($mismatch.FilePath)" -ForegroundColor Gray
        Write-Host "  Local:  $($mismatch.LocalRef)" -ForegroundColor Yellow
        Write-Host "  Remote: $($mismatch.RemoteRef)" -ForegroundColor Yellow
    }
}

if ($errorList.Count -gt 0) {
    Write-Host ""
    Write-Host "ERRORS:" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor Yellow
    foreach ($err in $errorList) {
        Write-Host ""
        Write-Host "File: $($err.File)" -ForegroundColor White
        Write-Host "  Error: $($err.Error)" -ForegroundColor Gray
    }
}

if ($mismatches.Count -gt 0) {
    Write-Host ""
    Write-Host "! Found $($mismatches.Count) ref mismatch(es) between local files and genepool!" -ForegroundColor Red
    exit 1
}
elseif ($errorList.Count -gt 0) {
    Write-Host ""
    Write-Host "! Completed with $($errorList.Count) error(s)" -ForegroundColor Yellow
    exit 2
}
else {
    Write-Host ""
    Write-Host "OK All refs are consistent between local files and genepool!" -ForegroundColor Green
}
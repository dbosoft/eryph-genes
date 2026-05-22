[CmdletBinding()]
param (
    [Parameter(Mandatory=$False)]
    [string]
    $Filter,
    
    [Parameter(Mandatory=$true)]
    [string]
    $BuildPath
)
$InformationPreference= 'Continue'
$ErrorActionPreference = 'Stop'

Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' ERYPH GENES BUILD PROCESS' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

push-Location $PSScriptRoot

Write-Host 'PHASE 1: Initialization' -ForegroundColor Yellow
Write-Host '----------------------------------------' -ForegroundColor Yellow

Write-Information 'Loading import specifications from import.json...'
$importSpecs = Get-Content -Raw -Path 'import.json' | ConvertFrom-Json
$keys = $importSpecs | ForEach-Object { $_ | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name }
Write-Information ('Found ' + $keys.Count + ' templates in import.json')

Write-Information 'Resolving build path...'
$resolvedBuildPath = Resolve-Path $BuildPath
if((Test-Path $resolvedBuildPath -PathType Container) -eq $false)
{
    Write-Error ('Could not find build path: ' + $BuildPath)
    return
}
Write-Information ('Build path: ' + $resolvedBuildPath)

Write-Information 'Resolving genepool path...'
# Run in a child process so that powershell-yaml's YamlDotNet 13 (loaded by ConvertFrom-Yaml
# in Resolve-GenepoolPath.ps1) does not pin the parent AppDomain and conflict with
# YamlDotNet 16 required later by Eryph cmdlets (New-Catlet).
$GenepoolPath = powershell -NoProfile -File .\Resolve-GenepoolPath.ps1
Write-Information ('Genepool path: ' + $GenepoolPath)

Write-Information 'Locating build script...'
$BuildScript = Join-Path $resolvedBuildPath -ChildPath '..\build.ps1' -Resolve
Write-Information ('Build script: ' + $BuildScript)

Write-Host ''
Write-Host 'PHASE 2: Cleanup Previous Builds' -ForegroundColor Yellow
Write-Host '----------------------------------------' -ForegroundColor Yellow

$existingDirs = Get-ChildItem -Path $resolvedBuildPath -Directory -ErrorAction SilentlyContinue
if ($existingDirs) {
    Write-Information ('Removing ' + $existingDirs.Count + ' existing build directories...')
    $existingDirs | ForEach-Object {
        Write-Information ('  Removing: ' + $_.Name)
        Remove-Item $_.FullName -Recurse -ErrorAction Continue
    }
} else {
    Write-Information 'No existing build directories to clean'
}

Write-Host ''
Write-Host 'PHASE 3: Building Templates' -ForegroundColor Yellow
Write-Host '----------------------------------------' -ForegroundColor Yellow
try{
$templateCount = 0
$successCount = 0
$failedCount = 0

$keys | ForEach-Object {
    $importSpec = $importSpecs.$_
    $TemplateName = $_

    if($Filter -and $TemplateName -notlike $Filter){
        Write-Information ('  Skipping ' + $TemplateName + ' (filter: ' + $Filter + ')')
        return
    }

    $templateCount++
    $osType = $importSpec.osType
    
    Write-Host ''
    Write-Host '========================================' -ForegroundColor Magenta
    Write-Host (' TEMPLATE: ' + $TemplateName) -ForegroundColor Magenta
    Write-Host (' OS Type: ' + $osType) -ForegroundColor Magenta
    Write-Host '========================================' -ForegroundColor Magenta

    try{
        Write-Information 'Step 1: Building template with Packer...'
        & $BuildScript -Filter $TemplateName
        Write-Host '  OK Packer build completed' -ForegroundColor Green
        
        Set-Location $PSScriptRoot
        Write-Information 'Step 2: Packing build output...'
        $packed = .\.\pack_build.ps1 $TemplateName -BuildPath $resolvedBuildPath -RemoveBuild
        # pack_build.ps1 may emit progress before the final tag; the resolved tag is always the last item
        $genesetName = @($packed) | Select-Object -Last 1
        if([string]::IsNullOrWhiteSpace($genesetName)){
            throw "pack_build.ps1 did not return a resolved pack target"
        }
        Write-Host ('  OK Packed to: ' + $genesetName) -ForegroundColor Green
        
        Set-Location $PSScriptRoot
        Write-Information 'Step 3: Running validation tests...'
        .\test-PackedBaseCatlet.ps1 -Geneset $genesetName -GenepoolPath $GenepoolPath -OsType $osType
        Write-Host '  OK Tests passed' -ForegroundColor Green
        
        $successCount++
        Write-Host ('OK ' + $TemplateName + ' completed successfully') -ForegroundColor Green
    }catch{
        $failedCount++
        $ErrorActionPreference = 'Continue'
        Write-Host ('X ' + $TemplateName + ' failed: ' + $_) -ForegroundColor Red
        Write-Error $_ 
        $ErrorActionPreference = 'Stop'
    }
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' BUILD SUMMARY' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ('Total Templates: ' + $templateCount) -ForegroundColor White
Write-Host ('OK Successful: ' + $successCount) -ForegroundColor Green
if ($failedCount -gt 0) {
    Write-Host ('X Failed: ' + $failedCount) -ForegroundColor Red
}
Write-Host '========================================' -ForegroundColor Cyan

}finally{
    pop-Location
}

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

push-Location $PSScriptRoot
$importSpecs = Get-Content -Raw -Path "import.json" | ConvertFrom-Json
$keys = $importSpecs | ForEach-Object { $_ | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name }

$resolvedBuildPath = Resolve-Path $BuildPath
$GenepoolPath = .\.\Resolve-GenepoolPath.ps1
Write-Host "Genepool path: $GenepoolPath"

if((Test-Path $resolvedBuildPath -PathType Container) -eq $false)
{
    Write-Information "Could not find build path $BuildPath" -ForegroundColor 
    return
}

Write-Host "Resolved build path: $resolvedBuildPath"

$BuildScript = Join-Path $resolvedBuildPath -ChildPath "..\build.ps1" -Resolve
Get-ChildItem -Path $resolvedBuildPath -Directory | ForEach-Object {
    Write-Warning "Removing $_"
    $fullName = $_.FullName
    Remove-Item $fullName -Recurse -ErrorAction Continue
}

Write-Host "Build script path: $BuildScript"
try{
$keys | ForEach-Object {
    $importSpec = $importSpecs.$_
    $TemplateName = $_

    if($Filter -and $TemplateName -notlike $Filter){
        return
    }

    $osType = $importSpec.osType

    & $BuildScript -Filter $TemplateName
    Set-Location $PSScriptRoot
    .\.\pack_build.ps1 $TemplateName -BuildPath $resolvedBuildPath -RemoveBuild
    .\.\test-packed.ps1 -Geneset $TemplateName -GenepoolPath $GenepoolPath -OsType $osType
}
}finally{
    pop-Location
}

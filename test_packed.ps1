[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]
    $Geneset,

    [Parameter(Mandatory=$true)]
    [string] $GenepoolPath
)
$InformationPreference= 'Continue'
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

$geneSource = Join-Path $PSScriptRoot "genes" -Resolve
$GenesetSourcePath = Join-Path $geneSource $Geneset.Replace('/', '\')
$GenesetPackagedPath = Join-Path $GenesetSourcePath ".packed" -Resolve

Write-Host "Geneset source path: $GenesetPackagedPath"

$gensetTargetPath = Join-Path $GenepoolPath $Geneset.Replace('/', '\')

if((Test-Path $gensetTargetPath) -eq $false) {
    New-Item -ItemType Directory -Path $gensetTargetPath | Out-Null
}

Write-Host "Geneset target path: $gensetTargetPath"
Copy-Item $GenesetPackagedPath\*  -Destination $gensetTargetPath -Force -Recurse

$template = Get-Content tests\windows.yaml

Get-Catlet | Where-Object Name -eq catlettest-windows | Remove-Catlet -Force
$cutTemplate = $template.Replace("{{cut}}", $Geneset)
$cut = $cutTemplate | New-Catlet -Verbose
$cut | Start-Catlet
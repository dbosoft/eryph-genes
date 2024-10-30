
Push-Location $PSScriptRoot

$InformationPreference= 'Continue'
$packedGenesets = Get-ChildItem -Recurse -Directory | where { $_.Name -eq '.packed' } | Resolve-Path


$packedGenesets | ForEach-Object {

    $packedGenesets = $_

    Remove-Item $packedGenesets -Recurse
}
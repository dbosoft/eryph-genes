
Push-Location $PSScriptRoot

$InformationPreference= 'Continue'
$packedGenesets = Get-ChildItem -Recurse -Directory | where { $_.Name -eq '.packed' -or $_.Name -eq '.pack' } | Resolve-Path


$packedGenesets | ForEach-Object {

    $packedGenesets = $_

    Remove-Item $packedGenesets -Recurse
}


[CmdletBinding()]
param ()
$InformationPreference= 'Continue'
$ErrorActionPreference = 'Stop'

$volumePath =(& eryph-zero.exe agentsettings get | ConvertFrom-Yaml).Defaults.volumes
$genepoolPath = Join-Path $volumePath genepool

if(-not (Test-Path $genepoolPath)){
    Write-Error "Genepool path not found: $genepoolPath"
    exit 1
}

$genepoolPath
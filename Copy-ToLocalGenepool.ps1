# Copy-ToLocalGenepool.ps1
# Copies a built geneset tag (genes\<org>\<geneset>\<tag>\.packed) into the local
# eryph-zero genepool (<genepool>\<org>\<geneset>\<tag>), so catlets can use it
# without pushing it to the public genepool.
#
# Gene folders for architectures the local genepool cannot hold (anything but
# "any" and hyperv/*) are skipped, like the client does when downloading;
# eryph-zero rejects the whole genepool when such a gene is materialized.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Geneset tag, e.g. dbosoft/powershell/next (a local build always packs tag next)")]
    [string]$Geneset,

    [Parameter(HelpMessage="Local genepool path (default: cached .claude\genepool-path.txt, else Resolve-GenepoolPath.ps1)")]
    [string]$GenepoolPath
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

if (($Geneset -split '/').Count -ne 3) {
    throw "-Geneset must be org/geneset/tag, got '$Geneset'"
}

if (-not $GenepoolPath) {
    $cachedPath = Join-Path $PSScriptRoot ".claude\genepool-path.txt"
    if (Test-Path $cachedPath) {
        $GenepoolPath = (Get-Content $cachedPath -Raw).Trim()
    } else {
        $GenepoolPath = & (Join-Path $PSScriptRoot "Resolve-GenepoolPath.ps1")
        New-Item -ItemType Directory -Path (Split-Path $cachedPath -Parent) -Force | Out-Null
        Set-Content -Path $cachedPath -Value $GenepoolPath
    }
}

$packedPath = Join-Path $PSScriptRoot "genes\$($Geneset.Replace('/', '\'))\.packed"
$targetPath = Join-Path $GenepoolPath $Geneset.Replace('/', '\')

if (-not (Test-Path $packedPath)) {
    throw "Packed geneset not found at $packedPath. Build it first (turbo build --filter=<package>)."
}

if (Test-Path $targetPath) {
    Remove-Item "$targetPath\*" -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
}

$manifest = Get-Content (Join-Path $packedPath 'geneset-tag.json') -Raw | ConvertFrom-Json
$skipped = @($manifest.volumes | Where-Object { $_ -and $_.arch -ne 'any' -and $_.arch -notlike 'hyperv/*' })
$skippedHashes = @($skipped | ForEach-Object { $_.hash -replace '^sha256:', '' })
foreach ($volume in $skipped) {
    Write-Information "Skipping $($volume.name) ($($volume.arch)): not supported by the local genepool"
}

Get-ChildItem $packedPath -Force |
    Where-Object { $skippedHashes -notcontains $_.Name } |
    ForEach-Object { Copy-Item $_.FullName -Destination $targetPath -Recurse -Force }

Write-Information "Copied $Geneset to $targetPath"

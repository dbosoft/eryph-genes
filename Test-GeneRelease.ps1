# Test-GeneRelease.ps1
# Release gate for fodder genes: runs Test-FodderGene.ps1 for each geneset tag
# before it is published. With -FromBuild the freshly built tag
# (genes\<org>\<geneset>\<tag>\.packed) is copied into the local genepool first,
# so the test runs against the build and not against the published version.
# Run as Administrator.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Geneset tags, e.g. dbosoft/winget/1.1")]
    [string[]]$GenesetTag,

    [Parameter(HelpMessage="Copy each tag's .packed build output into the local genepool before testing")]
    [switch]$FromBuild,

    [string]$GenepoolPath,

    [switch]$KeepVM,

    [switch]$StopOnFailure
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Test-FodderGene.ps1 ends with `exit`, so it runs in its own process.
$powershell = (Get-Process -Id $PID).Path
$results = @()

foreach ($tag in $GenesetTag) {
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host " Testing: $tag" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow

    $status = 'Failed'
    $started = Get-Date
    try {
        if ($FromBuild) {
            $copyArgs = @{ Geneset = $tag }
            if ($GenepoolPath) { $copyArgs.GenepoolPath = $GenepoolPath }
            & (Join-Path $PSScriptRoot 'Copy-ToLocalGenepool.ps1') @copyArgs
        }

        $testArgs = @('-NoProfile', '-File', (Join-Path $PSScriptRoot 'Test-FodderGene.ps1'), '-Gene', $tag)
        if ($KeepVM) { $testArgs += '-KeepVM' }
        & $powershell @testArgs
        if ($LASTEXITCODE -eq 0) { $status = 'Passed' }
    }
    catch {
        Write-Warning "Testing $tag failed: $_"
    }

    $results += [PSCustomObject]@{ Gene = $tag; Status = $status; Duration = (Get-Date) - $started }
    if ($status -ne 'Passed' -and $StopOnFailure) {
        break
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Release Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$results | Format-Table Gene, Status, @{ n = 'Duration'; e = { $_.Duration.ToString('hh\:mm\:ss') } } -AutoSize | Out-String | Write-Host

if ($results.Count -lt $GenesetTag.Count -or ($results | Where-Object Status -ne 'Passed')) {
    Write-Host "Release testing failed. Do not publish these genes." -ForegroundColor Red
    exit 1
}
Write-Host "All tests passed." -ForegroundColor Green
exit 0

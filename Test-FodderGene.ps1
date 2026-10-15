# Test-FodderGene.ps1
# Orchestrator for fodder gene tests. Runs every suite of
# tests/fodder-genes/<geneset>/test-matrix.psd1 on each base OS of the suite:
# deploys the suite's catlet, waits until provisioning finished, then runs the
# host checks and in-VM Pester tests (Test-FodderGene.Tests.ps1) against it.
# Deployment happens here and not inside Pester, so a failed deployment is
# reported as such instead of skipping every test.
# See tests/README.md for the test-matrix format.

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Fodder geneset, e.g. dbosoft/winget or dbosoft/winget/1.1")]
    [string]$Gene,

    [Parameter(HelpMessage="Tag to test (default: the tag in -Gene, else latest)")]
    [string]$Tag,

    [Parameter(HelpMessage="Base OS genesets to test on, e.g. winsrv2022-standard (default: OSMatrix of each suite)")]
    [string[]]$BaseOS,

    [Parameter(HelpMessage="Only run these suites (names from test-matrix.psd1)")]
    [string[]]$Suite,

    [Parameter(HelpMessage="Minutes to wait for the fodder to finish running")]
    [int]$ProvisioningTimeoutMinutes = 30,

    [Parameter(HelpMessage="Keep the catlets after testing for debugging")]
    [switch]$KeepVM
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# `pwsh -File` passes "a,b" as one string; accept comma-separated lists too
$Suite = @($Suite | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$BaseOS = @($BaseOS | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

$parts = $Gene -split '/'
if ($parts.Count -lt 2 -or $parts.Count -gt 3) {
    throw "-Gene must be org/geneset or org/geneset/tag, got '$Gene'"
}
if ($parts.Count -eq 3) {
    if (-not $Tag) { $Tag = $parts[2] }
    $Gene = "$($parts[0])/$($parts[1])"
}
$geneset = $parts[1]
$geneRef = if ($Tag) { "$Gene/$Tag" } else { $Gene }

$testRoot = Join-Path $PSScriptRoot "tests\fodder-genes\$geneset"
$matrixPath = Join-Path $testRoot "test-matrix.psd1"
if (-not (Test-Path $matrixPath)) {
    throw "No test matrix for $Gene at $matrixPath. Create one as described in tests/README.md."
}
$matrix = Import-PowerShellDataFile $matrixPath

$suites = @($matrix.TestSuites | Where-Object { -not $Suite -or $Suite -contains $_.Name })
if ($suites.Count -eq 0) {
    throw "No suite in $matrixPath matches: $($Suite -join ', ')"
}

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    throw "Run as Administrator: the tests reach the catlets through host-side egs-tool (Hyper-V socket)."
}

$pester = Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 } | Sort-Object Version -Descending | Select-Object -First 1
if (-not $pester) {
    throw "Pester 5.x or higher is required: Install-Module Pester -Force"
}
Import-Module $pester.Path -Force
Import-Module (Join-Path $PSScriptRoot "tests\EryphTestHelpers.psm1") -Force

$testFile = Join-Path $PSScriptRoot "Test-FodderGene.Tests.ps1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Testing Fodder Gene $geneRef" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Suites:   $($suites.Name -join ', ')"
Write-Host "Pester:   $($pester.Version)"
Write-Host "Keep VMs: $($KeepVM.IsPresent)"
Write-Host ""

$runs = @()

foreach ($testSuite in $suites) {
    $osList = if ($BaseOS) { $BaseOS } else { @($testSuite.OSMatrix) }

    foreach ($os in $osList) {
        $osType = Get-OsTypeForGeneset -Geneset $os
        $label = "$($testSuite.Name) on $os"
        Write-Host "----- $label -----" -ForegroundColor Yellow

        $run = [ordered]@{ Suite = $testSuite.Name; OS = $os; Status = 'Failed'; Passed = 0; Failed = 0; Error = $null }
        $catlet = $null

        try {
            $specPath = Join-Path $testRoot $testSuite.CatletSpec
            if (-not (Test-Path $specPath)) {
                throw "Catlet spec not found: $specPath"
            }

            # Short unique name: it also becomes the hostname, and Windows
            # computer names are limited to 15 characters.
            $shortGene = ($geneset -replace '[^a-zA-Z0-9]', '')
            $shortGene = $shortGene.Substring(0, [Math]::Min(6, $shortGene.Length))
            $catletName = "ft-$shortGene-$('{0:x4}' -f (Get-Random -Maximum 65535))"

            $yaml = (Get-Content $specPath -Raw).Replace('{{GENE_TAG}}', $geneRef).Replace('{{GENE}}', $geneRef).Replace('{{OS_VERSION}}', $os)
            $yaml = if ($yaml -match '(?m)^name:') {
                $yaml -replace '(?m)^name:.*$', "name: $catletName"
            } else {
                "name: $catletName`n$yaml"
            }
            Write-Verbose "Catlet YAML:`n$yaml"

            Write-Information "Deploying catlet $catletName"
            $catlet = $yaml | New-Catlet -SkipVariablesPrompt
            if (-not $catlet) {
                throw "New-Catlet returned no catlet"
            }
            Write-Information "Catlet $($catlet.Id) (VmId $($catlet.VmId))"

            if (-not (Initialize-EGSConnection -VmId $catlet.VmId)) {
                throw "egs-tool add-ssh-config failed for VmId $($catlet.VmId)"
            }

            Start-Catlet -Id $catlet.Id -Force | Out-Null

            if (-not (Wait-EGSReady -VmId $catlet.VmId -TimeoutMinutes 10)) {
                throw "Guest services did not become available within 10 minutes"
            }

            Write-Information "Waiting for provisioning to finish (up to $ProvisioningTimeoutMinutes minutes)"
            $provisioning = Wait-ProvisioningComplete -VmId $catlet.VmId -OsType $osType -TimeoutMinutes $ProvisioningTimeoutMinutes

            $config = New-PesterConfiguration
            $config.Run.PassThru = $true
            $config.Output.Verbosity = 'Detailed'
            $config.Should.ErrorAction = 'Continue'
            $config.Run.Container = New-PesterContainer -Path $testFile -Data @{
                Gene = $geneRef
                SuiteName = $testSuite.Name
                OsVersion = $os
                OsType = $osType
                CatletId = $catlet.Id
                VmId = $catlet.VmId
                Provisioning = $provisioning
                # @($null) has Count 1, so drop the null a missing key yields
                HostTests = @($testSuite.HostTests | Where-Object { $_ })
                InVMTests = @($testSuite.InVMTests | Where-Object { $_ })
                GeneTestPath = $testRoot
            }

            $result = Invoke-Pester -Configuration $config
            $run.Passed = $result.PassedCount
            $run.Failed = $result.FailedCount
            $run.Status = if ($result.FailedCount -eq 0 -and $result.PassedCount -gt 0) { 'Passed' } else { 'Failed' }
        }
        catch {
            $run.Error = "$_"
            Write-Warning "$label failed: $_"
        }
        finally {
            if ($catlet) {
                if ($run.Status -ne 'Passed') {
                    $diagPath = Join-Path $PSScriptRoot "diagnostics\$(Get-Date -Format 'yyyyMMdd_HHmmss')_${geneset}_$($testSuite.Name)_$($os -replace '[\\/:]', '-')"
                    try {
                        Save-ProvisioningDiagnostics -VmId $catlet.VmId -OsType $osType -OutputPath $diagPath
                    } catch {
                        Write-Warning "Could not save diagnostics: $_"
                    }
                }

                if ($KeepVM) {
                    Write-Information "Keeping catlet $($catlet.Name) (ID: $($catlet.Id))"
                } else {
                    Remove-Catlet -Id $catlet.Id -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }

        $runs += [PSCustomObject]$run
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Test Summary: $geneRef" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$runs | Format-Table Suite, OS, Status, Passed, Failed, Error -AutoSize | Out-String -Width 200 | Write-Host

if ($runs | Where-Object Status -ne 'Passed') {
    exit 1
}
exit 0

# vm-runner.ps1
# Runs Pester inside a catlet. Uploaded by Test-FodderGene.Tests.ps1 together with
# Pester and the gene's in-VM test files; works with Windows PowerShell and pwsh.
param(
    [Parameter(Mandatory=$true)]
    [string]$PesterPath,

    [Parameter(Mandatory=$true)]
    [string]$TestPath
)

$ErrorActionPreference = 'Stop'
Import-Module $PesterPath -Force

$config = New-PesterConfiguration
$config.Run.Path = $TestPath
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $config

Write-Host ''
Write-Host "Test Summary: Total=$($result.TotalCount) Passed=$($result.PassedCount) Failed=$($result.FailedCount)"
exit $result.FailedCount

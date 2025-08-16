# Test runner script for in-VM Pester tests
param([string]$TestPattern = '*.Tests.ps1')
$ErrorActionPreference = 'Stop'

# Import Pester from known location
Import-Module 'C:\Tests\Pester' -Force

# Configure and run tests
$config = New-PesterConfiguration
$config.Run.Path = "C:\Tests\validation\$TestPattern"
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $config

# Display summary
Write-Host ""
Write-Host "Test Summary: Total=$($result.TotalCount) Passed=$($result.PassedCount) Failed=$($result.FailedCount)"

if ($result.FailedCount -gt 0) {
    Write-Host "Failed tests:"
    $result.Failed | ForEach-Object { Write-Host "  - $($_.ExpandedPath)" }
}

exit $result.FailedCount
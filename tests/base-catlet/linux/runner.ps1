# Test runner script for in-VM Pester tests on Linux
param([string]$TestPattern = '*.Tests.ps1')
$ErrorActionPreference = 'Stop'

# Import Pester from known location
Import-Module '/tmp/tests/Pester' -Force

# Configure and run tests
$config = New-PesterConfiguration
$config.Run.Path = "/tmp/tests/validation/$TestPattern"
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
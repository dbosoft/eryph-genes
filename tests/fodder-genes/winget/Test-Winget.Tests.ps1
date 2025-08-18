# Test-Winget.Tests.ps1
# Main orchestrator for winget fodder gene testing
# Uses standardized test runner to minimize boilerplate

param(
    [Parameter(Mandatory=$true)]
    [string]$GeneTag,  # Full gene tag like "dbosoft/winget/latest" or "dbosoft/winget/v1.2.3"
    
    [switch]$KeepVM    # Keep VMs after testing for debugging
)

# Use the standardized fodder gene test runner
$runner = Join-Path $PSScriptRoot "..\..\Invoke-FodderGeneTest.ps1"
& $runner -GeneTag $GeneTag -GeneName "winget" -KeepVM:$KeepVM
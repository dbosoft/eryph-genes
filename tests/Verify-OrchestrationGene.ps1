# Verification script for the orchestration test gene
# This script tests the gene locally after deployment

param(
    [Parameter(Mandatory = $true)]
    [string]$CatletId
)

Write-Host "Verifying orchestration test gene deployment..." -ForegroundColor Green

# Wait for catlet to be fully started
Write-Host "Waiting for catlet to be ready for SSH access..."
Start-Sleep -Seconds 30

# Test SSH access and verify test files were created
$testCommands = @(
    "Test-Path 'C:\OrchestrationTest'"
    "Test-Path 'C:\OrchestrationTest\test-results.txt'"
    "Test-Path 'C:\OrchestrationTest\verification.txt'"
    "Get-Content 'C:\OrchestrationTest\test-results.txt'"
    "Get-Content 'C:\OrchestrationTest\verification.txt'"
)

foreach ($command in $testCommands) {
    Write-Host "Running: $command" -ForegroundColor Yellow
    # Note: Actual SSH execution would be handled by egs-executor
    Write-Host "  Command prepared for egs-executor" -ForegroundColor Gray
}

Write-Host "`nVerification commands prepared. Use egs-executor to run these tests:" -ForegroundColor Green
Write-Host "1. First run: setup-egs with catlet ID" -ForegroundColor Cyan
Write-Host "2. Then run each test command via: run-ssh" -ForegroundColor Cyan
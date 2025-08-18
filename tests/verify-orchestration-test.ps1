# PowerShell script to verify the orchestration test fodder executed correctly
# This script should be run via SSH after deploying a catlet with the test gene

param(
    [string]$ExpectedEnvironment = "production",
    [string]$ExpectedMessage = "Gene extraction successful!"
)

Write-Host "Verifying orchestration test execution..." -ForegroundColor Yellow

# Check if test directory exists
$testDir = "C:\OrchestrationTest"
if (-not (Test-Path $testDir)) {
    Write-Error "Test directory not found at $testDir"
    exit 1
}

# Check test results file
$resultsFile = "$testDir\test-results.txt"
if (-not (Test-Path $resultsFile)) {
    Write-Error "Test results file not found at $resultsFile"
    exit 1
}

# Read and parse results
$results = Get-Content $resultsFile -Raw
Write-Host "Test results content:" -ForegroundColor Green
Write-Host $results

# Verify expected values
if ($results -notmatch "Environment: $ExpectedEnvironment") {
    Write-Error "Environment variable not substituted correctly. Expected: $ExpectedEnvironment"
    exit 1
}

if ($results -notmatch "Message: $ExpectedMessage") {
    Write-Error "Test message variable not substituted correctly. Expected: $ExpectedMessage"
    exit 1
}

# Check verification file
$verificationFile = "$testDir\verification.txt"
if (-not (Test-Path $verificationFile)) {
    Write-Error "Verification file not found at $verificationFile"
    exit 1
}

Write-Host "✓ All verification checks passed!" -ForegroundColor Green
Write-Host "✓ Test directory created successfully" -ForegroundColor Green
Write-Host "✓ Variables substituted correctly" -ForegroundColor Green
Write-Host "✓ PowerShell script executed successfully" -ForegroundColor Green

exit 0
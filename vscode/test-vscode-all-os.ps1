# test-vscode-all-os.ps1
# Automated testing script for VS Code installation across different Windows versions

param(
    [switch]$SkipDeploy,
    [switch]$SkipVerify,
    [switch]$CleanupAfter
)

# Test matrix with OS variants
$testMatrix = @(
    @{
        Name = "win2019"
        Parent = "dbosoft/winsrv2019-standard/starter"
        ExpectedMethod = "Chocolatey"
        ExpectedBuild = 17763
    },
    @{
        Name = "win10"
        Parent = "dbosoft/win10-20h2-enterprise/starter"
        ExpectedMethod = "Winget"
        ExpectedBuild = 19042
    },
    @{
        Name = "win11"
        Parent = "dbosoft/win11-24h2-enterprise/starter"
        ExpectedMethod = "Winget"
        ExpectedBuild = 22631
    }
)

# Function to wait for cloud-init completion
function Wait-CloudInit {
    param(
        [string]$CatletId,
        [int]$MaxWaitMinutes = 15
    )
    
    Write-Host "Waiting for cloud-init to complete on catlet $CatletId..."
    $startTime = Get-Date
    $timeout = $startTime.AddMinutes($MaxWaitMinutes)
    
    while ((Get-Date) -lt $timeout) {
        try {
            # Try to SSH and check cloud-init status
            $result = ssh "$CatletId.eryph.alt" "powershell -Command 'Get-Content C:\ProgramData\cloudbase-init\log\cloudbase-init.log | Select-String -Pattern \"execution finished\" -Quiet'" 2>$null
            
            if ($result -eq "True") {
                Write-Host "Cloud-init completed successfully"
                return $true
            }
        } catch {
            # SSH might not be ready yet
        }
        
        Write-Host "Waiting for cloud-init... ($(([DateTime]::Now - $startTime).ToString('mm\:ss')))"
        Start-Sleep -Seconds 10
    }
    
    Write-Warning "Timeout waiting for cloud-init after $MaxWaitMinutes minutes"
    return $false
}

# Function to verify VS Code installation via SSH
function Test-VSCodeInstallation {
    param(
        [string]$CatletId,
        [string]$ExpectedMethod,
        [string]$OSName
    )
    
    Write-Host "`nVerifying VS Code installation on $OSName..."
    
    $results = @{
        OSName = $OSName
        VSCodeInstalled = $false
        InstallMethod = "Unknown"
        VSCodePath = ""
        VSCodeVersion = ""
        WingetPresent = $false
        ChocolateyPresent = $false
    }
    
    try {
        # Check if VS Code is installed
        $vscodeCheck = ssh "$CatletId.eryph.alt" @"
powershell -Command "
    `$paths = @(
        'C:\Program Files\Microsoft VS Code\Code.exe',
        'C:\Program Files (x86)\Microsoft VS Code\Code.exe',
        '\${env:LOCALAPPDATA}\Programs\Microsoft VS Code\Code.exe'
    )
    foreach (`$path in `$paths) {
        if (Test-Path `$path) {
            Write-Output `$path
            break
        }
    }
"
"@
        
        if ($vscodeCheck) {
            $results.VSCodeInstalled = $true
            $results.VSCodePath = $vscodeCheck.Trim()
            
            # Get VS Code version
            $version = ssh "$CatletId.eryph.alt" "powershell -Command '& \"$($results.VSCodePath)\" --version | Select-Object -First 1'"
            $results.VSCodeVersion = $version.Trim()
        }
        
        # Check if winget is present
        $wingetCheck = ssh "$CatletId.eryph.alt" "powershell -Command 'Get-Command winget -ErrorAction SilentlyContinue | Out-String'"
        $results.WingetPresent = ($wingetCheck -ne "")
        
        # Check if Chocolatey is present
        $chocoCheck = ssh "$CatletId.eryph.alt" "powershell -Command 'Get-Command choco -ErrorAction SilentlyContinue | Out-String'"
        $results.ChocolateyPresent = ($chocoCheck -ne "")
        
        # Determine installation method from logs
        $installLog = ssh "$CatletId.eryph.alt" "powershell -Command 'Get-Content C:\ProgramData\cloudbase-init\log\cloudbase-init-unattend.log | Select-String -Pattern \"VS Code successfully installed via\" | Select-Object -Last 1'"
        
        if ($installLog -match "winget") {
            $results.InstallMethod = "Winget"
        } elseif ($installLog -match "Chocolatey") {
            $results.InstallMethod = "Chocolatey"
        }
        
        # Display results
        Write-Host "Results for $($results.OSName):"
        Write-Host "  VS Code Installed: $($results.VSCodeInstalled)"
        Write-Host "  VS Code Path: $($results.VSCodePath)"
        Write-Host "  VS Code Version: $($results.VSCodeVersion)"
        Write-Host "  Installation Method: $($results.InstallMethod)"
        Write-Host "  Winget Present: $($results.WingetPresent)"
        Write-Host "  Chocolatey Present: $($results.ChocolateyPresent)"
        Write-Host "  Expected Method: $ExpectedMethod"
        
        if ($results.InstallMethod -eq $ExpectedMethod) {
            Write-Host "  ✓ Installation method matches expected" -ForegroundColor Green
        } else {
            Write-Warning "  ✗ Installation method mismatch! Expected: $ExpectedMethod, Got: $($results.InstallMethod)"
        }
        
    } catch {
        Write-Error "Failed to verify installation: $_"
    }
    
    return $results
}

# Main execution
$allResults = @()

if (!$SkipDeploy) {
    Write-Host "=== Starting VS Code Multi-OS Testing ===" -ForegroundColor Cyan
    Write-Host "Reading template file..."
    
    # Read template
    if (!(Test-Path "test-vscode-template.yaml")) {
        Write-Error "Template file 'test-vscode-template.yaml' not found!"
        exit 1
    }
    
    $template = Get-Content "test-vscode-template.yaml" -Raw
    
    # Get EGS key once
    Write-Host "Getting EGS SSH key..."
    # IMPORTANT: Replace line breaks with EMPTY STRING, not space!
    $egsKey = (egs-tool.exe get-ssh-key | Out-String).Replace("`r`n", "").Trim()
    
    if (!$egsKey) {
        Write-Error "Failed to get EGS SSH key!"
        exit 1
    }
    
    # Deploy each OS variant
    foreach ($test in $testMatrix) {
        Write-Host "`n=== Deploying VS Code on $($test.Name) ===" -ForegroundColor Yellow
        Write-Host "Parent: $($test.Parent)"
        Write-Host "Expected Build: $($test.ExpectedBuild)"
        Write-Host "Expected Installation Method: $($test.ExpectedMethod)"
        
        # Replace placeholders
        $catletYaml = $template -replace '{{ os_variant }}', $test.Name
        $catletYaml = $catletYaml -replace '{{ parent }}', $test.Parent
        
        # Save temporary YAML for debugging
        $tempFile = "temp-test-vscode-$($test.Name).yaml"
        $catletYaml | Out-File -FilePath $tempFile -Encoding UTF8
        
        Write-Host "Deploying catlet..."
        try {
            # Deploy catlet
            $catletYaml | New-Catlet -Variables @{ egskey = $egsKey } -SkipVariablesPrompt
            
            # Get the catlet ID
            $catlet = Get-Catlet | Where-Object { $_.Name -eq "test-vscode-$($test.Name)" } | Select-Object -First 1
            
            if ($catlet) {
                Write-Host "Catlet deployed successfully. ID: $($catlet.Id)"
                
                # Start the catlet if not already running
                if ($catlet.State -ne "Running") {
                    Write-Host "Starting catlet..."
                    $catlet | Start-Catlet -Force
                    Start-Sleep -Seconds 30  # Give it time to boot
                }
                
                # Update SSH config
                Write-Host "Updating SSH config..."
                egs-tool.exe update-ssh-config
                
                # Wait for cloud-init
                if (Wait-CloudInit -CatletId $catlet.Id) {
                    if (!$SkipVerify) {
                        # Verify installation
                        $result = Test-VSCodeInstallation -CatletId $catlet.Id -ExpectedMethod $test.ExpectedMethod -OSName $test.Name
                        $allResults += $result
                    }
                } else {
                    Write-Warning "Cloud-init did not complete in time for $($test.Name)"
                }
                
            } else {
                Write-Warning "Failed to find deployed catlet for $($test.Name)"
            }
            
        } catch {
            Write-Error "Failed to deploy $($test.Name): $_"
        }
        
        # Clean up temp file
        if (Test-Path $tempFile) {
            Remove-Item $tempFile
        }
    }
}

# Generate summary report
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan

$report = @'
# VS Code Installation Test Results

Date: {0}

## Test Matrix

| OS Version | Expected Method | VS Code Installed | Actual Method | Winget | Chocolatey | Result |
|------------|-----------------|-------------------|---------------|--------|------------|---------|'
$report = $report -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

for ($i = 0; $i -lt $allResults.Count; $i++) {
    $result = $allResults[$i]
    $test = $testMatrix[$i]
    $status = if ($result.VSCodeInstalled -and ($result.InstallMethod -eq $test.ExpectedMethod)) { "✓" } else { "✗" }
    $wingetStatus = if ($result.WingetPresent) { "Yes" } else { "No" }
    $chocoStatus = if ($result.ChocolateyPresent) { "Yes" } else { "No" }
    
    $report += "`n| $($result.OSName) | $($test.ExpectedMethod) | $($result.VSCodeInstalled) | $($result.InstallMethod) | $wingetStatus | $chocoStatus | $status |"
}

$report += @'

## Detailed Results

'@

foreach ($result in $allResults) {
    $report += "`n### $($result.OSName)`n"
    $report += "- **VS Code Path**: $($result.VSCodePath)`n"
    $report += "- **VS Code Version**: $($result.VSCodeVersion)`n"
    $report += "- **Installation Method**: $($result.InstallMethod)`n"
    $report += "- **Winget Present**: $($result.WingetPresent)`n"
    $report += "- **Chocolatey Present**: $($result.ChocolateyPresent)`n`n"
}

# Save report
$report | Out-File -FilePath "test-vscode-results.md" -Encoding UTF8
Write-Host "Report saved to test-vscode-results.md"

# Cleanup if requested
if ($CleanupAfter) {
    Write-Host "`nCleaning up test catlets..."
    foreach ($test in $testMatrix) {
        $catlet = Get-Catlet | Where-Object { $_.Name -eq "test-vscode-$($test.Name)" }
        if ($catlet) {
            Write-Host "Removing catlet: test-vscode-$($test.Name)"
            $catlet | Stop-Catlet -Force
            Start-Sleep -Seconds 5
            $catlet | Remove-Catlet -Force
        }
    }
}

Write-Host "`n=== Testing Complete ===" -ForegroundColor Green
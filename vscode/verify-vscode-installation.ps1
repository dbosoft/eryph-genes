# verify-vscode-installation.ps1
# Standalone script to verify VS Code installation on a running catlet

param(
    [Parameter(Mandatory=$true)]
    [string]$CatletId,
    
    [string]$ExpectedMethod = "Auto",
    
    [switch]$Detailed,
    
    [switch]$CheckLogs
)

# Function to run command via SSH
function Invoke-SSHCommand {
    param(
        [string]$CatletId,
        [string]$Command
    )
    
    try {
        $result = ssh "$CatletId.eryph.alt" "powershell -Command `"$Command`"" 2>$null
        return $result
    } catch {
        return $null
    }
}

Write-Host "=== VS Code Installation Verification ===" -ForegroundColor Cyan
Write-Host "Catlet ID: $CatletId"
Write-Host "Expected Method: $ExpectedMethod"
Write-Host ""

# Check if catlet is accessible
Write-Host "Checking catlet connectivity..."
$testConnection = Invoke-SSHCommand -CatletId $CatletId -Command "Write-Output 'Connected'"
if ($testConnection -ne "Connected") {
    Write-Error "Cannot connect to catlet $CatletId. Ensure it's running and SSH is configured."
    exit 1
}
Write-Host "[OK] Connected to catlet" -ForegroundColor Green

# Get OS information
Write-Host ""
Write-Host "Gathering OS information..."
$osInfo = Invoke-SSHCommand -CatletId $CatletId -Command @'
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    Write-Output "OS: $($os.Caption)"
    Write-Output "Build: $($os.BuildNumber)"
    Write-Output "Version: $($os.Version)"
'@
Write-Host $osInfo

# Check VS Code installation
Write-Host ""
Write-Host "Checking VS Code installation..."
$vscodeCheck = Invoke-SSHCommand -CatletId $CatletId -Command @'
    $paths = @(
        "C:\Program Files\Microsoft VS Code\Code.exe",
        "C:\Program Files (x86)\Microsoft VS Code\Code.exe",
        "${env:LOCALAPPDATA}\Programs\Microsoft VS Code\Code.exe"
    )
    $found = $false
    foreach ($path in $paths) {
        if (Test-Path $path) {
            Write-Output "INSTALLED: $path"
            $found = $true
            
            # Get version
            try {
                $versionInfo = & $path --version 2>$null
                if ($versionInfo) {
                    Write-Output "VERSION: $($versionInfo[0])"
                }
            } catch {}
            break
        }
    }
    if (-not $found) {
        Write-Output "NOT_INSTALLED"
    }
'@

if ($vscodeCheck -match "INSTALLED: (.+)") {
    $vscodePath = $Matches[1]
    Write-Host " VS Code is installed at: $vscodePath" -ForegroundColor Green
    
    if ($vscodeCheck -match "VERSION: (.+)") {
        $vscodeVersion = $Matches[1]
        Write-Host "  Version: $vscodeVersion"
    }
} else {
    Write-Host " VS Code is NOT installed" -ForegroundColor Red
}

# Check winget
Write-Host ""
Write-Host "Checking winget..."
$wingetCheck = Invoke-SSHCommand -CatletId $CatletId -Command @'
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Output "PRESENT"
        try {
            $version = winget --version
            Write-Output "VERSION: $version"
        } catch {}
    } else {
        Write-Output "NOT_PRESENT"
    }
'@

if ($wingetCheck -match "PRESENT") {
    Write-Host " Winget is present" -ForegroundColor Green
    if ($wingetCheck -match "VERSION: (.+)") {
        Write-Host "  Version: $($Matches[1])"
    }
} else {
    Write-Host " Winget is not present"
}

# Check Chocolatey
Write-Host ""
Write-Host "Checking Chocolatey..."
$chocoCheck = Invoke-SSHCommand -CatletId $CatletId -Command @'
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Output "PRESENT"
        try {
            $version = choco --version
            Write-Output "VERSION: $version"
        } catch {}
    } else {
        Write-Output "NOT_PRESENT"
    }
'@

if ($chocoCheck -match "PRESENT") {
    Write-Host " Chocolatey is present" -ForegroundColor Green
    if ($chocoCheck -match "VERSION: (.+)") {
        Write-Host "  Version: $($Matches[1])"
    }
} else {
    Write-Host " Chocolatey is not present"
}

# Check installation logs
if ($CheckLogs) {
    Write-Host ""
    Write-Host "Checking installation logs..."
    
    $logCheck = Invoke-SSHCommand -CatletId $CatletId -Command @'
        $logFile = "C:\ProgramData\cloudbase-init\log\cloudbase-init-unattend.log"
        if (Test-Path $logFile) {
            $content = Get-Content $logFile
            
            # Check installation method
            $methodLine = $content | Select-String -Pattern "VS Code successfully installed via" | Select-Object -Last 1
            if ($methodLine) {
                Write-Output "METHOD: $methodLine"
            }
            
            # Check for errors
            $errors = $content | Select-String -Pattern "ERROR:|Failed to install"
            if ($errors) {
                Write-Output "ERRORS_FOUND"
                $errors | ForEach-Object { Write-Output "ERROR: $_" }
            }
            
            # Get timing
            $startLine = $content | Select-String -Pattern "Starting VS Code installation" | Select-Object -First 1
            $endLine = $content | Select-String -Pattern "VS Code installation completed|Failed to install VS Code" | Select-Object -Last 1
            
            if ($startLine) {
                Write-Output "START: $startLine"
            }
            if ($endLine) {
                Write-Output "END: $endLine"
            }
        } else {
            Write-Output "LOG_NOT_FOUND"
        }
'@
    
    if ($logCheck -match "METHOD: .*via (\w+)") {
        $installMethod = $Matches[1]
        Write-Host "  Installation method: $installMethod" -ForegroundColor Cyan
        
        if ($ExpectedMethod -ne "Auto" -and $installMethod -ne $ExpectedMethod) {
            Write-Warning "  Expected: $ExpectedMethod, Got: $installMethod"
        }
    }
    
    if ($logCheck -match "ERRORS_FOUND") {
        Write-Host "  Errors found in log:" -ForegroundColor Yellow
        $logCheck -split "`n" | Where-Object { $_ -match "^ERROR:" } | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Yellow
        }
    }
}

# Detailed checks
if ($Detailed) {
    Write-Host ""
    Write-Host "Detailed checks..."
    
    # Check PATH
    Write-Host ""
    Write-Host "Checking PATH environment variable..."
    $pathCheck = Invoke-SSHCommand -CatletId $CatletId -Command @'
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($machinePath -match "Microsoft VS Code") {
            Write-Output "VS_CODE_IN_PATH"
        } else {
            Write-Output "VS_CODE_NOT_IN_PATH"
        }
'@
    
    if ($pathCheck -match "VS_CODE_IN_PATH") {
        Write-Host "   VS Code is in system PATH" -ForegroundColor Green
    } else {
        Write-Host "   VS Code is not in system PATH"
    }
    
    # Check if code command works
    Write-Host ""
    Write-Host "Checking 'code' command..."
    $codeCommandCheck = Invoke-SSHCommand -CatletId $CatletId -Command @'
        try {
            $result = & code --version 2>$null
            if ($result) {
                Write-Output "CODE_COMMAND_WORKS"
                Write-Output $result[0]
            } else {
                Write-Output "CODE_COMMAND_FAILED"
            }
        } catch {
            Write-Output "CODE_COMMAND_ERROR"
        }
'@
    
    if ($codeCommandCheck -match "CODE_COMMAND_WORKS") {
        Write-Host "   'code' command is working" -ForegroundColor Green
    } else {
        Write-Host "   'code' command is not working" -ForegroundColor Red
    }
    
    # Check installed extensions
    Write-Host ""
    Write-Host "Checking installed extensions..."
    $extensionsCheck = Invoke-SSHCommand -CatletId $CatletId -Command @'
        if (Get-Command code -ErrorAction SilentlyContinue) {
            $extensions = & code --list-extensions 2>$null
            if ($extensions) {
                Write-Output "EXTENSIONS_COUNT: $($extensions.Count)"
                $extensions | ForEach-Object { Write-Output "EXT: $_" }
            } else {
                Write-Output "NO_EXTENSIONS"
            }
        } else {
            Write-Output "CODE_NOT_FOUND"
        }
'@
    
    if ($extensionsCheck -match "EXTENSIONS_COUNT: (\d+)") {
        $extCount = $Matches[1]
        Write-Host "  Extensions installed: $extCount"
        
        if ($extCount -gt 0) {
            $extensionsCheck -split "`n" | Where-Object { $_ -match "^EXT: (.+)" } | ForEach-Object {
                Write-Host "    - $($Matches[1])"
            }
        }
    } elseif ($extensionsCheck -match "NO_EXTENSIONS") {
        Write-Host "  No extensions installed"
    } else {
        Write-Host "  Could not check extensions"
    }
}

# Summary
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
$summary = @{
    "VS Code Installed" = ($vscodeCheck -match "INSTALLED")
    "Winget Present" = ($wingetCheck -match "PRESENT")
    "Chocolatey Present" = ($chocoCheck -match "PRESENT")
}

$summary.GetEnumerator() | ForEach-Object {
    $status = if ($_.Value) { "[OK]" } else { "[FAIL]" }
    $color = if ($_.Value) { "Green" } else { "Red" }
    Write-Host "$status $($_.Key)" -ForegroundColor $color
}

# Exit code
if ($vscodeCheck -match "INSTALLED") {
    exit 0
} else {
    exit 1
}
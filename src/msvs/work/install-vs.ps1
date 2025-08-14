# Visual Studio Community 2022 Installation Script
# This is a standalone version of the installation script for testing and reference
# Usage: .\install-vs.ps1 [-IsoPath <path>] [-Workloads <workload1;workload2>] [-InstallPath <path>] [-IncludeRecommended]

param(
    [ValidateSet("Community", "Professional", "Enterprise")]
    [string]$Edition = "Community",
    [string]$IsoPath = "",
    [string]$Workloads = "Microsoft.VisualStudio.Workload.ManagedDesktop;Microsoft.VisualStudio.Workload.NetWeb",
    [string]$Components = "",
    [string]$Languages = "en-US",
    [string]$InstallPath = "C:\Program Files\Microsoft Visual Studio\2022\Community",
    [switch]$IncludeRecommended = $true,
    [switch]$IncludeOptional = $false
)

Write-Host "Visual Studio Community 2022 Installation Script" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Function to test if a command exists
function Test-CommandExists {
    param($Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

# Function to detect VS installer on mounted ISO
function Find-VSInstallerOnISO {
    Write-Host "Searching for Visual Studio installer on mounted drives..."
    
    # Skip D: drive as it typically contains cloud-init disk in VMs
    $drivesToCheck = @('E:', 'F:', 'G:', 'H:')
    
    foreach ($drive in $drivesToCheck) {
        if (Test-Path $drive) {
            Write-Host "Checking drive $drive..."
            
            # Common VS installer locations on ISO
            $installerPaths = @(
                "$drive\vs_community.exe",
                "$drive\vs_setup.exe",
                "$drive\setup.exe",
                "$drive\vs_installer\vs_community.exe"
            )
            
            foreach ($path in $installerPaths) {
                if (Test-Path $path) {
                    Write-Host "Found VS installer at: $path" -ForegroundColor Green
                    return $path
                }
            }
        }
    }
    
    return $null
}

# Function to mount ISO if path provided
function Mount-VsISO {
    param($IsoPath)
    
    if ([string]::IsNullOrWhiteSpace($IsoPath)) {
        return $null
    }
    
    if (!(Test-Path $IsoPath)) {
        Write-Host "WARNING: Provided ISO path does not exist: $IsoPath" -ForegroundColor Yellow
        return $null
    }
    
    Write-Host "Mounting ISO from: $IsoPath"
    try {
        $mount = Mount-DiskImage -ImagePath $IsoPath -PassThru
        $driveLetter = ($mount | Get-Volume).DriveLetter
        if ($driveLetter) {
            $installerPath = "${driveLetter}:\vs_community.exe"
            if (!(Test-Path $installerPath)) {
                $installerPath = "${driveLetter}:\vs_setup.exe"
            }
            if (!(Test-Path $installerPath)) {
                $installerPath = "${driveLetter}:\setup.exe"
            }
            
            if (Test-Path $installerPath) {
                Write-Host "Found installer at: $installerPath" -ForegroundColor Green
                return $installerPath
            } else {
                Write-Host "No VS installer found on mounted ISO" -ForegroundColor Yellow
                Dismount-DiskImage -ImagePath $IsoPath
                return $null
            }
        }
    } catch {
        Write-Host "Error mounting ISO: $_" -ForegroundColor Red
        return $null
    }
    
    return $null
}

# Function to download VS bootstrapper
function Download-VSBootstrapper {
    Write-Host "Downloading Visual Studio Community 2022 bootstrapper..."
    
    $bootstrapperUrl = "https://aka.ms/vs/17/release/vs_community.exe"
    $bootstrapperPath = "$env:TEMP\vs_community.exe"
    
    try {
        # Show download progress
        $progressPreference = 'Continue'
        Invoke-WebRequest -Uri $bootstrapperUrl -OutFile $bootstrapperPath -UseBasicParsing
        if (Test-Path $bootstrapperPath) {
            Write-Host "Bootstrapper downloaded to: $bootstrapperPath" -ForegroundColor Green
            return $bootstrapperPath
        }
    } catch {
        Write-Host "Error downloading bootstrapper: $_" -ForegroundColor Red
        return $null
    }
    
    return $null
}

# Function to build installation arguments
function Build-InstallArguments {
    param(
        [string]$InstallPath,
        [string]$Workloads,
        [string]$Components,
        [string]$Languages,
        [bool]$IncludeRecommended,
        [bool]$IncludeOptional
    )
    
    $args = @(
        "--quiet",
        "--wait",
        "--norestart",
        "--installPath", "`"$InstallPath`""
    )
    
    # Add workloads
    if (![string]::IsNullOrWhiteSpace($Workloads)) {
        $workloadList = $Workloads -split ';'
        foreach ($workload in $workloadList) {
            $workload = $workload.Trim()
            if (![string]::IsNullOrWhiteSpace($workload)) {
                $args += "--add", $workload
            }
        }
    }
    
    # Add individual components
    if (![string]::IsNullOrWhiteSpace($Components)) {
        $componentList = $Components -split ';'
        foreach ($component in $componentList) {
            $component = $component.Trim()
            if (![string]::IsNullOrWhiteSpace($component)) {
                $args += "--add", $component
            }
        }
    }
    
    # Add language packs
    if (![string]::IsNullOrWhiteSpace($Languages)) {
        $languageList = $Languages -split ';'
        foreach ($language in $languageList) {
            $language = $language.Trim()
            if (![string]::IsNullOrWhiteSpace($language)) {
                $args += "--addProductLang", $language
            }
        }
    }
    
    # Include recommended components
    if ($IncludeRecommended) {
        $args += "--includeRecommended"
    }
    
    # Include optional components
    if ($IncludeOptional) {
        $args += "--includeOptional"
    }
    
    return $args
}

# Display configuration
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Install Path: $InstallPath"
Write-Host "  Include Recommended: $IncludeRecommended"
if (![string]::IsNullOrWhiteSpace($IsoPath)) {
    Write-Host "  ISO Path: $IsoPath"
}
Write-Host "  Workloads:"
$Workloads -split ';' | ForEach-Object { 
    Write-Host "    - $_"
}
Write-Host ""

# Main installation logic
$installed = $false
$installerPath = $null

# Check if VS is already installed
if (Test-Path "$InstallPath\Common7\IDE\devenv.exe") {
    Write-Host "Visual Studio is already installed at: $InstallPath" -ForegroundColor Green
    $installed = $true
}

if (!$installed) {
    # Try to find installer in this order:
    # 1. User-provided ISO path
    # 2. Auto-detect mounted ISO
    # 3. Download bootstrapper
    
    if (![string]::IsNullOrWhiteSpace($IsoPath)) {
        Write-Host "Attempting to use provided ISO path..."
        $installerPath = Mount-VsISO -IsoPath $IsoPath
    }
    
    if (!$installerPath) {
        Write-Host "Checking for auto-mounted ISO..."
        $installerPath = Find-VSInstallerOnISO
    }
    
    if (!$installerPath) {
        Write-Host "No ISO found, downloading from internet..."
        $installerPath = Download-VSBootstrapper
    }
    
    if (!$installerPath) {
        Write-Host "ERROR: Could not obtain Visual Studio installer" -ForegroundColor Red
        exit 1
    }
    
    # Build installation arguments
    $installArgs = Build-InstallArguments -InstallPath $InstallPath -Workloads $Workloads -Components $Components -Languages $Languages -IncludeRecommended $IncludeRecommended -IncludeOptional $IncludeOptional
    
    Write-Host ""
    Write-Host "Starting Visual Studio installation..." -ForegroundColor Cyan
    Write-Host "Installer: $installerPath"
    Write-Host "This may take 30-60 minutes depending on selected workloads..."
    Write-Host ""
    
    # Create log directory
    $logDir = "$env:TEMP\VSInstallLogs"
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    
    # Execute installation
    try {
        $startTime = Get-Date
        $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        $exitCode = $process.ExitCode
        $duration = (Get-Date) - $startTime
        
        Write-Host ""
        Write-Host "Installation completed in $($duration.TotalMinutes.ToString('0.0')) minutes" -ForegroundColor Cyan
        
        if ($exitCode -eq 0) {
            Write-Host "Visual Studio installation completed successfully" -ForegroundColor Green
            $installed = $true
        } elseif ($exitCode -eq 3010) {
            Write-Host "Visual Studio installation completed successfully (reboot required)" -ForegroundColor Green
            $installed = $true
            Write-Host "WARNING: System reboot required to complete installation" -ForegroundColor Yellow
            # In standalone mode, we don't automatically reboot
        } elseif ($exitCode -eq 1641) {
            Write-Host "Visual Studio installer initiated a restart" -ForegroundColor Yellow
            Write-Host "Please reboot and run the script again to continue installation" -ForegroundColor Yellow
            exit 1641
        } else {
            Write-Host "Visual Studio installation failed with exit code: $exitCode" -ForegroundColor Red
            Write-Host "Check logs in: $logDir" -ForegroundColor Yellow
            
            # Try to find and display error logs
            $errorLog = Get-ChildItem -Path "$env:TEMP" -Filter "dd_*.log" -ErrorAction SilentlyContinue | 
                        Sort-Object LastWriteTime -Descending | 
                        Select-Object -First 1
            
            if ($errorLog) {
                Write-Host "Recent log file: $($errorLog.FullName)" -ForegroundColor Yellow
                Write-Host "Last 50 lines of log:" -ForegroundColor Yellow
                Get-Content $errorLog.FullName -Tail 50 | Write-Host
            }
        }
    } catch {
        Write-Host "Error during installation: $_" -ForegroundColor Red
    }
    
    # Clean up downloaded bootstrapper if used
    if ($installerPath -like "*\Temp\*") {
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
    }
    
    # Unmount ISO if we mounted it
    if (![string]::IsNullOrWhiteSpace($IsoPath) -and (Test-Path $IsoPath)) {
        try {
            Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
        } catch {
            # Ignore dismount errors
        }
    }
}

# Final verification
if ($installed) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Visual Studio Community 2022 Ready!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    # Add VS tools to PATH
    $vsPath = "$InstallPath\Common7\IDE"
    if (Test-Path $vsPath) {
        $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$vsPath*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$vsPath", "Machine")
            Write-Host "Added Visual Studio to system PATH" -ForegroundColor Green
        }
    }
    
    # Display installation summary
    Write-Host ""
    Write-Host "Installation Summary:" -ForegroundColor Cyan
    Write-Host "  Location: $InstallPath"
    Write-Host "  Executable: $InstallPath\Common7\IDE\devenv.exe"
    Write-Host ""
    Write-Host "Installed workloads:" -ForegroundColor Cyan
    if (![string]::IsNullOrWhiteSpace($Workloads)) {
        $Workloads -split ';' | ForEach-Object { Write-Host "  - $_" -ForegroundColor Green }
    } else {
        Write-Host "  - Default workloads" -ForegroundColor Green
    }
    
    exit 0
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Visual Studio Installation Failed" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}
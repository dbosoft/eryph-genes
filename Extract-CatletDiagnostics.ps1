# Extract-CatletDiagnostics.ps1
# Standalone script for extracting diagnostics from a catlet when EGS fails
# This script mounts the VM disk and extracts sysprep and cloud-init logs

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$CatletId,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\diagnostics",
    
    [Parameter(Mandatory=$false)]
    [switch]$KeepCatlet
)

$InformationPreference = 'Continue'
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Write-Host "========================================" -ForegroundColor Red
Write-Host " Catlet Diagnostic Extraction" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host "Catlet ID: $CatletId" -ForegroundColor White
Write-Host "Output Path: $OutputPath" -ForegroundColor White
Write-Host ""

function Stop-CatletHard {
    param([string]$Id)
    
    Write-Information "Hard stopping catlet: $Id"
    try {
        # First try graceful stop
        Stop-Catlet -Id $Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 10
        
        # Get the VM and force stop if still running
        $catlet = Get-Catlet -Id $Id
        if ($catlet.Status -eq "Running") {
            Write-Information "Catlet still running, forcing VM stop..."
            $vm = Get-VM -Id $catlet.VmId -ErrorAction SilentlyContinue
            if ($vm) {
                Stop-VM -VM $vm -Force -TurnOff
                Write-Information "VM force stopped successfully"
            }
        }
        return $true
    }
    catch {
        Write-Warning "Failed to stop catlet: $_"
        return $false
    }
}

function Get-CatletMainDisk {
    param([string]$CatletId)
    
    Write-Information "Detecting main disk for catlet: $CatletId"
    try {
        $catlet = Get-Catlet -Id $CatletId
        $vmId = $catlet.VmId
        
        # Get VM and its disks
        $vm = Get-VM -Id $vmId
        Write-Information "Found VM: $($vm.Name)"
        
        # Get all VHD paths from the VM
        $vhdPaths = @()
        $vm.HardDrives | ForEach-Object {
            if ($_.Path) {
                $vhdPaths += $_.Path
                Write-Information "Found VHD: $($_.Path)"
            }
        }
        
        if ($vhdPaths.Count -eq 0) {
            throw "No VHD files found for VM"
        }
        
        # The main disk is typically the first/largest one
        $mainDisk = $vhdPaths[0]
        Write-Information "Using main disk: $mainDisk"
        
        return @{
            VmId = $vmId
            MainDiskPath = $mainDisk
            AllDisks = $vhdPaths
        }
    }
    catch {
        Write-Error "Failed to detect main disk: $_"
        return $null
    }
}

function Mount-VHDAndExtractLogs {
    param(
        [string]$VhdPath,
        [string]$OutputPath
    )
    
    Write-Information "Mounting VHD: $VhdPath"
    Write-Information "WARNING: This script is designed for Windows VHDs only!"
    $mountedDrive = $null
    
    try {
        # Mount the VHD (this is ONLY a VHD file from a catlet, never host partitions)
        Write-Information "Mounting catlet VHD file (not host partition): $VhdPath"
        $mountResult = Mount-VHD -Path $VhdPath -Passthru -ReadOnly
        $disk = $mountResult | Get-Disk
        $partitions = $disk | Get-Partition
        
        Write-Information "Found $($partitions.Count) partitions in VHD"
        $partitions | ForEach-Object {
            Write-Information "VHD Partition $($_.PartitionNumber): Type=$($_.Type), Size=$([math]::Round($_.Size/1GB, 2))GB"
        }
        
        # Find the largest partition in the VHD (likely contains the OS)
        # We use simple logic: largest partition over 1GB
        $partition = $partitions | Where-Object { 
            $_.Size -gt 1GB 
        } | Sort-Object Size -Descending | Select-Object -First 1
        
        if (-not $partition) {
            throw "No suitable partition found in catlet VHD (no partition > 1GB)"
        }
        
        Write-Information "Selected VHD partition $($partition.PartitionNumber) ($([math]::Round($partition.Size/1GB, 2))GB)"
        
        # Assign drive letter if the partition doesn't have one
        if (-not $partition.DriveLetter) {
            Write-Information "VHD partition has no drive letter, assigning one..."
            $availableLetter = 67..90 | ForEach-Object { [char]$_ } | Where-Object { 
                -not (Get-PSDrive -Name $_ -ErrorAction SilentlyContinue) 
            } | Select-Object -First 1
            
            if (-not $availableLetter) {
                throw "No available drive letters to assign to VHD partition"
            }
            
            Set-Partition -InputObject $partition -NewDriveLetter $availableLetter
            Write-Information "Assigned drive letter ${availableLetter}: to VHD partition"
            $driveLetter = $availableLetter
        } else {
            $driveLetter = $partition.DriveLetter
            Write-Information "VHD partition already has drive letter: ${driveLetter}:"
        }
        
        # Create output directory
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        
        $logsExtracted = 0
        
        # Extract Windows sysprep logs
        $sysprepPaths = @(
            "${driveLetter}:\Windows\System32\Sysprep\Panther\setupact.log",
            "${driveLetter}:\Windows\System32\Sysprep\Panther\setuperr.log",
            "${driveLetter}:\Windows\Panther\setupact.log",
            "${driveLetter}:\Windows\Panther\setuperr.log",
            "${driveLetter}:\Windows\Panther\UnattendGC\setupact.log",
            "${driveLetter}:\Windows\Panther\UnattendGC\setuperr.log",
            "${driveLetter}:\Windows\Temp\sysprep.log"
        )
        
        Write-Information "Extracting Windows sysprep logs..."
        foreach ($logPath in $sysprepPaths) {
            if (Test-Path $logPath) {
                # Create unique filenames to avoid overwriting
                $baseFileName = Split-Path $logPath -Leaf
                $pathHash = ($logPath -replace ':', '_' -replace '\\', '_').Substring(0, [Math]::Min(20, $logPath.Length))
                $fileName = "sysprep_${pathHash}_${baseFileName}"
                $destPath = Join-Path $OutputPath $fileName
                Copy-Item -Path $logPath -Destination $destPath -Force
                Write-Information "Extracted: $logPath -> $destPath"
                $logsExtracted++
            }
        }
        
        # Extract cloudbase-init logs
        $cloudbaseInitPaths = @(
            "${driveLetter}:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log",
            "${driveLetter}:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init-unattend.log",
            "${driveLetter}:\ProgramData\cloudbase-init\log\cloudbase-init.log",
            "${driveLetter}:\ProgramData\cloudbase-init\log\cloudbase-init-unattend.log"
        )
        
        Write-Information "Extracting cloudbase-init logs..."
        foreach ($logPath in $cloudbaseInitPaths) {
            if (Test-Path $logPath) {
                $fileName = "cloudbase-init_$(Split-Path $logPath -Leaf)"
                $destPath = Join-Path $OutputPath $fileName
                Copy-Item -Path $logPath -Destination $destPath -Force
                Write-Information "Extracted: $logPath -> $destPath"
                $logsExtracted++
            }
        }
        
        # Extract cloud-init logs (Linux - these paths typically won't exist on Windows VHDs)
        $cloudInitPaths = @(
            "${driveLetter}:\var\log\cloud-init.log",
            "${driveLetter}:\var\log\cloud-init-output.log"
        )
        
        Write-Information "Checking for cloud-init logs (Linux)..."
        $linuxLogsFound = 0
        foreach ($logPath in $cloudInitPaths) {
            if (Test-Path $logPath) {
                $fileName = "cloud-init_$(Split-Path $logPath -Leaf)"
                $destPath = Join-Path $OutputPath $fileName
                Copy-Item -Path $logPath -Destination $destPath -Force
                Write-Information "Extracted: $logPath -> $destPath"
                $logsExtracted++
                $linuxLogsFound++
            }
        }
        
        if ($linuxLogsFound -gt 0) {
            Write-Warning "Found Linux logs! This script is primarily designed for Windows VHDs. Consider using Linux-specific diagnostic tools."
        }
        
        # Extract Windows boot, setup and component servicing logs
        $bootSetupPaths = @(
            "${driveLetter}:\Windows\Logs\CBS\CBS.log",
            "${driveLetter}:\Windows\WindowsUpdate.log", 
            "${driveLetter}:\Windows\Setup\State\State.ini",
            "${driveLetter}:\Windows\inf\setupapi.dev.log",
            "${driveLetter}:\Windows\Logs\DISM\dism.log",
            "${driveLetter}:\Windows\ntbtlog.txt",
            "${driveLetter}:\Windows\Setup\Compat\CompatData.xml",
            "${driveLetter}:\Windows\Logs\SrtTrail.txt"
        )
        
        # Extract AppX logs (common cause of Windows 11 sysprep failures)
        $appxLogPaths = @(
            "${driveLetter}:\Windows\Logs\AppxDeployment-Server\Microsoft-Windows-AppxDeployment-Server%4Operational.evtx",
            "${driveLetter}:\Windows\Logs\AppxDeployment-Server\Microsoft-Windows-AppxDeployment%4Operational.evtx",
            "${driveLetter}:\Windows\System32\winevt\Logs\Microsoft-Windows-AppXDeployment%4Operational.evtx",
            "${driveLetter}:\Windows\System32\winevt\Logs\Microsoft-Windows-AppXDeployment-Server%4Operational.evtx",
            "${driveLetter}:\Windows\System32\winevt\Logs\Microsoft-Windows-AppModel-Runtime%4Admin.evtx"
        )
        
        Write-Information "Extracting AppX logs (common Windows 11 sysprep failure cause)..."
        foreach ($logPath in $appxLogPaths) {
            if (Test-Path $logPath) {
                $baseFileName = Split-Path $logPath -Leaf
                $pathHash = ($logPath -replace ':', '_' -replace '\\', '_' -replace '%', '_').Substring(0, [Math]::Min(15, $logPath.Length))
                $fileName = "appx_${pathHash}_${baseFileName}"
                $destPath = Join-Path $OutputPath $fileName
                Copy-Item -Path $logPath -Destination $destPath -Force
                Write-Information "Extracted: $logPath -> $destPath"
                $logsExtracted++
            }
        }
        
        Write-Information "Extracting Windows boot and setup logs..."
        foreach ($logPath in $bootSetupPaths) {
            if (Test-Path $logPath) {
                $baseFileName = Split-Path $logPath -Leaf
                $pathHash = ($logPath -replace ':', '_' -replace '\\', '_').Substring(0, [Math]::Min(20, $logPath.Length))
                $fileName = "boot_${pathHash}_${baseFileName}"
                $destPath = Join-Path $OutputPath $fileName
                Copy-Item -Path $logPath -Destination $destPath -Force
                Write-Information "Extracted: $logPath -> $destPath"
                $logsExtracted++
            }
        }
        
        # Extract Windows Event Logs that might be relevant
        $eventLogPaths = @(
            "${driveLetter}:\Windows\System32\winevt\Logs\System.evtx",
            "${driveLetter}:\Windows\System32\winevt\Logs\Application.evtx",
            "${driveLetter}:\Windows\System32\winevt\Logs\Setup.evtx"
        )
        
        Write-Information "Extracting Windows Event logs..."
        foreach ($logPath in $eventLogPaths) {
            if (Test-Path $logPath) {
                $fileName = "event_$(Split-Path $logPath -Leaf)"
                $destPath = Join-Path $OutputPath $fileName
                Copy-Item -Path $logPath -Destination $destPath -Force
                Write-Information "Extracted: $logPath -> $destPath"
                $logsExtracted++
            }
        }
        
        # Create a summary file
        $summaryPath = Join-Path $OutputPath "extraction_summary.txt"
        $summary = @"
Catlet Diagnostic Extraction Summary
====================================
Extraction Time: $(Get-Date)
Catlet ID: $CatletId
VHD Path: $VhdPath
Mounted Drive: ${driveLetter}:
Logs Extracted: $logsExtracted

VHD Contents (root level):
$(try { Get-ChildItem "${driveLetter}:\" -Force | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String } catch { "Failed to list root contents" })

Windows Directory Contents:
$(try { if (Test-Path "${driveLetter}:\Windows") { Get-ChildItem "${driveLetter}:\Windows" -Force | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize | Out-String } else { "Windows directory not found" } } catch { "Failed to list Windows contents" })
"@
        
        Set-Content -Path $summaryPath -Value $summary
        Write-Information "Created extraction summary: $summaryPath"
        
        return $logsExtracted
    }
    catch {
        Write-Error "Failed to extract logs from VHD: $_"
        return 0
    }
    finally {
        # Unmount the VHD
        if ($VhdPath) {
            try {
                Write-Information "Unmounting VHD: $VhdPath"
                Dismount-VHD -Path $VhdPath
                Write-Information "VHD unmounted successfully"
            }
            catch {
                Write-Warning "Failed to unmount VHD: $_"
            }
        }
    }
}

function Remove-CatletSafely {
    param([string]$Id)
    
    if ($KeepCatlet) {
        Write-Information "Keeping catlet as requested (ID: $Id)"
        return
    }
    
    Write-Information "Removing catlet: $Id"
    try {
        Remove-Catlet -Id $Id -Force
        Write-Information "Catlet removed successfully"
    }
    catch {
        Write-Warning "Failed to remove catlet: $_"
    }
}

# Main execution
try {
    # Step 1: Stop catlet hard
    Write-Host ""
    Write-Host "STEP 1: Stopping catlet hard..." -ForegroundColor Yellow
    if (-not (Stop-CatletHard -Id $CatletId)) {
        Write-Error "Failed to stop catlet, cannot proceed with disk extraction"
        exit 1
    }
    
    # Step 2: Detect main disk
    Write-Host ""
    Write-Host "STEP 2: Detecting main disk..." -ForegroundColor Yellow
    $diskInfo = Get-CatletMainDisk -CatletId $CatletId
    if (-not $diskInfo) {
        Write-Error "Failed to detect main disk"
        exit 1
    }
    
    # Step 3: Mount disk and extract logs
    Write-Host ""
    Write-Host "STEP 3: Mounting disk and extracting diagnostics..." -ForegroundColor Yellow
    $extractedCount = Mount-VHDAndExtractLogs -VhdPath $diskInfo.MainDiskPath -OutputPath $OutputPath
    
    # Step 4: Display results
    Write-Host ""
    Write-Host "STEP 4: Extraction Results" -ForegroundColor Green
    Write-Host "Extracted $extractedCount log files to: $OutputPath" -ForegroundColor White
    
    if (Test-Path $OutputPath) {
        Write-Host ""
        Write-Host "Extracted files:" -ForegroundColor Cyan
        Get-ChildItem $OutputPath | ForEach-Object {
            Write-Host "  - $($_.Name) ($($_.Length) bytes)" -ForegroundColor Gray
        }
    }
    
    # Step 5: Cleanup catlet
    Write-Host ""
    Write-Host "STEP 5: Cleanup..." -ForegroundColor Yellow
    Remove-CatletSafely -Id $CatletId
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host " Diagnostic extraction completed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Check the extracted logs in: $OutputPath" -ForegroundColor White
    
    exit 0
}
catch {
    Write-Error "Diagnostic extraction failed: $_"
    
    # Attempt cleanup on failure
    try {
        Remove-CatletSafely -Id $CatletId
    }
    catch {
        Write-Warning "Failed to cleanup catlet after error: $_"
    }
    
    exit 1
}
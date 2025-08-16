# EryphTestHelpers.psm1
# Shared helper functions for eryph testing with EGS
#
# File copy optimization:
# - Single files: Uses egs-tool upload-file (faster, no SSH overhead)
# - Directories: Uses scp (egs-tool doesn't support directory uploads)
# - Host key verification: Disabled by default in EGS, no need for StrictHostKeyChecking

function Wait-EGSReady {
    <#
    .SYNOPSIS
    Waits for EGS (Eryph Guest Services) to be available on a VM
    
    .PARAMETER VmId
    The VM ID to check
    
    .PARAMETER TimeoutMinutes
    Maximum time to wait in minutes (default: 10)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,
        
        [int]$TimeoutMinutes = 10
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Information "Waiting for EGS to be ready on VM: $VmId (timeout: $TimeoutMinutes minutes)" -InformationAction Continue
    
    $lastStatus = ""
    $checkCount = 0
    
    do {
        $checkCount++
        try {
            $status = & egs-tool get-status $VmId 2>&1 | Out-String
            $status = $status.Trim()
            
            if ($status -ne $lastStatus) {
                Write-Verbose "EGS status check #$checkCount : $status"
                $lastStatus = $status
            }
            
            if ($status -eq "available") {
                Write-Information "EGS is available on VM: $VmId (after $($stopwatch.Elapsed.TotalSeconds.ToString('F1')) seconds)" -InformationAction Continue
                return $true
            }
            elseif ($status -match "error|failed") {
                Write-Warning "EGS reported error status: $status"
            }
        }
        catch {
            Write-Verbose "Error checking EGS status: $_"
        }
        
        if ($stopwatch.Elapsed.TotalMinutes -ge $TimeoutMinutes) {
            Write-Warning "Timeout waiting for EGS on VM $VmId after $TimeoutMinutes minutes"
            Write-Warning "Last status: $lastStatus"
            Write-Warning "Try running manually: egs-tool get-status $VmId"
            return $false
        }
        
        Start-Sleep -Seconds 5
    } while ($true)
}

function Invoke-EGSCommand {
    <#
    .SYNOPSIS
    Executes a command on a VM via EGS/SSH
    
    .PARAMETER VmId
    The VM ID to connect to
    
    .PARAMETER Command
    The command to execute
    
    .PARAMETER TimeoutSeconds
    Command timeout in seconds (default: 120)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,
        
        [Parameter(Mandatory=$true)]
        [string]$Command,
        
        [int]$TimeoutSeconds = 120
    )
    
    $sshPath = "C:/Windows/System32/OpenSSH/ssh.exe"
    if (-not (Test-Path $sshPath)) {
        throw "Windows OpenSSH not found at: $sshPath"
    }
    
    try {
        # Use timeout to prevent hanging (host key verification already disabled by EGS)
        $result = & $sshPath -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=3 `
            "$VmId.hyper-v.alt" -C $Command 2>$null
        
        return $result
    }
    catch {
        Write-Warning "Failed to execute command on VM $VmId : $_"
        return $null
    }
}

function Get-CloudbaseInitLog {
    <#
    .SYNOPSIS
    Retrieves the cloudbase-init log from a Windows VM
    
    .PARAMETER VmId
    The VM ID to get logs from
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId
    )
    
    $logPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log"
    $log = Invoke-EGSCommand -VmId $VmId -Command "type `"$logPath`" 2>nul"
    
    if (-not $log) {
        # Try alternative location
        $altPath = "C:\ProgramData\cloudbase-init\log\cloudbase-init.log"
        $log = Invoke-EGSCommand -VmId $VmId -Command "type `"$altPath`" 2>nul"
    }
    
    return $log
}

function Get-CloudInitLog {
    <#
    .SYNOPSIS
    Retrieves the cloud-init log from a Linux VM
    
    .PARAMETER VmId
    The VM ID to get logs from
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId
    )
    
    $log = Invoke-EGSCommand -VmId $VmId -Command "sudo cat /var/log/cloud-init.log 2>/dev/null || cat /var/log/cloud-init.log"
    return $log
}

function Get-CloudInitLogs {
    <#
    .SYNOPSIS
    Retrieves cloud-init/cloudbase-init logs based on OS type
    
    .PARAMETER VmId
    The VM ID to get logs from
    
    .PARAMETER OsType
    The OS type (windows or linux)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("windows", "linux")]
        [string]$OsType
    )
    
    if ($OsType -eq "windows") {
        return Get-CloudbaseInitLog -VmId $VmId
    }
    else {
        return Get-CloudInitLog -VmId $VmId
    }
}

function Copy-FileToVM {
    <#
    .SYNOPSIS
    Copies a file to a VM using egs-tool upload-file (faster for single files)
    
    .PARAMETER VmId
    The VM ID to copy to
    
    .PARAMETER Source
    Source file path on host
    
    .PARAMETER Target
    Target path on VM
    
    .PARAMETER OsType
    The OS type (windows or linux)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,
        
        [Parameter(Mandatory=$true)]
        [string]$Source,
        
        [Parameter(Mandatory=$true)]
        [string]$Target,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("windows", "linux")]
        [string]$OsType
    )
    
    if (-not (Test-Path $Source)) {
        throw "Source file not found: $Source"
    }
    
    # Ensure target directory exists
    if ($OsType -eq "windows") {
        $targetDir = Split-Path $Target -Parent
        if ($targetDir) {
            Invoke-EGSCommand -VmId $VmId -Command "mkdir `"$targetDir`" 2>nul"
        }
    }
    else {
        $targetDir = Split-Path $Target -Parent
        if ($targetDir) {
            Invoke-EGSCommand -VmId $VmId -Command "mkdir -p $targetDir"
        }
    }
    
    # Use egs-tool upload-file for single file copy (faster than scp)
    try {
        Write-Verbose "Uploading file via egs-tool: $Source -> $Target"
        $result = & egs-tool upload-file $VmId $Source $Target 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Verbose "File uploaded successfully"
            return $true
        } else {
            Write-Warning "egs-tool upload-file failed with exit code: $LASTEXITCODE"
            Write-Warning "Output: $result"
            return $false
        }
    }
    catch {
        Write-Warning "Failed to copy file to VM: $_"
        return $false
    }
}

function Copy-TestsToVM {
    <#
    .SYNOPSIS
    Copies test files/directories to a VM
    
    .PARAMETER VmId
    The VM ID to copy to
    
    .PARAMETER SourcePath
    Source directory path on host
    
    .PARAMETER TargetPath
    Target directory path on VM
    
    .PARAMETER OsType
    The OS type (windows or linux)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,
        
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetPath,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("windows", "linux")]
        [string]$OsType
    )
    
    if (-not (Test-Path $SourcePath)) {
        Write-Warning "Source path not found: $SourcePath"
        return $false
    }
    
    # Create target directory
    if ($OsType -eq "windows") {
        Invoke-EGSCommand -VmId $VmId -Command "mkdir `"$TargetPath`" 2>nul"
    }
    else {
        Invoke-EGSCommand -VmId $VmId -Command "mkdir -p $TargetPath"
    }
    
    # Use the unified Copy-DirectoryToVM function which uses zip+egs
    try {
        $result = Copy-DirectoryToVM -VmId $VmId -SourcePath $SourcePath -TargetPath $TargetPath -OsType $OsType
        
        # Make scripts executable on Linux
        if ($result -and $OsType -eq "linux") {
            Invoke-EGSCommand -VmId $VmId -Command "chmod +x ${TargetPath}/*.sh 2>/dev/null || true"
        }
        
        return $result
    }
    catch {
        Write-Warning "Failed to copy tests to VM: $_"
        return $false
    }
}

function Initialize-EGSConnection {
    <#
    .SYNOPSIS
    Sets up EGS connection for a VM
    
    .PARAMETER VmId
    The VM ID to setup
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId
    )
    
    try {
        Write-Information "Setting up EGS connection for VM: $VmId" -InformationAction Continue
        
        # Step 1: Add SSH config for this specific VM
        Write-Verbose "Running: egs-tool add-ssh-config $VmId"
        $addResult = & egs-tool add-ssh-config $VmId 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "egs-tool add-ssh-config failed with exit code: $LASTEXITCODE"
            Write-Warning "Output: $addResult"
            return $false
        }
        Write-Verbose "SSH config added: $addResult"
        
        # Step 2: Update SSH config for all VMs
        Write-Verbose "Running: egs-tool update-ssh-config"
        $updateResult = & egs-tool update-ssh-config 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "egs-tool update-ssh-config failed with exit code: $LASTEXITCODE"
            Write-Warning "Output: $updateResult"
            return $false
        }
        Write-Verbose "SSH config updated: $updateResult"
        
        return $true
    }
    catch {
        Write-Warning "Failed to setup EGS connection: $_"
        return $false
    }
}

function Get-CatletIp {
    <#
    .SYNOPSIS
    Gets the IP address of a catlet
    
    .PARAMETER Id
    The catlet ID
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id
    )
    
    try {
        $catlet = Get-Catlet -Id $Id
        if ($catlet.Networks -and $catlet.Networks.Count -gt 0) {
            $network = $catlet.Networks[0]
            if ($network.IpV4Addresses -and $network.IpV4Addresses.Count -gt 0) {
                return @{
                    IpAddress = $network.IpV4Addresses[0].Address
                    Subnet = $network.IpV4Addresses[0].Subnet
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to get catlet IP: $_"
    }
    
    return $null
}

function Wait-CatletReady {
    <#
    .SYNOPSIS
    Waits for a catlet to be ready (combining network and EGS readiness)
    
    .PARAMETER VmId
    The VM ID to wait for
    
    .PARAMETER TimeoutMinutes
    Maximum time to wait in minutes
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,
        
        [int]$TimeoutMinutes = 10
    )
    
    return Wait-EGSReady -VmId $VmId -TimeoutMinutes $TimeoutMinutes
}

function Copy-PesterToVM {
    <#
    .SYNOPSIS
    Copies Pester module from host to VM for direct import
    
    .PARAMETER VmId
    The VM ID to copy to
    
    .PARAMETER OsType
    The OS type (windows or linux)
    
    .OUTPUTS
    Returns the path where Pester was copied
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("windows", "linux")]
        [string]$OsType
    )
    
    $pesterModule = Get-Module -ListAvailable Pester | 
        Where-Object { $_.Version.Major -ge 5 } | 
        Sort-Object Version -Descending | 
        Select-Object -First 1
    
    if (-not $pesterModule) {
        throw "Pester 5.x not found on host. Please install: Install-Module Pester -Force"
    }
    
    $targetPath = if ($OsType -eq "windows") { 
        "C:\Tests\Pester" 
    } else { 
        "/tmp/tests/Pester" 
    }
    
    Write-Information "Copying Pester module v$($pesterModule.Version) to VM: $targetPath" -InformationAction Continue
    $copyResult = Copy-DirectoryToVM -VmId $VmId -SourcePath $pesterModule.ModuleBase -TargetPath $targetPath -OsType $OsType
    
    # Only return the path, not the copy result
    return $targetPath
}

function Copy-DirectoryToVM {
    <#
    .SYNOPSIS
    Copies entire directory to VM using zip and egs-tool upload-file
    
    .PARAMETER VmId
    The VM ID to copy to
    
    .PARAMETER SourcePath
    Source directory path on host
    
    .PARAMETER TargetPath
    Target directory path on VM
    
    .PARAMETER OsType
    The OS type (windows or linux)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,
        
        [Parameter(Mandatory=$true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetPath,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("windows", "linux")]
        [string]$OsType
    )
    
    if (-not (Test-Path $SourcePath)) {
        throw "Source path not found: $SourcePath"
    }
    
    # Create a temporary zip file
    $tempZip = [System.IO.Path]::GetTempFileName() + ".zip"
    Write-Verbose "Creating temporary zip: $tempZip"
    
    try {
        # Compress the directory
        Compress-Archive -Path "$SourcePath\*" -DestinationPath $tempZip -Force
        
        # Upload the zip file using egs-tool
        $targetZip = if ($OsType -eq "windows") { "C:\Windows\Temp\transfer.zip" } else { "/tmp/transfer.zip" }
        Write-Information "Uploading zip file via egs-tool: $tempZip -> $targetZip" -InformationAction Continue
        Write-Verbose "Zip file size: $((Get-Item $tempZip).Length) bytes"
        
        $uploadResult = & egs-tool upload-file $VmId $tempZip $targetZip 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "egs-tool upload failed with exit code: $LASTEXITCODE"
            Write-Warning "Output: $uploadResult"
            throw "Failed to upload zip file: $uploadResult"
        }
        Write-Verbose "Upload successful"
        
        # Verify zip was uploaded
        if ($OsType -eq "windows") {
            $verifyZipCmd = "powershell -Command `"if (Test-Path '$targetZip') { (Get-Item '$targetZip').Length } else { 'NOT_FOUND' }`""
        } else {
            $verifyZipCmd = "if [ -f '$targetZip' ]; then stat -c%s '$targetZip'; else echo 'NOT_FOUND'; fi"
        }
        $zipSize = Invoke-EGSCommand -VmId $VmId -Command $verifyZipCmd
        if ($zipSize -eq "NOT_FOUND" -or $zipSize -eq $null) {
            throw "Zip file was not uploaded to VM at $targetZip"
        }
        Write-Verbose "Zip file on VM: $zipSize bytes"
        
        # Extract the zip on the target VM
        if ($OsType -eq "windows") {
            # Ensure target directory exists and extract
            Write-Verbose "Extracting zip on Windows VM to: $TargetPath"
            
            # Create parent directory first
            $parentDir = Split-Path $TargetPath -Parent
            if ($parentDir -and $parentDir -ne '\') {
                $mkdirCmd = "powershell -Command `"New-Item -Path '$parentDir' -ItemType Directory -Force | Out-Null`""
                Invoke-EGSCommand -VmId $VmId -Command $mkdirCmd
            }
            
            # Now extract
            $extractCmd = "powershell -Command `"if (Test-Path '$TargetPath') { Remove-Item '$TargetPath' -Recurse -Force }; New-Item -Path '$TargetPath' -ItemType Directory -Force | Out-Null; Expand-Archive -Path '$targetZip' -DestinationPath '$TargetPath' -Force; Remove-Item '$targetZip' -Force`""
            
            $extractResult = Invoke-EGSCommand -VmId $VmId -Command $extractCmd
            Write-Verbose "Extract result: $extractResult"
            
            # Verify extraction worked
            $verifyCmd = "powershell -Command `"Test-Path '$TargetPath'`""
            $exists = Invoke-EGSCommand -VmId $VmId -Command $verifyCmd
            if ($exists -ne "True") {
                throw "Failed to extract directory to $TargetPath"
            }
        } else {
            # Linux extraction
            $extractCmd = @"
rm -rf '$TargetPath' 2>/dev/null
mkdir -p '$TargetPath'
unzip -q '$targetZip' -d '$TargetPath'
rm -f '$targetZip'
"@
            Invoke-EGSCommand -VmId $VmId -Command $extractCmd
        }
        
        Write-Verbose "Directory successfully copied to VM"
        return $true
    }
    finally {
        # Clean up temp zip
        if (Test-Path $tempZip) {
            Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
        }
    }
}

function Copy-MultipleFilesToVM {
    <#
    .SYNOPSIS
    Copies multiple files to VM in batch
    
    .PARAMETER VmId
    The VM ID to copy to
    
    .PARAMETER FileMappings
    Array of hashtables with Source and Target keys
    
    .PARAMETER OsType
    The OS type (windows or linux)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,
        
        [Parameter(Mandatory=$true)]
        [hashtable[]]$FileMappings,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("windows", "linux")]
        [string]$OsType
    )
    
    foreach ($mapping in $FileMappings) {
        if (-not $mapping.Source -or -not $mapping.Target) {
            throw "Invalid file mapping. Must have Source and Target keys"
        }
        Copy-FileToVM -VmId $VmId -Source $mapping.Source -Target $mapping.Target -OsType $OsType
    }
}

function Invoke-PesterInVM {
    <#
    .SYNOPSIS
    Runs Pester tests inside VM with proper setup
    
    .PARAMETER VmId
    The VM ID to run tests in
    
    .PARAMETER TestPath
    Path to test files in the VM
    
    .PARAMETER OsType
    The OS type (windows or linux)
    
    .PARAMETER PesterPath
    Path to Pester module in VM (optional, uses default)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,
        
        [Parameter(Mandatory=$true)]
        [string]$TestPath,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("windows", "linux")]
        [string]$OsType,
        
        [string]$PesterPath
    )
    
    if (-not $PesterPath) {
        $PesterPath = if ($OsType -eq "windows") { "C:\Tests\Pester" } else { "/tmp/tests/Pester" }
    }
    
    $command = if ($OsType -eq "windows") {
        @"
`$ErrorActionPreference = 'Stop'
try {
    Import-Module '$PesterPath' -Force
    `$config = New-PesterConfiguration
    `$config.Run.Path = '$TestPath'
    `$config.Run.PassThru = `$true
    `$config.Output.Verbosity = 'Normal'
    `$result = Invoke-Pester -Configuration `$config
    
    if (`$result.FailedCount -eq 0) {
        Write-Host 'VALIDATION_PASSED: All tests passed'
        exit 0
    } else {
        Write-Host "VALIDATION_FAILED: `$(`$result.FailedCount) tests failed"
        `$result.Failed | ForEach-Object { 
            Write-Host "  - `$(`$_.ExpandedPath): `$(`$_.ErrorRecord.Exception.Message)" 
        }
        exit `$result.FailedCount
    }
} catch {
    Write-Host "VALIDATION_ERROR: `$_"
    exit 999
}
"@
    } else {
        # Linux with PowerShell Core
        @"
pwsh -c "
`$ErrorActionPreference = 'Stop'
try {
    Import-Module '$PesterPath' -Force
    `$config = New-PesterConfiguration
    `$config.Run.Path = '$TestPath'
    `$config.Run.PassThru = `$true
    `$config.Output.Verbosity = 'Normal'
    `$result = Invoke-Pester -Configuration `$config
    
    if (`$result.FailedCount -eq 0) {
        Write-Host 'VALIDATION_PASSED: All tests passed'
        exit 0
    } else {
        Write-Host \\\"VALIDATION_FAILED: `\\$(`\\$result.FailedCount) tests failed\\\"
        exit `\\$result.FailedCount
    }
} catch {
    Write-Host \\\"VALIDATION_ERROR: `\\$_\\\"
    exit 999
}
"
"@
    }
    
    $output = Invoke-EGSCommand -VmId $VmId -Command $command
    return $output
}

function Copy-TestSuiteToVM {
    <#
    .SYNOPSIS
    Copies complete test suite (Pester + test files) to VM
    
    .PARAMETER VmId
    The VM ID to copy to
    
    .PARAMETER TestSourcePath
    Path to test files on host
    
    .PARAMETER OsType
    The OS type (windows or linux)
    
    .OUTPUTS
    Returns hashtable with TestRoot, PesterPath, and RunnerPath
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,
        
        [Parameter(Mandatory=$true)]
        [string]$TestSourcePath,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("windows", "linux")]
        [string]$OsType
    )
    
    $testRoot = if ($OsType -eq "windows") { "C:\Tests" } else { "/tmp/tests" }
    
    # Copy Pester first
    Write-Information "Copying Pester module to VM..." -InformationAction Continue
    $pesterPath = Copy-PesterToVM -VmId $VmId -OsType $OsType
    
    # Copy test files
    Write-Information "Copying test files to VM..." -InformationAction Continue
    Copy-DirectoryToVM -VmId $VmId -SourcePath $TestSourcePath -TargetPath "$testRoot\validation" -OsType $OsType
    
    # Copy runner script (if it exists alongside tests, otherwise create it)
    Write-Information "Setting up test runner script..." -InformationAction Continue
    
    $runnerPath = if ($OsType -eq "windows") {
        "$testRoot\run-tests.ps1"
    } else {
        "$testRoot/run-tests.ps1"
    }
    
    # Check if runner.ps1 exists in test source directory
    $localRunnerPath = Join-Path $TestSourcePath "runner.ps1"
    if (Test-Path $localRunnerPath) {
        # Use the pre-made runner script
        Write-Verbose "Using pre-made runner script from: $localRunnerPath"
        
        # Remove existing file if present
        Invoke-EGSCommand -VmId $VmId -Command "powershell -Command `"if (Test-Path '$runnerPath') { Remove-Item '$runnerPath' -Force }`"" | Out-Null
        
        # Upload the runner script
        $uploadResult = & egs-tool upload-file $VmId $localRunnerPath $runnerPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to upload runner script: $uploadResult"
        }
    } else {
        # Create runner script dynamically (fallback)
        Write-Verbose "Creating runner script dynamically"
        $runnerScript = @"
param([string]`$TestPattern = '*.Tests.ps1')
`$ErrorActionPreference = 'Stop'
Import-Module '$pesterPath' -Force
`$config = New-PesterConfiguration
`$config.Run.Path = '$testRoot\validation\' + `$TestPattern
`$config.Run.PassThru = `$true
`$config.Output.Verbosity = 'Normal'
`$result = Invoke-Pester -Configuration `$config

Write-Host ''
Write-Host ('Test Summary: Total=' + `$result.TotalCount + ' Passed=' + `$result.PassedCount + ' Failed=' + `$result.FailedCount)

if (`$result.FailedCount -gt 0) {
    Write-Host 'Failed tests:'
    `$result.Failed | ForEach-Object { Write-Host ('  - ' + `$_.ExpandedPath) }
}

exit `$result.FailedCount
"@
        
        if ($OsType -eq "windows") {
            # Create a temp file with the script content and upload it
            $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
            try {
                Set-Content -Path $tempScript -Value $runnerScript -Force
                
                # Remove existing file if present
                Invoke-EGSCommand -VmId $VmId -Command "powershell -Command `"if (Test-Path '$runnerPath') { Remove-Item '$runnerPath' -Force }`"" | Out-Null
                
                # Upload the script
                $uploadResult = & egs-tool upload-file $VmId $tempScript $runnerPath 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Failed to upload runner script: $uploadResult"
                }
            }
            finally {
                if (Test-Path $tempScript) {
                    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
                }
            }
        } else {
            # For Linux, we need to write the file differently to avoid here-string issues
            # First escape the script content for safe transmission
            $escapedScript = $runnerScript -replace "'", "''" -replace "`n", "``n" -replace "`r", ""
            # Write the file using echo with escaped content
            $writeCmd = "echo '$escapedScript' | pwsh -c `"Set-Content -Path '$runnerPath' -Value `$input`""
            Invoke-EGSCommand -VmId $VmId -Command $writeCmd
            Invoke-EGSCommand -VmId $VmId -Command "chmod +x '$runnerPath'"
        }
    }
    
    return @{
        TestRoot = $testRoot
        PesterPath = $pesterPath
        RunnerPath = $runnerPath
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Wait-EGSReady',
    'Invoke-EGSCommand',
    'Get-CloudbaseInitLog',
    'Get-CloudInitLog',
    'Get-CloudInitLogs',
    'Copy-FileToVM',
    'Copy-TestsToVM',
    'Initialize-EGSConnection',
    'Get-CatletIp',
    'Wait-CatletReady',
    'Copy-PesterToVM',
    'Copy-DirectoryToVM',
    'Copy-MultipleFilesToVM',
    'Invoke-PesterInVM',
    'Copy-TestSuiteToVM'
)
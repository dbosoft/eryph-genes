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
    Write-Information ('Waiting for EGS to be ready on VM: ' + $VmId + ' (timeout: ' + $TimeoutMinutes + ' minutes)') -InformationAction Continue
    
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
                Write-Information ('EGS is available on VM: ' + $VmId + ' (after ' + $stopwatch.Elapsed.TotalSeconds.ToString('F1') + ' seconds)') -InformationAction Continue
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
    
    try {
        # Use timeout to prevent hanging (host key verification already disabled by EGS).
        # The egs-tool SSH config routes the .hyper-v.alt alias through a ProxyCommand,
        # so a plain `ssh` works regardless of which OpenSSH build is first on PATH.
        $result = & ssh -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=3 `
            "$VmId.hyper-v.alt" -C $Command 2>$null
        
        return $result
    }
    catch {
        Write-Warning "Failed to execute command on VM $VmId : $_"
        return $null
    }
}

function Get-EgsServiceLog {
    <#
    .SYNOPSIS
    Retrieves the egs-service agent log from a Windows VM.

    .DESCRIPTION
    eryph-guest-services (the cloudbase-init replacement) writes its
    operational log - datasource, every module, reboots, SSH events - to
    C:\ProgramData\eryph\guest-services\logs\agent.log. Per-script output is in
    C:\ProgramData\eryph\provisioning\logs\, the overall result in
    C:\ProgramData\eryph\provisioning\state.json (see Save-ProvisioningDiagnostics).

    .PARAMETER VmId
    The VM ID to get logs from

    .PARAMETER Tail
    Number of lines to return from the end of the log. Default 200.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,

        [int]$Tail = 200
    )

    # The EGS shell on Windows is PowerShell, so the cmdlet runs directly.
    return Invoke-EGSCommand -VmId $VmId `
        -Command "Get-Content -LiteralPath C:\ProgramData\eryph\guest-services\logs\agent.log -Tail $Tail"
}

function Get-CloudbaseInitLog {
    <#
    .SYNOPSIS
    Deprecated: cloudbase-init has been replaced by egs-service on Windows
    catlets built by hyperv-boxes. Forwards to Get-EgsServiceLog so existing
    callers keep working; new code should call Get-EgsServiceLog directly.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId
    )

    Write-Warning "Get-CloudbaseInitLog is deprecated — Windows catlets no longer ship cbi. Returning the egs-service agent log instead."
    return Get-EgsServiceLog -VmId $VmId
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
    Retrieves provisioning-agent logs based on OS type.

    Windows → Get-EgsServiceLog (egs agent.log).
    Linux   → Get-CloudInitLog (/var/log/cloud-init.log — cloud-init is still
              the Linux provisioning agent; eryph-guest-services on Linux runs
              alongside it, not as a replacement).

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
        return Get-EgsServiceLog -VmId $VmId
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
        Write-Information ('Setting up EGS connection for VM: ' + $VmId) -InformationAction Continue

        # Register the SSH config for this VM. egs-tool writes the .hyper-v.alt
        # alias (ProxyCommand over the Hyper-V socket) and exchanges keys via KVP;
        # the former separate `update-ssh-config` step is no longer required.
        Write-Verbose "Running: egs-tool add-ssh-config $VmId"
        $addResult = & egs-tool add-ssh-config $VmId 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "egs-tool add-ssh-config failed with exit code: $LASTEXITCODE"
            Write-Warning "Output: $addResult"
            return $false
        }
        Write-Verbose "SSH config added: $addResult"

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
        'C:\Tests\Pester' 
    } else { 
        '/tmp/tests/Pester' 
    }
    
    Write-Information ('Copying Pester module v' + $pesterModule.Version + ' to VM: ' + $targetPath) -InformationAction Continue
    
    # Copy all files individually via EGS (handles binary files like DLLs correctly)
    $copyResult = Copy-DirectoryToVM -VmId $VmId -SourcePath $pesterModule.ModuleBase -TargetPath $targetPath -OsType $OsType
    
    if (-not $copyResult) {
        throw 'Failed to copy Pester module to VM'
    }
    
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
    
    # Create target directory on VM first
    if ($OsType -eq "windows") {
        $mkdirCmd = "powershell -Command `"New-Item -Path '$TargetPath' -ItemType Directory -Force | Out-Null`""
    } else {
        $mkdirCmd = "mkdir -p '$TargetPath'"
    }
    Invoke-EGSCommand -VmId $VmId -Command $mkdirCmd | Out-Null
    
    # Get all files to copy (recursively)
    $allFiles = Get-ChildItem -Path $SourcePath -File -Recurse
    $totalFiles = $allFiles.Count
    Write-Information ('Copying ' + $totalFiles + ' files individually via EGS...') -InformationAction Continue
    
    $successCount = 0
    $failedCount = 0
    
    foreach ($file in $allFiles) {
        $relativePath = $file.FullName.Substring($SourcePath.Length).TrimStart('\', '/')
        
        if ($OsType -eq "windows") {
            $targetFile = $TargetPath + '\' + $relativePath.Replace('/', '\')
        } else {
            $targetFile = $TargetPath + '/' + $relativePath.Replace('\', '/')
        }
        
        # Create target directory for this file
        $targetDir = Split-Path $targetFile -Parent
        if ($OsType -eq "windows") {
            $mkdirCmd = "powershell -Command `"New-Item -Path '$targetDir' -ItemType Directory -Force | Out-Null`""
        } else {
            $mkdirCmd = "mkdir -p '$targetDir'"
        }
        Invoke-EGSCommand -VmId $VmId -Command $mkdirCmd | Out-Null
        
        # Upload individual file using egs-tool
        Write-Verbose "Copying: $relativePath"
        $uploadResult = & egs-tool upload-file $VmId $file.FullName $targetFile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $successCount++
        } else {
            $failedCount++
            Write-Warning "Failed to copy $relativePath : $uploadResult"
        }
    }
    
    Write-Information ('File copy complete: ' + $successCount + ' succeeded, ' + $failedCount + ' failed') -InformationAction Continue
    
    if ($failedCount -gt 0) {
        Write-Warning "Some files failed to copy. Check individual file warnings above."
    }
    
    return ($failedCount -eq 0)
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
    $validationPath = if ($OsType -eq "windows") { "$testRoot\validation" } else { "$testRoot/validation" }
    Copy-DirectoryToVM -VmId $VmId -SourcePath $TestSourcePath -TargetPath $validationPath -OsType $OsType
    
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

function Invoke-EGSCommandWithExitCode {
    <#
    .SYNOPSIS
    Runs a command on a VM via EGS/SSH and returns its output and exit code

    .DESCRIPTION
    Like Invoke-EGSCommand, but keeps the remote exit code (ssh returns it as
    its own exit code). On Windows guests the command runs in PowerShell, on
    Linux guests in the default shell as root.

    .OUTPUTS
    Hashtable with Output (string[]) and ExitCode (int)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,

        [Parameter(Mandatory=$true)]
        [string]$Command
    )

    # -n: the guest never closes a command's stdin (eryph-org/guest-services#68),
    # so give ssh nothing to forward.
    $output = & ssh -n -o ConnectTimeout=10 -o ServerAliveInterval=5 -o ServerAliveCountMax=3 `
        "$VmId.hyper-v.alt" -C $Command 2>&1
    return @{
        Output = @($output | ForEach-Object { "$_" })
        ExitCode = $LASTEXITCODE
    }
}

function Get-OsTypeForGeneset {
    <#
    .SYNOPSIS
    Maps a base geneset (e.g. winsrv2022-standard, dbosoft/ubuntu-24.04/starter) to windows or linux
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Geneset
    )

    $name = ($Geneset -split '/') | Where-Object { $_ -match '^(win|ubuntu|debian|alma|rocky|oracle|centos|fedora|rhel)' } | Select-Object -First 1
    if (-not $name) {
        $name = if ($Geneset -match '/') { ($Geneset -split '/')[1] } else { $Geneset }
    }

    if ($name -match '^win') { return 'windows' }
    if ($name -match '^(ubuntu|debian|alma|rocky|oracle|centos|fedora|rhel)') { return 'linux' }
    throw "Cannot tell whether '$Geneset' is a Windows or Linux geneset. Add it to Get-OsTypeForGeneset."
}

function Wait-ProvisioningComplete {
    <#
    .SYNOPSIS
    Waits until the guest finished provisioning (all fodder ran)

    .DESCRIPTION
    EGS reports "available" as soon as the guest's SSH server is up, which is
    usually before the fodder has finished running.
    Windows (egs-service): waits until C:\ProgramData\eryph\provisioning\state.json
    lists the Final stage as completed. Linux (cloud-init): waits until
    `cloud-init status` leaves the running state. Connection failures while
    the guest reboots during provisioning are tolerated.

    .OUTPUTS
    Hashtable with Completed (bool), Failed (bool) and Detail (string)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,

        [Parameter(Mandatory=$true)]
        [ValidateSet("windows", "linux")]
        [string]$OsType,

        [int]$TimeoutMinutes = 30
    )

    $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
    $detail = 'no provisioning status read yet'

    while ((Get-Date) -lt $deadline) {
        if ($OsType -eq 'windows') {
            $result = Invoke-EGSCommandWithExitCode -VmId $VmId `
                -Command 'Get-Content -LiteralPath C:\ProgramData\eryph\provisioning\state.json -Raw'
            $raw = ($result.Output -join "`n").Trim()
            if ($result.ExitCode -eq 0 -and $raw) {
                $detail = $raw
                try {
                    $state = $raw | ConvertFrom-Json
                    if (@($state.completedStages) -contains 'Final') {
                        # state.json is success-only on a clean run; a property
                        # named failed*/error*/failure* means a handler failed.
                        $failureProps = $state.PSObject.Properties.Name |
                            Where-Object { $_ -match '^(failed|errors?|failures?)' }

                        # A failing script does not stop provisioning on Windows
                        # and does not show up in state.json; its per-script log
                        # does ("exit-code: <n>"). 1001/1003 are reboot requests.
                        $exitCodes = Invoke-EGSCommandWithExitCode -VmId $VmId `
                            -Command "Select-String -Path C:\ProgramData\eryph\provisioning\logs\*.log -Pattern '^exit-code: (-?\d+)' | ForEach-Object { `$_.Filename + ' ' + `$_.Matches[0].Groups[1].Value }"
                        $failedScripts = @($exitCodes.Output | Where-Object { $_ -match '^(\S+) (-?\d+)$' -and $Matches[2] -notin '0', '1001', '1003' })

                        $detail = $raw
                        if ($failedScripts) {
                            $detail = "Failed scripts (see C:\ProgramData\eryph\provisioning\logs): $($failedScripts -join ', ')`n$raw"
                        }
                        return @{ Completed = $true; Failed = ([bool]$failureProps -or [bool]$failedScripts); Detail = $detail }
                    }
                } catch {
                    # state.json is rewritten while provisioning runs; read again
                }
            }
        } else {
            $result = Invoke-EGSCommandWithExitCode -VmId $VmId -Command 'cloud-init status --long < /dev/null'
            $text = ($result.Output -join "`n").Trim()
            if ($text) {
                $detail = $text
                if ($text -match 'status:\s*(done|error|degraded)') {
                    return @{ Completed = $true; Failed = ($Matches[1] -ne 'done'); Detail = $text }
                }
            }
        }

        Start-Sleep -Seconds 10
    }

    return @{ Completed = $false; Failed = $true; Detail = "Timed out after $TimeoutMinutes minutes. Last status: $detail" }
}

function Save-ProvisioningDiagnostics {
    <#
    .SYNOPSIS
    Copies the guest's provisioning state and logs into a host directory

    .DESCRIPTION
    Windows: state.json, the egs agent.log and every per-script log.
    Linux: cloud-init status, cloud-init.log, cloud-init-output.log and the
    rendered user scripts.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$VmId,

        [Parameter(Mandatory=$true)]
        [ValidateSet("windows", "linux")]
        [string]$OsType,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )

    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

    $commands = if ($OsType -eq 'windows') {
        [ordered]@{
            'state.json' = 'Get-Content -LiteralPath C:\ProgramData\eryph\provisioning\state.json -Raw'
            'agent.log' = 'Get-Content -LiteralPath C:\ProgramData\eryph\guest-services\logs\agent.log -Tail 500'
            'script-logs.txt' = 'Get-ChildItem C:\ProgramData\eryph\provisioning\logs -Filter *.log | ForEach-Object { "===== $($_.Name)"; Get-Content -LiteralPath $_.FullName }'
        }
    } else {
        [ordered]@{
            'cloud-init-status.txt' = 'cloud-init status --long < /dev/null'
            'cloud-init.log' = 'tail -n 500 /var/log/cloud-init.log'
            'cloud-init-output.log' = 'cat /var/log/cloud-init-output.log'
            'scripts.txt' = 'for f in /var/lib/cloud/instance/scripts/*; do echo "===== $f"; cat "$f"; done'
        }
    }

    foreach ($file in $commands.Keys) {
        $result = Invoke-EGSCommandWithExitCode -VmId $VmId -Command $commands[$file]
        Set-Content -Path (Join-Path $OutputPath $file) -Value $result.Output
    }

    Write-Information "Provisioning diagnostics saved to: $OutputPath" -InformationAction Continue
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
    'Copy-TestSuiteToVM',
    'Get-EgsServiceLog',
    'Invoke-EGSCommandWithExitCode',
    'Get-OsTypeForGeneset',
    'Wait-ProvisioningComplete',
    'Save-ProvisioningDiagnostics'
)

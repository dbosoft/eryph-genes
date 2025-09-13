function Get-CloudbaseInitUserDataError {
    <#
    .SYNOPSIS
    Retrieves user data stderr error messages from Cloudbase-Init log content.

    .DESCRIPTION
    This function scans the provided Cloudbase-Init log content for lines containing errors related to user data execution, specifically `stderr` messages. It extracts and outputs only the message inside the raw byte strings for better readability.

    .PARAMETER LogContent
    The content of the Cloudbase-Init log as a string array.

    .EXAMPLE
    gc .\cloudbase-init.log | Get-CloudbaseInitUserDataError
    Scans the provided log content for user data errors and outputs the cleaned-up matching lines.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $true)]
        [string]$LogContent
    )

    begin {
        $lines = @()
    }
    process {
        if ($null -ne $LogContent -and $LogContent -ne "") {
            # If LogContent is a single string with line breaks, split it into lines
            if ($LogContent -is [string] -and $LogContent -match "(\r\n|\n)") {
                $lines += $LogContent -split "`r?`n"
            } else {
                $lines += $LogContent
            }
        }
    }
    end {
        if (-not $lines -or $lines.Count -eq 0) {
            Write-Warning "LogContent is empty."
            return
        }

        $logStartPattern = '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} \d+ (DEBUG|INFO|ERROR|WARNING) [\w\.\-]+ \[\-\]'
        $currentLogLine = ""
        $logLines = @()

        foreach ($line in $lines) {
            if ($line -match $logStartPattern) {
                if ($currentLogLine) {
                    $logLines += $currentLogLine
                }
                $currentLogLine = $line
            } else {
                $currentLogLine += "`n$line"
            }
        }
        if ($currentLogLine) {
            $logLines += $currentLogLine
        }

        # Look for script failures (non-zero exit codes) and stderr output
        $errors = @()
        
        foreach ($logLine in $logLines) {
            # Check for script failures with non-zero exit codes
            if ($logLine -match "Script .* ended with exit code: (\d+)") {
                $exitCode = [int]$matches[1]
                if ($exitCode -ne 0) {
                    if ($logLine -match "Script `"([^`"]+)`".*ended with exit code: (\d+)") {
                        $scriptName = $matches[1]
                        $errors += "Script '$scriptName' failed with exit code $exitCode"
                    } else {
                        $errors += "Script failed with exit code $exitCode"
                    }
                }
            }
            
            # Also check for stderr output (original functionality)
            elseif ($logLine -match "User_data stderr") {
                if ($logLine -match "b(['`"])(.*?)(\1)") {
                    $msg = $matches[2] -replace "\\r\\n|\\n", "`n"
                    # Only add non-empty messages
                    if ($msg -and $msg.Trim() -ne "") {
                        $errors += $msg
                    }
                }
            }
        }

        # Filter out any empty or null entries
        $cleanErrors = $errors | Where-Object { $_ -and $_.Trim() -ne "" }
        
        if ($cleanErrors.Count -gt 0) {
            Write-Information "fodder command error(s) found in Cloudbase-Init log:" -InformationAction Continue
            $cleanErrors | ForEach-Object { Write-Output $_ }
        }
    }
}

Export-ModuleMember -Function Get-CloudbaseInitUserDataError

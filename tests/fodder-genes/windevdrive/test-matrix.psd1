# test-matrix.psd1 - windevdrive fodder gene. Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            # Dedicated eryph drive
            Name = "DevDriveDisk"
            OSMatrix = @("win11-24h2-enterprise")
            CatletSpec = "catlets/configure.yaml"
            HostTests = @(
                @{ Name = "E: is ReFS"; Command = "(Get-Volume -DriveLetter E).FileSystem"; Expect = 'ReFS' }
                @{ Name = "E: is labeled DevDrive"; Command = "(Get-Volume -DriveLetter E).FileSystemLabel"; Expect = 'DevDrive' }
                @{ Name = "E: is a trusted dev drive"; Command = "fsutil devdrv query E:"; Expect = '(?i)trusted' }
                @{ Name = "package caches point to E:"; Command = "[Environment]::GetEnvironmentVariable('NUGET_PACKAGES','Machine')"; Expect = '^E:' }
            )
        }
        @{
            # VHDX on C:, attached again at startup by a scheduled task
            Name = "DevDriveVhd"
            OSMatrix = @("win11-24h2-enterprise")
            CatletSpec = "catlets/location-vhd.yaml"
            HostTests = @(
                @{ Name = "VHDX exists on C:"; Command = "Test-Path C:\DevDrives\DevDrive.vhdx"; Expect = 'True' }
                @{ Name = "E: is ReFS"; Command = "(Get-Volume -DriveLetter E).FileSystem"; Expect = 'ReFS' }
                @{ Name = "E: is a trusted dev drive"; Command = "fsutil devdrv query E:"; Expect = '(?i)trusted' }
                @{ Name = "startup task re-attaches the VHDX"; Command = "(Get-ScheduledTask -TaskName 'Mount Dev Drive DevDrive').State"; Expect = 'Ready' }
            )
        }
        @{
            # Space shrunk off C:
            Name = "DevDriveResize"
            OSMatrix = @("win11-24h2-enterprise")
            CatletSpec = "catlets/location-resize.yaml"
            HostTests = @(
                @{ Name = "E: is on the system disk"; Command = "(Get-Partition -DriveLetter E).DiskNumber -eq (Get-Partition -DriveLetter C).DiskNumber"; Expect = 'True' }
                @{ Name = "E: is ReFS"; Command = "(Get-Volume -DriveLetter E).FileSystem"; Expect = 'ReFS' }
                @{ Name = "E: is a trusted dev drive"; Command = "fsutil devdrv query E:"; Expect = '(?i)trusted' }
            )
        }
    )
}

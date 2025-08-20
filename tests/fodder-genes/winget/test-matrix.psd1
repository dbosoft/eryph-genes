# test-matrix.psd1
# Winget Fodder Gene Test Matrix
# Tests realistic winget scenarios across different Windows versions

@{
    TestSuites = @(
        @{
            Name = "WingetBasicFunctionality"
            Description = "Basic winget installation and functionality tests"
            OSMatrix = @("winsrv2019-standard", "winsrv2022-standard", "win10-20h2-enterprise", "win11-24h2-enterprise")
            CatletSpec = "catlets/basic-winget-test.yaml"
            HostTests = [ordered]@{
                "CheckWingetExecutable" = "winget --version"
                "ListSources" = "winget source list"
                "SearchSimplePackage" = "winget search notepad"
                "ShowPackageInfo" = "winget show Microsoft.WindowsTerminal"
            }
            InVMTests = @()  # No complex in-VM tests needed for basic functionality
        }
        
        @{
            Name = "WingetSourceManagement"
            Description = "Test winget source management capabilities"
            OSMatrix = @("winsrv2022-standard", "win10-20h2-enterprise", "win11-24h2-enterprise")  # Skip Server 2019 - limited winget support
            CatletSpec = "catlets/winget-source-test.yaml"
            HostTests = [ordered]@{
                "ListInitialSources" = "winget source list"
                "AddCustomSource" = "winget source add --name TestSource --arg https://pkgs.dev.azure.com/microsoft/microsoft/_packaging/microsoft-public-packages/nuget/v3/index.json --type Microsoft.Rest; if (`$LASTEXITCODE -eq 0) { 'Source added successfully' } else { 'Source add failed as expected' }"
                "ListSourcesAfterAdd" = "winget source list"
                "ResetSources" = "winget source reset --force"
                "ListSourcesAfterReset" = "winget source list"
            }
            InVMTests = @()
        }
        
        @{
            Name = "WingetPackageSearch"
            Description = "Test winget package search and information retrieval"
            OSMatrix = @("winsrv2022-standard", "win10-20h2-enterprise", "win11-24h2-enterprise")
            CatletSpec = "catlets/winget-search-test.yaml"
            HostTests = [ordered]@{
                "SearchPopularPackage" = "winget search 'Visual Studio Code'"
                "SearchWithTag" = "winget search --tag development"
                "SearchExactMatch" = "winget search --exact Microsoft.VisualStudioCode"
                "ShowDetailedInfo" = "winget show Microsoft.VisualStudioCode"
                "ListAvailableVersions" = "winget show Microsoft.VisualStudioCode --versions"
            }
            InVMTests = @()
        }
        
        @{
            Name = "WingetCompatibilityCheck"
            Description = "Verify winget compatibility and limitations on different OS versions"
            OSMatrix = @("winsrv2019-standard")  # Specifically test Server 2019 limitations
            CatletSpec = "catlets/winget-compatibility-test.yaml"
            HostTests = [ordered]@{
                "CheckOSSupport" = "Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object Caption, BuildNumber"
                "CheckWingetAvailability" = "if (Get-Command winget -ErrorAction SilentlyContinue) { winget --version } else { 'Winget not available - expected on Server 2019' }"
                "CheckAppInstaller" = "Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue | Select-Object Name, Version"
                "CheckWindowsAppsFolder" = "Get-ChildItem 'C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller*' -ErrorAction SilentlyContinue | Select-Object Name"
            }
            InVMTests = @()
        }
        
        @{
            Name = "WingetAdvancedFeatures"
            Description = "Test advanced winget features available on newer Windows versions"
            OSMatrix = @("win11-24h2-enterprise")  # Only test on Windows 11 where all features work
            CatletSpec = "catlets/winget-advanced-test.yaml"
            HostTests = [ordered]@{
                "CheckManifestValidation" = "winget validate --help"
                "ExportPackageList" = "winget export --output C:\temp\packages.json; if (Test-Path C:\temp\packages.json) { 'Export successful' } else { 'Export failed' }"
                "ImportPackageList" = "if (Test-Path C:\temp\packages.json) { winget import --import-file C:\temp\packages.json --ignore-unavailable --ignore-versions --accept-source-agreements --accept-package-agreements --disable-interactivity } else { 'No file to import' }"
                "CheckSettings" = "winget settings --help"
                "ListUpgrades" = "winget upgrade --include-unknown"
            }
            InVMTests = @()
        }
    )
}
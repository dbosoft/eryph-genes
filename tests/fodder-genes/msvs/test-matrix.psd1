# test-matrix.psd1 - msvs fodder gene
# Format: see tests/README.md. A Visual Studio installation takes 20-40 minutes;
# run with -ProvisioningTimeoutMinutes 90.

@{
    TestSuites = @(
        @{
            Name = "VS2022Community"
            OSMatrix = @("win11-24h2-enterprise")
            CatletSpec = "catlets/vs2022.yaml"
            HostTests = @(
                @{ Name = "devenv.exe is installed"; Command = "Test-Path 'C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe'"; Expect = 'True' }
                @{ Name = "vswhere finds the instance"; Command = "& `"`${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe`" -products * -property installationPath"; Expect = 'Community' }
            )
        }
        @{
            Name = "VS2026Community"
            OSMatrix = @("win11-24h2-enterprise")
            CatletSpec = "catlets/vs2026.yaml"
            HostTests = @(
                @{ Name = "devenv.exe is installed"; Command = "Test-Path 'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\devenv.exe'"; Expect = 'True' }
                @{ Name = "vswhere reports VS 18"; Command = "& `"`${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe`" -products * -property installationVersion"; Expect = '^18\.' }
                @{ Name = "package cache is in vs_cache_path"; Command = "Test-Path C:\VSCache"; Expect = 'True' }
            )
        }
    )
}

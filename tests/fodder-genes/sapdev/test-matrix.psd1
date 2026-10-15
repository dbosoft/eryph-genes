# test-matrix.psd1 - sapdev fodder gene. Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            Name = "SapDevTools"
            OSMatrix = @("win11-24h2-enterprise")
            CatletSpec = "catlets/sapdev-test.yaml"
            HostTests = @(
                @{ Name = "CAP cds is installed for all users"; Command = '$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine"); cds --version'; Expect = '@sap/cds' }
                @{ Name = "UI5 CLI is installed"; Command = "Test-Path C:\ProgramData\npm\ui5.cmd"; Expect = 'True' }
                @{ Name = "MTA build tool is installed"; Command = "Test-Path C:\ProgramData\npm\mbt.cmd"; Expect = 'True' }
                @{ Name = "npm prefix is on the system PATH"; Command = "[Environment]::GetEnvironmentVariable('Path','Machine')"; Expect = 'ProgramData.npm' }
                @{ Name = "cf CLI v8 is installed"; Command = "& 'C:\Program Files\CloudFoundry\cf.exe' --version"; Expect = 'version 8\.' }
                @{ Name = "multiapps plugin is available to all users"; Command = '$env:CF_PLUGIN_HOME = "C:\ProgramData\cf"; & "C:\Program Files\CloudFoundry\cf.exe" plugins'; Expect = '(?i)multiapps' }
                @{ Name = "BTP CLI is installed"; Command = "& 'C:\Program Files\SAP\btp-cli\btp.exe' --version"; Expect = '(?i)btp' }
            )
        }
    )
}

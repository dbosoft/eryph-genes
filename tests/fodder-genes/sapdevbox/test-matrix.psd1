# test-matrix.psd1 - sapdevbox catlet geneset. Format: see tests/README.md.
# Test a tag, e.g. .\Test-FodderGene.ps1 -Gene dbosoft/sapdevbox/win11-next -ProvisioningTimeoutMinutes 90

@{
    TestSuites = @(
        @{
            Name = "SapDevBox"
            OSMatrix = @("win11-24h2-enterprise")
            CatletSpec = "catlets/win11.yaml"
            HostTests = @(
                @{ Name = "C: was extended to the 127 GB disk"; Command = "[int]((Get-Volume -DriveLetter C).Size / 1GB)"; Expect = '^1[12]\d$' }
                @{ Name = "Visual Studio is not installed"; Command = "Test-Path 'C:\Program Files\Microsoft Visual Studio\18'"; Expect = 'False' }
                @{ Name = "E: is a trusted dev drive"; Command = "fsutil devdrv query E:"; Expect = '(?i)trusted' }
                @{ Name = "VS Code is installed"; Command = "Test-Path 'C:\Program Files\Microsoft VS Code\Code.exe'"; Expect = 'True' }
                @{ Name = "Fiori tools extension is prepared"; Command = "(Get-ChildItem 'C:\Program Files\Microsoft VS Code\bootstrap\extensions').Name -join ','"; Expect = 'SAPSE\.sap-ux-fiori-tools-extension-pack' }
                @{ Name = "CAP cds is installed"; Command = '$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine"); cds --version'; Expect = '@sap/cds' }
                @{ Name = "cf CLI with multiapps"; Command = '$env:CF_PLUGIN_HOME = "C:\ProgramData\cf"; & "C:\Program Files\CloudFoundry\cf.exe" plugins'; Expect = '(?i)multiapps' }
                @{ Name = "BTP CLI is installed"; Command = "Test-Path 'C:\Program Files\SAP\btp-cli\btp.exe'"; Expect = 'True' }
                @{ Name = "Eclipse with ADT is installed"; Command = "Get-ChildItem C:\eclipse\features -Directory -Filter 'com.sap.adt.core.devedition_*' | Select-Object -ExpandProperty Name"; Expect = '^com\.sap\.adt\.core' }
            )
        }
    )
}

# test-matrix.psd1 - sapadt fodder gene
# Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            Name = "SapAdtInstall"
            OSMatrix = @("win11-24h2-enterprise", "winsrv2022-standard")
            CatletSpec = "catlets/sapadt-test.yaml"
            HostTests = @(
                @{ Name = "Visual C++ v14 runtime is installed"; Command = "(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64').Installed"; Expect = '^1$' }
                @{ Name = "eclipse.exe is present"; Command = "Test-Path C:\eclipse\eclipse.exe"; Expect = 'True' }
                @{ Name = "bundled JRE is present"; Command = "Test-Path C:\eclipse\plugins\*justj*\jre\bin\java.exe"; Expect = 'True' }
                @{ Name = "ADT feature is installed"; Command = "Get-ChildItem C:\eclipse\features -Directory -Filter 'com.sap.adt.core.devedition_*' | Select-Object -ExpandProperty Name"; Expect = '^com\.sap\.adt\.core\.devedition_' }
                @{ Name = "Start menu shortcut exists"; Command = "Test-Path `"`$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Eclipse.lnk`""; Expect = 'True' }
            )
        }
    )
}

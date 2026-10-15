# test-matrix.psd1 - vscode fodder gene. Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            Name = "SystemInstall"
            OSMatrix = @("win11-24h2-enterprise")
            CatletSpec = "catlets/win-vscode.yaml"
            HostTests = @(
                @{ Name = "Code.exe is installed for all users"; Command = "Test-Path 'C:\Program Files\Microsoft VS Code\Code.exe'"; Expect = 'True' }
                @{ Name = "code is on the machine PATH"; Command = "[Environment]::GetEnvironmentVariable('Path','Machine')"; Expect = 'Microsoft VS Code.bin' }
                @{ Name = "code CLI runs"; Command = "& 'C:\Program Files\Microsoft VS Code\bin\code.cmd' --version"; Expect = '^\d+\.\d+\.\d+' }
            )
        }
    )
}

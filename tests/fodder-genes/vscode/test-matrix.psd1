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
                @{ Name = "extensions are registered for first logon"; Command = "(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\eryph-vscode-extensions').StubPath"; Expect = 'install-user-extensions\.ps1' }
                @{ Name = "extensions are installed at the first logon of a user"; Command = '$deadline = (Get-Date).AddMinutes(5); while (-not (Test-Path C:\Users\Admin\.vscode\extensions\ms-vscode.powershell-*) -and (Get-Date) -lt $deadline) { Start-Sleep 10 }; (Get-ChildItem C:\Users\Admin\.vscode\extensions -Directory -ErrorAction SilentlyContinue).Name -join '','''; Expect = 'ms-vscode\.powershell' }
                @{ Name = "code CLI runs"; Command = "& 'C:\Program Files\Microsoft VS Code\bin\code.cmd' --version"; Expect = '^\d+\.\d+\.\d+' }
            )
        }
    )
}

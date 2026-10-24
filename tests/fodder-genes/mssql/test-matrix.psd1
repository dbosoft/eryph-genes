# test-matrix.psd1 - mssql fodder gene
# Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            Name = "Express"
            OSMatrix = @("winsrv2022-standard")
            CatletSpec = "catlets/express.yaml"
            HostTests = @(
                @{ Name = "SQL Server service is running"; Command = 'Get-Service ''MSSQL$SQLEXPRESS'' | Select-Object -ExpandProperty Status'; Expect = '^Running$' }
                @{ Name = "listens on TCP 1433"; Command = '(Test-NetConnection -ComputerName 127.0.0.1 -Port 1433 -WarningAction SilentlyContinue).TcpTestSucceeded'; Expect = 'True' }
                @{ Name = "login can connect to its database"; Command = '$c=New-Object System.Data.SqlClient.SqlConnection ''Server=tcp:127.0.0.1,1433;Database=testdb;User ID=testuser;Password=Test-Passw0rd-123!;TrustServerCertificate=True''; $c.Open(); $cmd=$c.CreateCommand(); $cmd.CommandText=''SELECT DB_NAME()''; $cmd.ExecuteScalar(); $c.Close()'; Expect = 'testdb' }
            )
        }
    )
}

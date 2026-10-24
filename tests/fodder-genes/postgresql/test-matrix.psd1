# test-matrix.psd1 - postgresql fodder gene
# Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            Name = "Server"
            OSMatrix = @("debian-13", "almalinux-10")
            CatletSpec = "catlets/server.yaml"
            HostTests = @(
                @{ Name = 'postgresql service is active'; Command = 'systemctl is-active postgresql < /dev/null'; Expect = '^active$' }
                @{ Name = 'database exists'; Command = 'sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname=''testdb''" < /dev/null'; Expect = '^1$' }
                @{ Name = 'role exists'; Command = 'sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname=''testuser''" < /dev/null'; Expect = '^1$' }
                @{ Name = 'TLS is enabled'; Command = 'sudo -u postgres psql -tAc "SHOW ssl" < /dev/null'; Expect = '^on$' }
                @{ Name = 'listens on all interfaces'; Command = 'ss -ltn < /dev/null'; Expect = '(0\.0\.0\.0|\*|\[::\]):5432' }
                @{ Name = 'user can log in over TCP'; Command = 'PGPASSWORD=Test-Passw0rd-123 psql -h 127.0.0.1 -U testuser -d testdb -tAc "SELECT 1" < /dev/null'; Expect = '^1$' }
            )
        }
    )
}

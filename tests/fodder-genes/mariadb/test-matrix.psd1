# test-matrix.psd1 - mariadb fodder gene
# Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            Name = "Server"
            OSMatrix = @("debian-13", "almalinux-10")
            CatletSpec = "catlets/server.yaml"
            HostTests = @(
                @{ Name = "mariadb service is active"; Command = "systemctl is-active mariadb < /dev/null"; Expect = '^active$' }
                @{ Name = "database exists"; Command = "mariadb -N -e 'SHOW DATABASES' < /dev/null"; Expect = '(?m)^testdb$' }
                @{ Name = "user exists"; Command = "mariadb -N -e 'SELECT User FROM mysql.user' < /dev/null"; Expect = '(?m)^testuser$' }
                @{ Name = "TLS is enabled"; Command = "mariadb -N -e `"SHOW VARIABLES LIKE 'have_ssl'`" < /dev/null"; Expect = 'have_ssl\s+YES' }
                @{ Name = "listens on all interfaces"; Command = "ss -ltn < /dev/null"; Expect = '(0\.0\.0\.0|\*|\[::\]):3306' }
                @{ Name = "user can log in over TCP"; Command = "mariadb -u testuser -pTest-Passw0rd-123 -h 127.0.0.1 --ssl-verify-server-cert=0 -N -e 'SELECT 1' < /dev/null"; Expect = '^1$' }
            )
        }
    )
}

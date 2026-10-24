# test-matrix.psd1 - valkey fodder gene
# Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            Name = "Server"
            OSMatrix = @("debian-13", "almalinux-10")
            CatletSpec = "catlets/server.yaml"
            HostTests = @(
                @{ Name = 'valkey service is active'; Command = 'systemctl is-active valkey < /dev/null'; Expect = '^active$' }
                @{ Name = 'responds to PING with auth'; Command = 'valkey-cli -a Test-Redis-123 ping 2>/dev/null < /dev/null'; Expect = '^PONG$' }
                @{ Name = 'requires authentication'; Command = 'valkey-cli ping < /dev/null'; Expect = 'NOAUTH' }
                @{ Name = 'listens on all interfaces'; Command = 'ss -ltn < /dev/null'; Expect = '(0\.0\.0\.0|\*|\[::\]):6379' }
            )
        }
    )
}

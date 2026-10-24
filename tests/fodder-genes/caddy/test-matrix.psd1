# test-matrix.psd1 - caddy fodder gene
# Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            Name = "Proxy"
            OSMatrix = @("debian-13", "almalinux-10")
            CatletSpec = "catlets/proxy.yaml"
            HostTests = @(
                @{ Name = "caddy service is active"; Command = 'systemctl is-active caddy < /dev/null'; Expect = '^active$' }
                @{ Name = "serves backend over HTTPS"; Command = 'curl -sk --max-time 10 https://localhost/ < /dev/null'; Expect = 'CADDY-BACKEND-OK' }
                @{ Name = "redirects HTTP to HTTPS"; Command = 'curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://localhost/ < /dev/null'; Expect = '^308$' }
            )
        }
    )
}

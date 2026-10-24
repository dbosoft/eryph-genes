# test-matrix.psd1 - nextcloud fodder gene
# Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            Name = "Server"
            OSMatrix = @("debian-13", "almalinux-10")
            CatletSpec = "catlets/server.yaml"
            HostTests = @(
                @{ Name = "nextcloud reports installed"; Command = 'sudo -u $(stat -c %U /var/www/nextcloud/occ) php /var/www/nextcloud/occ status < /dev/null'; Expect = 'installed: true' }
                @{ Name = "database backend is mysql"; Command = 'sudo -u $(stat -c %U /var/www/nextcloud/occ) php /var/www/nextcloud/occ config:system:get dbtype < /dev/null'; Expect = '^mysql$' }
                @{ Name = "serves over HTTP"; Command = 'curl -s http://127.0.0.1/status.php < /dev/null'; Expect = '"installed":true' }
                @{ Name = "web server is active"; Command = 'systemctl is-active apache2 httpd 2>/dev/null < /dev/null'; Expect = '(?m)^active$' }
            )
        }
    )
}

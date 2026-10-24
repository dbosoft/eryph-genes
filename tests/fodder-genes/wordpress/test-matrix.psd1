# test-matrix.psd1 - wordpress fodder gene
# Format: see tests/README.md.

@{
    TestSuites = @(
        @{
            Name = "Server"
            OSMatrix = @("debian-13", "almalinux-10")
            CatletSpec = "catlets/server.yaml"
            HostTests = @(
                @{ Name = "wordpress is installed"; Command = 'sudo -u $(stat -c %U /var/www/wordpress/wp-config.php) /usr/local/bin/wp --path=/var/www/wordpress core is-installed < /dev/null' }
                @{ Name = "site title set"; Command = 'sudo -u $(stat -c %U /var/www/wordpress/wp-config.php) /usr/local/bin/wp --path=/var/www/wordpress option get blogname < /dev/null'; Expect = '^Eryph WordPress Test$' }
                @{ Name = "serves over HTTP"; Command = 'curl -s --max-time 10 http://localhost/ < /dev/null'; Expect = 'wp-(content|includes)' }
                @{ Name = "web server is active"; Command = 'systemctl is-active apache2 httpd 2>/dev/null < /dev/null'; Expect = '(?m)^active$' }
            )
        }
    )
}

# WordPress

This geneset contains fodder for installing a WordPress server on Linux, backed by a
MariaDB/MySQL database.

The fodder is cross-platform WordPress server fodder. It installs Apache and PHP, downloads the
latest WordPress release and installs it unattended with WP-CLI against an external
MariaDB/MySQL database. It uses mod_php on Debian/Ubuntu and php-fpm plus SELinux on the RHEL
family. It has been tested on Debian 13 and AlmaLinux 10 (it also works on Ubuntu and the RHEL
family).

## Usage

Deploy two catlets: a database catlet with the `dbosoft/mariadb` gene and an application catlet
with the WordPress gene. Set the application's `db_host` to the **name** of the database catlet —
eryph's internal DNS resolves catlet names within the project, so you don't need to look up its
IP address.

``` yaml
name: wordpress-db
parent: dbosoft/debian-13/starter

fodder:
 - source: gene:dbosoft/mariadb:server
   variables:
     - name: db_name
       value: wordpress
     - name: db_user
       value: wordpress
     - name: db_password
       value: change-me-please
       secret: true
```

``` yaml
name: wordpress-app
parent: dbosoft/debian-13/starter

memory:
  startup: 3072

fodder:
 - source: gene:dbosoft/wordpress:server
   variables:
     - name: db_host
       value: wordpress-db
     - name: db_name
       value: wordpress
     - name: db_user
       value: wordpress
     - name: db_password
       value: change-me-please
       secret: true
     - name: admin_password
       value: change-me-too
       secret: true
```

The `db_name`, `db_user` and `db_password` of the mariadb gene must match the ones of the
WordPress gene.

The fodder:

- installs Apache (mod_php on Debian/Ubuntu, php-fpm on the RHEL family) and the PHP modules
  WordPress needs
- downloads and extracts WordPress to `/var/www/wordpress`
- on the RHEL family configures SELinux (`httpd_can_network_connect_db`, and
  `httpd_sys_rw_content_t` on wp-content)
- installs WP-CLI to `/usr/local/bin/wp`
- writes `wp-config.php` and runs `wp core install`
- when `site_url` is empty, makes WordPress follow the request host (works via a NAT/forwarded
  address out of the box)
- opens port 80 when `firewalld` or `ufw` is active

WordPress is served over plain HTTP on port 80. For production use, put a TLS-terminating reverse
proxy (e.g. the `dbosoft/caddy` gene) in front of it and set `site_url` to the public HTTPS URL.

## Configuration

The following variables can be used to configure the `server` fodder:

- **db_host**  
  required, no default value

  The database server. Use the **name** of the database catlet (eryph's internal DNS resolves it
  within the project); an IP address or any resolvable hostname also works.

- **db_name**  
  default value: wordpress

  The name of the database.

- **db_user**  
  default value: wordpress

  The name of the database user.

- **db_password**  
  required, secret, no default value

  The password of the database user.

- **site_url**  
  optional, default value: empty

  The fixed site URL WordPress uses. When left empty (the default), WordPress follows the host the
  client used for each request, so the site works through a NAT/forwarded address out of the box
  without knowing that address in advance. Set it to a fixed address or domain (e.g.
  `https://blog.example.com`) for a stable canonical URL in production; WordPress then stores and
  always redirects to that URL.

- **site_title**  
  default value: WordPress

  The title of the site.

- **admin_user**  
  default value: admin

  The name of the WordPress administrator account.

- **admin_password**  
  required, secret, no default value

  The password of the WordPress administrator account.

- **admin_email**  
  default value: admin@example.com

  The email address of the WordPress administrator account.

- **wordpress_version**  
  default value: latest

  The WordPress version to install. Set it to a specific release like `6.7.1` to pin the version.

---


# Versioning

This geneset contains only fodder genes and is versioned with a major-minor version scheme.  

There is no patch version - when a bug is fixed, a new minor version will be released.  
A new major version is released when a gene is removed from the geneset. 

The tag latest is updated with each released version. If you want to have a stable reference, don't use the latest tag, use a specific version tag. 

----

# Contributing

This geneset is maintained by dbosoft and is open for contributions.  

You can find the repository for this geneset on [github.com/dbosoft/eryph-genes](https://github.com/dbosoft/eryph-genes).  

  

# License

All public dbosoft genesets are licensed under the [MIT License](https://opensource.org/licenses/MIT).


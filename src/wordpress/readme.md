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

The application catlet needs a **second drive** for its persistent state (the `wp-content`
directory and `wp-config.php`): see [Persistent state](#persistent-state) below. Without it the
provisioning fails on purpose rather than storing state that a redeploy would silently lose.

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

drives:
 - name: sdb
   size: 20

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
- downloads and extracts the WordPress code to `/var/www/wordpress`
- mounts the state drive at `/var/wordpress` and keeps `wp-content` and `wp-config.php` there
- on the RHEL family configures SELinux (`httpd_can_network_connect_db`, and
  `httpd_sys_rw_content_t` on the state directory)
- installs WP-CLI to `/usr/local/bin/wp`
- writes `wp-config.php` and runs `wp core install` on first deploy; re-attaches on a redeploy
- when `site_url` is empty, makes WordPress follow the request host (works via a NAT/forwarded
  address out of the box)
- opens port 80 when `firewalld` or `ufw` is active

WordPress is served over plain HTTP on port 80. For production use, put a TLS-terminating reverse
proxy (e.g. the `dbosoft/caddy` gene) in front of it and set `site_url` to the public HTTPS URL.

## Persistent state

WordPress keeps state the database does not: the `wp-content` directory (uploads, installed
plugins and themes) and `wp-config.php` with the database credentials and the generated auth keys
and salts. The OS disk is recreated from the gene on every deploy, so that state must live on a
**separate, persistent drive**.

Give the application catlet a second drive (any name/size; the example uses `sdb`, 20 GB). The
fodder formats it on first use (ext4, label `wordpress`), mounts it at `/var/wordpress`, and keeps
`wp-content` and `wp-config.php` there (symlinked into the webroot). On a **redeploy** the drive is
kept, so WordPress re-attaches to the existing installation instead of reinstalling. If no empty
drive is present, provisioning stops with a clear error rather than storing state that would not
survive.

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

{{> food_versioning_major_minor }}

{{> footer }}

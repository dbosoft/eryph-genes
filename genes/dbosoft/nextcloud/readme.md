# Nextcloud

This geneset contains fodder for installing a Nextcloud server on Linux, backed by a
MariaDB/MySQL database.

The fodder is cross-platform Nextcloud server fodder. It installs Apache and PHP, downloads the
latest Nextcloud release tarball and runs `occ maintenance:install` against an external
MariaDB/MySQL database. It has been tested on Debian 13 and AlmaLinux 10 (it also works on Ubuntu
and the RHEL family).

## Usage

Use two catlets: one database catlet with the `dbosoft/mariadb` gene and one application catlet
with the Nextcloud gene. `db_host` of the Nextcloud catlet must point at the address of the
database catlet.

``` yaml
name: nextcloud-db
parent: dbosoft/debian-13/starter

fodder:
 - source: gene:dbosoft/mariadb:server
   variables:
     - name: db_name
       value: nextcloud
     - name: db_user
       value: nextcloud
     - name: db_password
       value: change-me-please
       secret: true
```

``` yaml
name: nextcloud-app
parent: dbosoft/debian-13/starter

memory:
  startup: 3072

fodder:
 - source: gene:dbosoft/nextcloud:server
   variables:
     - name: db_host
       value: 10.0.0.10
     - name: db_name
       value: nextcloud
     - name: db_user
       value: nextcloud
     - name: db_password
       value: change-me-please
       secret: true
     - name: admin_user
       value: admin
     - name: admin_password
       value: change-me-too
       secret: true
```

The `db_name`, `db_user` and `db_password` of the mariadb gene must match the ones of the
Nextcloud gene.

The fodder:

- installs Apache (mod_php on Debian/Ubuntu, php-fpm on the RHEL family) and the PHP modules
  Nextcloud needs
- downloads and extracts Nextcloud to `/var/www/nextcloud`
- uses `/var/nextcloud-data` as data directory
- sets the PHP `memory_limit` to 512M
- on the RHEL family configures SELinux (`httpd_can_network_connect_db`, and
  `httpd_sys_rw_content_t` on config, apps and data)
- runs `occ maintenance:install`
- sets `trusted_domains` to the host name and the primary IP address
- opens port 80 when `firewalld` or `ufw` is active

Nextcloud is served over plain HTTP on port 80. For production use, put a TLS-terminating reverse
proxy in front of it.

## Configuration

The following variables can be used to configure the `server` fodder:

- **db_host**  
  required, no default value

  The address of the database server.

- **db_name**  
  default value: nextcloud

  The name of the database.

- **db_user**  
  default value: nextcloud

  The name of the database user.

- **db_password**  
  required, secret, no default value

  The password of the database user.

- **admin_user**  
  default value: admin

  The name of the Nextcloud administrator account.

- **admin_password**  
  required, secret, no default value

  The password of the Nextcloud administrator account.

- **nextcloud_version**  
  default value: latest

  The Nextcloud version to install. Set it to a specific release like `35.0.2` to pin the version.

- **trusted_domain**  
  optional, default value: empty

  An additional trusted domain, appended to the automatically detected ones (host name and
  primary IP address).

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


# Nextcloud

This geneset contains fodder for installing a Nextcloud server on Linux, backed by a
MariaDB/MySQL database.

The fodder is cross-platform Nextcloud server fodder. It installs Apache and PHP, downloads the
latest Nextcloud release tarball and runs `occ maintenance:install` against an external
MariaDB/MySQL database. It has been tested on Debian 13 and AlmaLinux 10 (it also works on Ubuntu
and the RHEL family).

## Usage

Deploy two catlets: a database catlet with the `dbosoft/mariadb` gene and an application catlet
with the Nextcloud gene. Set the application's `db_host` to the **name** of the database catlet —
eryph's internal DNS resolves catlet names within the project, so you don't need to look up its
IP address.

The application catlet needs a **second drive** for its persistent state (the data directory and
the generated `config.php`): see [Persistent state](#persistent-state) below. Without it the
provisioning fails on purpose rather than storing state that a redeploy would silently lose.

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

drives:
 - name: sdb
   size: 20

fodder:
 - source: gene:dbosoft/nextcloud:server
   variables:
     - name: db_host
       value: nextcloud-db
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
- downloads and extracts the Nextcloud code to `/var/www/nextcloud`
- mounts the state drive at `/var/nextcloud` and keeps the data directory and `config.php` there
- sets the PHP `memory_limit` to 512M
- on the RHEL family configures SELinux (`httpd_can_network_connect_db`, and
  `httpd_sys_rw_content_t` on the state directory and apps)
- runs `occ maintenance:install` on first deploy, and re-attaches + `occ upgrade` on a redeploy
- sets `trusted_domains` to the host name and the primary IP address
- opens port 80 when `firewalld` or `ufw` is active

Nextcloud is served over plain HTTP on port 80. For production use, put a TLS-terminating reverse
proxy in front of it.

## Persistent state

Nextcloud's state is split between the database and the application catlet: the catlet holds the
**data directory** (user files) and `config.php` with the generated `instanceid`, `secret` and
`passwordsalt`. The OS disk is recreated from the gene on every deploy, so that state must live on
a **separate, persistent drive** — otherwise a redeploy would lose it while the database keeps the
old installation, and provisioning would fail with *"The Login is already being used"*.

Give the application catlet a second drive (any name/size; the example uses `sdb`, 20 GB). The
fodder formats it on first use (ext4, label `nextcloud`), mounts it at `/var/nextcloud`, and stores
the data directory and `config.php` there. On a **redeploy** the drive is kept, so the fodder
re-attaches to the existing installation and runs `occ upgrade` instead of re-installing. If no
empty drive is present, provisioning stops with a clear error rather than storing state that would
not survive.

## Configuration

The following variables can be used to configure the `server` fodder:

- **db_host**  
  required, no default value

  The database server. Use the **name** of the database catlet (eryph's internal DNS resolves it
  within the project); an IP address or any resolvable hostname also works.

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

- **trusted_domains**  
  default value: `*`

  Space-separated list of additional trusted domains, appended to the automatically detected ones
  (host name and primary IP address). Nextcloud rejects requests whose `Host` header is not a
  trusted domain. The default `*` accepts any host, so the site works out of the box when reached
  through a NAT/forwarded address whose IP the catlet cannot know. For production, set this to the
  exact host name(s) users browse to (e.g. `cloud.example.com`) to restrict access.

---

{{> food_versioning_major_minor }}

{{> footer }}

# MariaDB

This geneset contains fodder for installing and configuring a MariaDB server on Linux.

The fodder is cross-platform across Linux families. It works on Debian/Ubuntu and on the
RHEL family (AlmaLinux, Rocky Linux, ...). It has been tested on Debian 13 and AlmaLinux 10.

## Usage

Add a gene reference to a Linux catlet, give it a data drive for its persistent state (see
[Persistent state](#persistent-state)), and set the password:

``` yaml
name: mariadb-server
parent: dbosoft/debian-13/starter

drives:
 - name: sdb
   size: 10
   location: mariadb-data

fodder:
 - source: gene:dbosoft/mariadb:server
   variables:
     - name: db_name
       value: appdb
     - name: db_user
       value: appuser
     - name: db_password
       value: change-me-please
       secret: true
```

The fodder:

- installs the MariaDB server
- mounts the state drive at the data directory `/var/lib/mysql` and initialises it on first use
- creates the database and a user with all privileges on that database
- enables TLS with a self-signed certificate (valid for 10 years, generated on first start)
- listens on all interfaces (`bind-address = 0.0.0.0`)
- opens port 3306/tcp when `firewalld` or `ufw` is active

## Persistent state

A database server's data must survive a redeploy, but the OS disk is recreated from the gene each
time. Give the catlet a second drive and make it **persistent** with an explicit `location`. This
is the key detail: `name` (`sdb`) only sets the device order inside the guest, while `location` is
the drive's identity on the host. Without a `location`, eryph assigns a throwaway storage id and
**deletes the drive together with the catlet**; with one, the drive lives independently of the
catlet and is re-attached on the next deploy. Pick a `location` that is unique within the project
(the example uses `mariadb-data`).

The fodder formats the drive on first use (ext4, label `mariadb`), mounts it at the data directory
`/var/lib/mysql` and initialises the databases there. On a **redeploy** — removing the catlet and
deploying it again with the same `location` — the drive is re-attached, so the existing databases
are used as-is. If no empty drive is present, provisioning stops with a clear error.

## Configuration

The following variables can be used to configure the `server` fodder:

- **db_name**  
  default value: db

  The name of the database that is created.

- **db_user**  
  default value: dbuser

  The name of the user that is created. The user gets all privileges on the database.

- **db_password**  
  required, secret, no default value

  The password of the database user.

- **allowed_host**  
  default value: %

  The host the user may connect from (the host part of the MariaDB account, e.g. `10.0.0.%`).
  `%` allows connections from any host.

---

{{> food_versioning_major_minor }}

{{> footer }}

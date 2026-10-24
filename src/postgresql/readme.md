# PostgreSQL

This geneset contains fodder for installing and configuring a PostgreSQL server on Linux.

The fodder is cross-platform across Linux families. It works on Debian/Ubuntu and on the
RHEL family (AlmaLinux, Rocky Linux, ...). It has been tested on Debian 13 and AlmaLinux 10.

## Usage

Add a gene reference to a Linux catlet, give it a data drive for its persistent state (see
[Persistent state](#persistent-state)), and set the password:

``` yaml
name: postgresql-server
parent: dbosoft/debian-13/starter

drives:
 - name: sdb
   size: 10

fodder:
 - source: gene:dbosoft/postgresql:server
   variables:
     - name: db_name
       value: appdb
     - name: db_user
       value: appuser
     - name: db_password
       value: change-me-please
       secret: true
```

The fodder pairs with an application catlet that connects to the database via its `db_host`
variable, set to the address of the PostgreSQL catlet.

The fodder:

- installs PostgreSQL and initialises its data directory on the state drive
- creates the database and a login role that owns it
- enables TLS with a self-signed certificate (valid for 10 years)
- listens on all interfaces (`listen_addresses = '*'`)
- adds a `pg_hba.conf` rule (`scram-sha-256`) that allows the role to connect from `allowed_host`
- opens port 5432/tcp when `firewalld` or `ufw` is active

## Persistent state

A database server's data must survive a redeploy, but the OS disk is recreated from the gene each
time. Give the catlet a second drive (any name/size; the example uses `sdb`, 10 GB); the fodder
formats it on first use (ext4, label `postgresql`) and puts the PostgreSQL data directory on it —
mounted at `/var/lib/pgsql/data` on the RHEL family, and at `/var/lib/postgresql/eryph/pgdata`
(with `data_directory` pointed there) on Debian/Ubuntu. On a **redeploy** the drive is kept, so the
existing databases are used as-is. If no empty drive is present, provisioning stops with a clear
error. (Guest device names are not stable, so the fodder selects the drive by label or as the
empty non-root disk, never by a fixed `/dev/sdX` name.)

## Configuration

The following variables can be used to configure the `server` fodder:

- **db_name**  
  default value: db

  The name of the database that is created.

- **db_user**  
  default value: dbuser

  The name of the login role that is created. The role owns the database.

- **db_password**  
  required, secret, no default value

  The password of the role.

- **allowed_host**  
  default value: 0.0.0.0/0

  The CIDR the role may connect from, written as a `pg_hba.conf` address (e.g. `10.0.0.0/24`).
  `0.0.0.0/0` allows any IPv4 host.

## TLS

The certificate is self-signed. A client only verifies it with `sslmode=verify-ca` or
`verify-full`; with the default `prefer` or `require` the connection is still encrypted.
Whether to trust the certificate is a decision of the client.

---

{{> food_versioning_major_minor }}

{{> footer }}

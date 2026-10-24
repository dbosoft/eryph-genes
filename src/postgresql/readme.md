# PostgreSQL

This geneset contains fodder for installing and configuring a PostgreSQL server on Linux.

The fodder is cross-platform across Linux families. It works on Debian/Ubuntu and on the
RHEL family (AlmaLinux, Rocky Linux, ...). It has been tested on Debian 13 and AlmaLinux 10.

## Usage

Add a gene reference to a Linux catlet and set the password:

``` yaml
name: postgresql-server
parent: dbosoft/debian-13/starter

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

- installs PostgreSQL and starts it (on the RHEL family it also runs `initdb`)
- creates the database and a login role that owns it
- enables TLS with a self-signed certificate (valid for 10 years)
- listens on all interfaces (`listen_addresses = '*'`)
- adds a `pg_hba.conf` rule (`scram-sha-256`) that allows the role to connect from `allowed_host`
- opens port 5432/tcp when `firewalld` or `ufw` is active

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

# MariaDB

This geneset contains fodder for installing and configuring a MariaDB server on Linux.

The fodder is cross-platform across Linux families. It works on Debian/Ubuntu and on the
RHEL family (AlmaLinux, Rocky Linux, ...). It has been tested on Debian 13 and AlmaLinux 10.

## Usage

Add a gene reference to a Linux catlet and set the password:

``` yaml
name: mariadb-server
parent: dbosoft/debian-13/starter

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

- installs the MariaDB server and starts it
- creates the database and a user with all privileges on that database
- enables TLS with a self-signed certificate (valid for 10 years, generated on first start)
- listens on all interfaces (`bind-address = 0.0.0.0`)
- opens port 3306/tcp when `firewalld` or `ufw` is active

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


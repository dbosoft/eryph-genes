# Microsoft SQL Server Express

This geneset contains fodder for installing Microsoft SQL Server Express on Windows.

The fodder installs the current release of SQL Server Express (SQL Server 2025 Express), enables
mixed-mode authentication and the static TCP port 1433, and creates a database plus a SQL login
that owns it. It has been tested on Windows Server 2022.

## Usage

Add a gene reference to a Windows catlet and set the passwords:

``` yaml
name: mssql-express
parent: dbosoft/winsrv2022-standard/starter

memory:
  startup: 4096

fodder:
 - source: gene:dbosoft/mssql:express
   variables:
     - name: sa_password
       value: change-me-Please-123!
       secret: true
     - name: db_name
       value: appdb
     - name: db_user
       value: appuser
     - name: db_password
       value: change-me-Too-456!
       secret: true
```

SQL Server Express needs some headroom, so give the catlet at least 4 GB of memory.

An application on another catlet connects to this one by its catlet name on port 1433
(eryph's internal DNS resolves the name).

## What the fodder does

- downloads and installs SQL Server Express (`SQLENGINE` feature) unattended
- enables SQL (mixed-mode) authentication with the given `sa` password
- sets a static TCP port 1433 (the installer defaults to a dynamic port)
- creates the database and a SQL login that is `db_owner` of it
- opens the Windows firewall for TCP 1433

The fodder is idempotent: it skips the installation when the instance already exists.

## Configuration

The following variables can be used to configure the `express` fodder:

- **sa_password**  
  required, secret, no default value

  The password for the SQL Server `sa` account.

- **db_name**  
  default value: db

  The name of the database that is created.

- **db_user**  
  default value: dbuser

  The name of the SQL login that is created. It becomes `db_owner` of the database.

- **db_password**  
  required, secret, no default value

  The password of the SQL login.

Passwords must satisfy SQL Server's strong-password policy (`CHECK_POLICY=ON`): at least
8 characters with a mix of upper case, lower case, digits and symbols. They must not contain a
single quote (`'`) or a double quote (`"`).

## Security

The `sa` account is enabled with the password you set, and the server listens on all interfaces
(port 1433 is open in the Windows firewall). Restrict network access appropriately.

---

{{> food_versioning_major_minor }}

{{> footer }}

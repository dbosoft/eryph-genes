# @dbosoft/mariadb-default

## 1.2.0

### Minor Changes

- Remove the anonymous accounts and test database that `mariadb-install-db` creates on a fresh datadir. Besides hardening the server, the anonymous `''@'localhost'` account otherwise shadowed `'%'` user accounts for local (127.0.0.1) connections, so an application co-located on the same catlet was denied access.

## 1.1.0

### Minor Changes

- Mount a required persistent state drive at the data directory `/var/lib/mysql` and initialise the databases there, so they survive a redeploy. Provisioning fails with a clear error when no empty data drive is present.

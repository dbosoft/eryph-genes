# @dbosoft/mariadb-default

## 1.1.0

### Minor Changes

- Mount a required persistent state drive at the data directory `/var/lib/mysql` and initialise the databases there, so they survive a redeploy. Provisioning fails with a clear error when no empty data drive is present.

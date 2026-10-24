# @dbosoft/postgresql-default

## 1.1.0

### Minor Changes

- Put the PostgreSQL data directory on a required persistent state drive so the databases survive a redeploy (RHEL family: mounted at `/var/lib/pgsql/data`; Debian/Ubuntu: at `/var/lib/postgresql/eryph/pgdata` with `data_directory` pointed there). The drive is selected by label or as the empty non-root disk, never by a fixed device name. Provisioning fails with a clear error when no empty data drive is present.

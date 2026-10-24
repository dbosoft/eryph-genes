# @dbosoft/nextcloud-default

## 1.2.0

### Minor Changes

- Store the data directory and `config.php` on a required persistent state drive, making the application catlet redeployable: a redeploy re-attaches to the existing installation (and runs `occ upgrade`) instead of failing with "The Login is already being used". The catlet now needs a second drive for its state; provisioning fails with a clear error when none is present.

## 1.1.0

### Minor Changes

- Make `trusted_domains` configurable and default it to `*` so Nextcloud is reachable via a NAT/forwarded address out of the box (previously only the host name and internal IP were trusted, so external access failed with "untrusted domain"). The readme now references the database catlet by name (resolved by eryph's internal DNS) instead of a placeholder IP.

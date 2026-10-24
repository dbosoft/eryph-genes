# @dbosoft/nextcloud-default

## 1.1.0

### Minor Changes

- Make `trusted_domains` configurable and default it to `*` so Nextcloud is reachable via a NAT/forwarded address out of the box (previously only the host name and internal IP were trusted, so external access failed with "untrusted domain"). The readme now references the database catlet by name (resolved by eryph's internal DNS) instead of a placeholder IP.

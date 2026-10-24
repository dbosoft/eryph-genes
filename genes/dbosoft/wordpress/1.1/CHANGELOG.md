# @dbosoft/wordpress-default

## 1.1.0

### Minor Changes

- Default `site_url` to empty so WordPress follows the host the client used (works via a NAT/forwarded address out of the box) instead of being pinned to a fixed URL that breaks external access. Set `site_url` for a fixed canonical URL in production. The readme now references the database catlet by name (eryph's internal DNS) instead of a placeholder IP.

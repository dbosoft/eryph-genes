# @dbosoft/wordpress-default

## 1.2.0

### Minor Changes

- Keep `wp-content` and `wp-config.php` on a required persistent state drive, making the application catlet redeployable: a redeploy re-attaches to the existing installation instead of reinstalling, and uploads/plugins/themes and the auth keys survive. The catlet now needs a second drive for its state; provisioning fails with a clear error when none is present.

## 1.1.0

### Minor Changes

- Default `site_url` to empty so WordPress follows the host the client used (works via a NAT/forwarded address out of the box) instead of being pinned to a fixed URL that breaks external access. Set `site_url` for a fixed canonical URL in production. The readme now references the database catlet by name (eryph's internal DNS) instead of a placeholder IP.

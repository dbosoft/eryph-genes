# @dbosoft/valkey-default

## 1.1.0

### Minor Changes

- Mount a required persistent state drive at the data directory `/var/lib/valkey`, so Valkey's saved data (RDB/AOF) survives a redeploy. Provisioning fails with a clear error when no empty data drive is present.

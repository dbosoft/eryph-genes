# Valkey

This geneset contains fodder for installing a Valkey server on Linux. Valkey is the open-source,
Redis-compatible (RESP) in-memory data store.

The RHEL family no longer packages Redis, so this gene standardises on Valkey, which both
Linux families provide. Clients and libraries that speak the Redis protocol work against it.

The fodder is cross-platform across Linux families. It works on Debian/Ubuntu and on the
RHEL family (AlmaLinux, Rocky Linux, ...). It has been tested on Debian 13 and AlmaLinux 10.

## Usage

Add a gene reference to a Linux catlet and optionally set a password:

``` yaml
name: valkey-server
parent: dbosoft/debian-13/starter

fodder:
 - source: gene:dbosoft/valkey:server
   variables:
     - name: password
       value: change-me-please
       secret: true
```

A typical use is a cache or session store for an application, for example a nextcloud or
wordpress catlet, which connects to this host on port 6379.

The fodder:

- installs Valkey (`valkey-server` on Debian/Ubuntu, `valkey` on the RHEL family) and starts it
- listens on all interfaces (`bind 0.0.0.0`, `protected-mode no`)
- sets `requirepass` when a password is given
- sets `maxmemory` and the `allkeys-lru` eviction policy when a memory limit is given
- opens port 6379/tcp when `firewalld` or `ufw` is active

## Configuration

The following variables can be used to configure the `server` fodder:

- **password**  
  optional, secret, default value: empty

  The authentication password (`requirepass`). Strongly recommended whenever the server is
  reachable from other hosts, as it listens on all interfaces. An empty value means no
  authentication.

- **maxmemory**  
  optional, default value: empty

  A memory limit such as `256mb` or `2gb`. When set, the eviction policy `allkeys-lru` is
  enabled. An empty value means no limit.

## Security

The server listens on all interfaces with protected mode off so that other catlets can reach
it. For anything beyond a trusted internal network, set a `password` and restrict network access.

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


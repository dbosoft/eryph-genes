# Valkey

This geneset contains fodder for installing a Valkey server on Linux. Valkey is the open-source,
Redis-compatible (RESP) in-memory data store.

The RHEL family no longer packages Redis, so this gene standardises on Valkey, which both
Linux families provide. Clients and libraries that speak the Redis protocol work against it.

The fodder is cross-platform across Linux families. It works on Debian/Ubuntu and on the
RHEL family (AlmaLinux, Rocky Linux, ...). It has been tested on Debian 13 and AlmaLinux 10.

## Usage

Add a gene reference to a Linux catlet, give it a data drive for its persistent state (see
[Persistent state](#persistent-state)), and optionally set a password:

``` yaml
name: valkey-server
parent: dbosoft/debian-13/starter

drives:
 - name: sdb
   size: 10
   location: valkey-data

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
- mounts the state drive at `/var/lib/valkey` so the saved data survives a redeploy
- opens port 6379/tcp when `firewalld` or `ufw` is active

## Persistent state

Valkey periodically saves its data to disk (an RDB snapshot in its data directory). That data
would be lost on a redeploy, because the OS disk is recreated from the gene. Give the catlet a
second drive and make it **persistent** with an explicit `location`. This is the key detail:
`name` (`sdb`) only sets the device order inside the guest, while `location` is the drive's identity
on the host. Without a `location`, eryph assigns a throwaway storage id and **deletes the drive
together with the catlet**; with one, the drive lives independently of the catlet and is re-attached
on the next deploy. Pick a `location` that is unique within the project (the example uses
`valkey-data`).

The fodder formats the drive on first use (ext4, label `valkey`) and mounts it at the data directory
`/var/lib/valkey`, so the saved data survives a **redeploy** (removing the catlet and deploying it
again with the same `location`). If no empty drive is present, provisioning stops with a clear error.

A pure in-memory cache does not strictly need this, but these genes are reference setups and
default to durable state. For a throwaway cache you can still point an app at it and ignore the
saved data.

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

{{> food_versioning_major_minor }}

{{> footer }}

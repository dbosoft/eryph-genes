# Caddy

This geneset contains fodder for installing Caddy as a reverse proxy with automatic HTTPS on
Linux.

The fodder is cross-platform Caddy fodder. It installs Caddy from the official package (the apt
repository on Debian/Ubuntu, COPR on the RHEL family) and configures it as a reverse proxy with
automatic HTTPS. It has been tested on Debian 13 and AlmaLinux 10 (it also works on Ubuntu and the
RHEL family).

## Usage

Put Caddy in front of a backend application, for example the application catlet of the
`dbosoft/nextcloud` gene running on another catlet. `backend` must point at the address and port of
the backend.

``` yaml
name: caddy-proxy
parent: dbosoft/debian-13/starter

fodder:
 - source: gene:dbosoft/caddy:server
   variables:
     - name: site_address
       value: cloud.example.com
     - name: backend
       value: 10.0.0.20:80
     - name: tls
       value: internal
```

Caddy can also proxy a service on the same catlet. Set `backend` to `127.0.0.1:<port>` and combine
the Caddy fodder with the fodder of the application on one catlet.

The fodder:

- installs Caddy from its official repository
- writes `/etc/caddy/Caddyfile` with a single reverse-proxy site
- enables and starts the `caddy` service
- opens ports 80 and 443 when `firewalld` or `ufw` is active

With `tls: internal` the certificate is issued by Caddy's own CA, so external clients will see an
untrusted-certificate warning unless they trust that CA. This is fine for internal use. Use
`tls: auto` with a public domain for a publicly-trusted certificate.

## Configuration

The following variables can be used to configure the `server` fodder:

- **site_address**  
  required, no default value

  The address Caddy serves, e.g. a domain like `cloud.example.com` or a host name. This is the
  host name clients use to reach the proxy.

- **backend**  
  required, no default value

  The upstream to proxy to, as `host:port`, e.g. `127.0.0.1:8080` or `10.0.0.20:80`.

- **tls**  
  default value: internal

  How TLS is handled:

  - `internal`: HTTPS with Caddy's own locally-trusted CA (self-signed, good for internal or demo
    use)
  - `auto`: automatic HTTPS via Let's Encrypt (needs a public domain reachable on ports 80 and 443)
  - `off`: plain HTTP only

- **tls_email**  
  optional, default value: empty

  The ACME account email used with `tls: auto`.

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


# Oracle Linux 9

This geneset contains the base catlet for Oracle Linux 9.

## Usage

The base catlet can be used as parent catlet like this

``` ps
New-Catlet -Parent "dbosoft/oraclelinux-9"
```

This base catlet does not include a default user.
You should therefore set up your own fodder to create an initial local user or to automatically join a domain.

Alternatively, you can use the Starter Catlet, which creates a default admin user with an initial password of "admin".


``` ps
New-Catlet -Parent "dbosoft/oraclelinux-9/starter"
```


See also [starter-food](/b/dbosoft/starter-food) for other defaults and variables for starter food.
----

# General Information

## RHEL-Compatible Catlets Naming Convention

The naming convention for the RHEL-compatible server catlets is as follows:

`almalinux-<version>`, `oracle-<version>`, `rhel-<version>`

where `<version>` is the major version number, e.g. `8`, `9`, `10`.
We focus on current and supported enterprise Linux versions.

## Available Distributions

### AlmaLinux
- **Binary compatible** with RHEL
- **Free and open source** - No subscription required
- **Enterprise-focused** with backing from CloudLinux
- **Fast security updates** and community support
- **Recommended** for most use cases requiring RHEL compatibility

### Oracle Linux
- **100% binary compatible** with RHEL
- **Free for production use** including support
- **UEK kernel** (Unbreakable Enterprise Kernel) - Optimized for performance
- **Oracle backing** with enterprise support options
- **Note**: UEK2 is not supported on Hyper-V and Azure due to missing drivers

### RHEL (Red Hat Enterprise Linux)
- **The original** enterprise Linux distribution
- **Commercial subscription** required for downloads and support
- **Free developer subscription** available (16 systems)
- **Full enterprise support** from Red Hat

## Monthly Builds

We **plan** to build the server catlets monthly. The build date is part of the tag name.
The tag `latest` is updated with each released version.

Currently the builds have to be triggered manually. We are working on automating this process.

----

# Versioning

This geneset contains 2 kinds of tags:

- Base catlets  
  Base catlets are versioned by a timestamp which is the build date of the catlet.  
  The tag latest is updated with each released version. 

- Starter catlets  
  Starter catlets are versioned with a major-minor version scheme.

  The started catlets are very light and contain only reference to the base catlet and the starter food.



----

# Contributing

This geneset is maintained by dbosoft and is open for contributions.  

You can find the repository for this geneset on [github.com/dbosoft/eryph-genes](https://github.com/dbosoft/eryph-genes).  

  

# License

All public dbosoft genesets are licensed under the [MIT License](https://opensource.org/licenses/MIT).


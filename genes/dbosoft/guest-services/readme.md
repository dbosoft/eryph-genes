# Eryph Guest Services

This geneset contains fodder for installing the erpyh guest services.

## Usage

To install the eryph guest services in your Windows catlets add a gene reference to the Windows gene:

``` yaml
fodder:
 - source: gene:dbosoft/guest-services:win-install
```

or for Linux:

``` yaml
fodder:
 - source: gene:dbosoft/guest-services:linux-install
```

## Configuration

The Windows and the Linux gene support the same variables. The following variables can be used to configure the gene:

- **version**  
  default value: `latest`

  The version of the eryph guest services which should be installed. The exact version, e.g. `0.1.0`, must
  be provided. `latest` will install the latest released version. `prerelease` will install the latest
  prerelease version.

- **downloadUrl**

  When provided, the eryph guest services will be downloaded from this URL instead of looking up the version.

- **sshPublicKey**
  
  The SSH public which should be used to authenticate connections to the eryph guest service. This public key
  will be injected into the catlet. The public key for the eryph guest services is configured independently
  of the atuhorized keys for the normal SSH server.

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



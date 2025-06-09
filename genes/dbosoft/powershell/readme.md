# Powershell

This geneset contains fodder for installing Powershell.

## Usage

To install Powershell in your Windows catlets add a gene reference to the Windows gene:

``` yaml
fodder:
 - source: gene:dbosoft/powershell:win-install
```

or for Linux:


``` yaml
fodder:
 - source: gene:dbosoft/powershell:linux-install
```

## Configuration

The Windows and the Linux gene support the same variables. The following variables can be used to configure the gene:

- **pwshVersion**  
  default value: latest
  
  The version of PowerShell which will be installed. Only PowerShell 7.4 or later have been tested. The exact version, e.g. `7.4.10` must be provided. `latest` will install the latest released version.

- **enableSsh**  
  default value: false

  When enabled, PowerShell will be registered as an SSH submodule. This way, SSH can be used when connecting to the catlet with `Enter-PSSession`. The SSH server must already be installed and enabled. Our starter catlets have SSH enabled by default.

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



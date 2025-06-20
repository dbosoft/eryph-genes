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

{{> food_versioning_major_minor }}

{{> footer }}


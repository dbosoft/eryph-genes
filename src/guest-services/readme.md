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

{{> food_versioning_major_minor }}

{{> footer }}


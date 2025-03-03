# Hyper-V

This geneset contains fodder genes to install Hyper-V within a catlet with or without eryph-zero.

## Usage

To use the fodder genes of this catlet include them into your catlet like this:


### Installing Hyper-V

``` yaml

fodder:
- source: gene:dbosoft/hyperv:install

```

This will include the gene `install` that enables Hyper-V in the VM.

Please note that the catlet has to enable nested_virtualization capability.

``` yaml

capabilities:
- nested_virtualization

```

### Installing eryph-zero

To install eryph-zero with Hyper-V use the gene `eryph-zero-latest`:

``` yaml

capabilities:
  - name: nested_virtualization

fodder:
- source: gene:dbosoft/hyperv:eryph-zero-latest
  variables:
  - name: email
    value: "{{ email }}"
  - name: invitationCode
    value: "{{ invitationCode }}"
```

The variables email and invitationCode are required to fetch latest geneset with your own invitation code.




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



# {{ manifest.short_description }}

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
    value: "\{{ email }}"
  - name: invitationCode
    value: "\{{ invitationCode }}"
```

The variables email and invitationCode are required to fetch latest geneset with your own invitation code.



{{> food_versioning_major_minor }}

{{> footer }}


# {{ manifest.short_description }}

This geneset contains fodder genes to setup Windows DSC (Desired State Configuration)

## Usage

This geneset currently contains only one gene that can be used to set up DSC with nuget as the package provider and a self-signed certificate for local use.  


Include it in a catlet like this:

``` yml
fodder:  
- source: gene:dbosoft/windsc:setup
```



## Details

The setup fodder contains 2 configurations: 
- Bootstrapping of nuget package source.
- Setting up a certificate as a DSC self-signed certificate. You can configure the DN for the certificate, but normally this should not be necessary.

{{> food_versioning_major_minor }}

{{> footer }}


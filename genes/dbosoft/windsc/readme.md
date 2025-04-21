# Windows DSC configuring

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



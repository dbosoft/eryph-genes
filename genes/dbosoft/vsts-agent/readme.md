# Azure DevOps agent catlet

This geneset contains a catlet that runs a Azure DevOps agent. 

## Usage

Use the catlet as parent for your own catlet:

``` ps

new-catlet -Parent dbosoft/vsts-agent/win2022-1.0 -name devops

```

The catlet requires some variables from the [dbosoft/vsts](/b/dbosoft/vsts) geneset (e.g. clientId and client secret). 





----

# Contributing

This geneset is maintained by dbosoft and is open for contributions.  

You can find the repository for this geneset on [github.com/dbosoft/eryph-genes](https://github.com/dbosoft/eryph-genes).  

  

# License

All public dbosoft genesets are licensed under the [MIT License](https://opensource.org/licenses/MIT).



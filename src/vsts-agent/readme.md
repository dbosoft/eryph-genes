# {{ manifest.short_description }}

This geneset contains a catlet that runs a Azure DevOps agent. 

## Usage

Use the catlet as parent for your own catlet:

``` ps

new-catlet -Parent dbosoft/vsts-agent/win2022-1.0 -name devops

```

The catlet requires some variables from the [dbosoft/vsts](/b/dbosoft/vsts) geneset (e.g. clientId and client secret). 




{{> footer }}


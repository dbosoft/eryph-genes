# VSTS / Azure DevOps Agent

This geneset contains fodder genes to install a DevOps agent in a catlet.

## ⚠ Change of CDN URL ⚠
Versions 1.1 and older of this gene will stop working in May 2025. Please update to the latest version.

Microsoft is changing the download URL for the Azure DevOps agent (see
https://devblogs.microsoft.com/devops/cdn-domain-url-change-for-agents-in-pipelines/).

## Usage

To use the fodder genes of this catlet include them into your catlet like this:


``` yml

fodder:  
- source: gene:dbosoft/vsts:agent-sp
  variables:
  - name: agentVersion
    value: "{{ agentVersion }}"
  - name: clientSecret
    value: "{{ clientSecret }}"
  - name: clientId
    value: "{{ clientId }}"
  - name: tenantId
    value: "{{ tenantId }}"
  - name: agentPassword
    value: "{{ agentPassword }}"
  - name: devopsUrls
    value: "{{ devopsUrls }}"
  - name: poolName
    value: "{{ poolName }}"
  - name: agentName
    value: "{{ agentName }}"

```

Currently it only supports credentials with a agent principal. See also https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/service-principal-agent-registration?view=azure-devops.



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



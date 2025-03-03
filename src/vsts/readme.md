# {{ manifest.short_description }}

This geneset contains fodder genes to install a DevOps agent in a catlet.

## Usage

To use the fodder genes of this catlet include them into your catlet like this:


``` yml

fodder:  
- source: gene:dbosoft/vsts:agent-sp
  variables:
  - name: agentVersion
    value: "\{{ agentVersion }}"
  - name: clientSecret
    value: "\{{ clientSecret }}"
  - name: clientId
    value: "\{{ clientId }}"
  - name: tenantId
    value: "\{{ tenantId }}"
  - name: agentPassword
    value: "\{{ agentPassword }}"
  - name: devopsUrls
    value: "\{{ devopsUrls }}"
  - name: poolName
    value: "\{{ poolName }}"
  - name: agentName
    value: "\{{ agentName }}"

```

Currently it only supports credentials with a agent principal. See also https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/service-principal-agent-registration?view=azure-devops.


{{> food_versioning_major_minor }}

{{> footer }}


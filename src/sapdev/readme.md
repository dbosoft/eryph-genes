# SAP development tools

This geneset provides fodder for the command line tools of the SAP BTP development stack on
Windows. All tools are installed for all users; the fodder runs as Local System.

| Fodder | Installs |
|---|---|
| `nodejs-tools` | Node.js LTS (if missing) and the npm packages `@sap/cds-dk` (CAP), `@ui5/cli` and `mbt` (Cloud MTA Build Tool), globally in `C:\ProgramData\npm` |
| `cf-cli` | Cloud Foundry CLI v8 in `C:\Program Files\CloudFoundry` with the `multiapps` plugin (`cf deploy`); plugins live in `C:\ProgramData\cf` (`CF_PLUGIN_HOME`) |
| `btp-cli` | SAP BTP CLI in `C:\Program Files\SAP\btp-cli` - only when the SAP Developer License is accepted |

## Usage

```yaml
fodder:
  - source: gene:dbosoft/sapdev:nodejs-tools
  - source: gene:dbosoft/sapdev:cf-cli
  - source: gene:dbosoft/sapdev:btp-cli
    variables:
      - name: accept_sap_developer_license
        value: true
```

## Variables

| Fodder | Variable | Default | Description |
|---|---|---|---|
| `nodejs-tools` | `npm_packages` | `@sap/cds-dk,@ui5/cli,mbt` | npm packages installed globally, comma separated |
| `cf-cli` | `cf_plugins` | `multiapps` | cf plugins from the CF-Community repository, comma separated |
| `btp-cli` | `accept_sap_developer_license` | `false` | Accepts the [SAP Developer License](https://tools.hana.ondemand.com/developer-license-3_2.txt); without it the BTP CLI is not installed |

The global npm prefix is set to `C:\ProgramData\npm` and added to the system PATH, so tools
installed during provisioning (as Local System) are available to every user. Users can install
or update global packages there without elevation.

For a complete SAP development environment with VS Code, the Fiori tools and Eclipse ADT, see
[dbosoft/sapdevbox](/b/dbosoft/sapdevbox).

---

{{> food_versioning_major_minor }}

{{> footer }}

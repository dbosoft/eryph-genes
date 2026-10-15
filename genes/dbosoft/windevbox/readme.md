# Windows Developer Box

This geneset provides pre-configured Windows development environments with common developer tools and configurations for Windows 10 and Windows 11 Enterprise editions.

## Available Tags

### win10
Windows 10 Enterprise development environment based on Windows 10 20H2 Enterprise.

### win11  
Windows 11 Enterprise development environment based on Windows 11 24H2 Enterprise.

## Important Note

This geneset represents an edge case for catlets configured purely via configuration from a base catlet. Due to the long installation time (typically 20-40 minutes, potentially longer with customizations), it is strongly recommended to repack this catlet after build into a custom base-catlet for reuse. This avoids repeated lengthy installation processes for each deployment.

## What's installed

- winget, plus the command line tools from the `dev_tools` variable (default `Git.Git,OpenJS.NodeJS.LTS,GitHub.cli`), installed machine-wide
- a trusted Dev Drive on `E:` (`devdrive_letter`): a dynamically expanding 100 GB VHDX on C: (`devdrive_size`), with package caches and a `\source` workspace
- Hyper-V (nested virtualization)
- PowerShell 7
- VS Code; the extensions from `vscode_extensions` are installed for each user at first logon
- Visual Studio 2026 (`vs_edition`, `vs_workloads`) with its package cache on the Dev Drive
- system-wide Git configuration, and the Git identity from `git_user_name` / `git_user_email` for each user at first logon

The catlet has 8 vCPUs, 16 GB memory and a 250 GB (dynamically expanding) system disk.

To put the Dev Drive on a dedicated disk instead, add the disk and set `devdrive_name`:

```yaml
drives:
 - name: sdb
   size: 100
variables:
 - name: devdrive_name
   value: sdb
```

Windows Terminal is not installed: Windows 11 already ships it, and winget can't install it for all users.
## Usage

This catlet does not include a default user.  
You should therefore set up your own fodder to create an initial local user or to automatically join a domain.  

Alternatively, you can add the starter-food fodder gene, which creates a default admin user with an initial password of "InitialPassw0rd".


```yaml
name: my-devbox
parent: dbosoft/windevbox/win11

fodder:
  - source: gene:dbosoft/starter-food:win-starter

```

Or using PowerShell with inline YAML:

```powershell
@"
name: my-devbox  
parent: dbosoft/windevbox/win11


fodder:
  - source: gene:dbosoft/starter-food:win-starter
"@ | New-Catlet
```

See also [starter-food](/b/dbosoft/starter-food) for other defaults and variables for starter food. 
  
&nbsp; 

## Windows license

All base catlets from dbosoft contain no valid windows license and are build using a evaluation image.  
For details see base catlets documentation how to change license and to rearm while evaluating. 

---


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


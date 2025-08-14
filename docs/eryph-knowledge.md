# eryph Knowledge Base

## System Architecture

### CRITICAL: eryph Architecture - Client-Server Model

**eryph uses a CLIENT-SERVER architecture on Windows:**

1. **SERVER (eryph-zero service)**:
   - Windows service that must be running
   - Manages Hyper-V, creates VMs, handles networking
   - Check with: `Get-Service eryph-zero`
   - Must be in "Running" state

2. **CLIENT (PowerShell cmdlets)**:
   - PowerShell commands that communicate with eryph-zero service
   - Commands like `Get-Catlet`, `New-Catlet`, `Start-Catlet` are CLIENT commands
   - They send requests to the eryph-zero SERVICE
   - **WILL FAIL if eryph-zero service is not running!**

3. **YOU ARE THE CLIENT**:
   - You run PowerShell cmdlets on the Windows machine
   - These cmdlets talk to the local eryph-zero service
   - The service does the actual work (creating VMs, managing Hyper-V)

**This means you MUST:**
1. FIRST check the service is running: `powershell -Command "Get-Service eryph-zero"`
2. THEN run eryph cmdlets: `powershell -Command "Get-Catlet"`
3. If cmdlets fail, check service status again

### What is eryph?

eryph is infrastructure that evolves. It transforms Windows VM management from copying and modifying templates into an evolutionary system where improvements compound over time through inheritance. Built on Hyper-V, it creates both Windows and Linux VMs.

## Core Concepts

- **Catlets**: VMs in eryph terminology, defined via YAML specifications
- **Genes**: Reusable templates that catlets inherit from (contain catlets, fodder, or volumes)
- **Genepool**: Cloud-hosted repository of genes (genepool.eryph.io)
- **Fodder**: Configuration data fed to VMs using cloud-init (Linux) or cloubase-init (Windows)
- **Breeding/Inheritance**: Child catlets inherit and can mutate parent configurations
- **Mutations**: Three strategies - `merge` (default, modify properties), `overwrite` (replace), `remove` (delete)

### Gene System Architecture

```
Organization/Geneset/Tag
Example: dbosoft/ubuntu-22.04/latest
         ├─ Organization (dbosoft)
         ├─ Geneset name (ubuntu-22.04)
         └─ Tag/version (latest)
```

### CRITICAL: Understanding Gene Types

**Three Distinct Gene Types:**

1. **Catlet Genes** - VM specifications that CAN inherit from other catlet genes
   - Define VM hardware, resources, and configuration
   - CAN have a `parent` field (inheritance)
   - CAN contain inline fodder
   - CAN reference external fodder genes
   - Used to create complete VMs with configuration

2. **Fodder Genes** - Standalone configuration templates that CANNOT inherit
   - Pure configuration units (cloud-init/cloubase-init)
   - NO `parent` field allowed - they are standalone
   - Must be referenced from catlet genes to be used
   - Designed to be composable and reusable across different catlets
   - Support variables for customization

3. **Volume Genes** - Disk images (VHDX files) compressed and hashed
   - Base OS images or data disks
   - Versioned by build date (e.g., 20241216)
   - No YAML specification, just disk content
   - Usually kept separate due to different versioning needs

**Key Distinction:** Only catlet genes support inheritance. Fodder genes are meant to be composed, not extended.

### Fodder: Inline vs Gene - DEVELOPMENT WORKFLOW

**ALWAYS START with inline fodder during development:**
- **Fast iteration** - no build/copy/genepool cycle needed
- **Immediate testing** - deploy and test directly
- **Easy debugging** - modify and redeploy quickly
- **Perfect the logic first** - before extracting to gene

**When to use inline fodder (RECOMMENDED FIRST APPROACH):**
- Initial development and testing
- Configuration specific to one inheritance tree
- Simple, short configuration
- Need inheritance capabilities
- Team/project-specific settings

**When to extract to fodder gene (ONLY AFTER INLINE WORKS):**
- Reusable across multiple catlets
- Complex configuration (100+ lines)
- Needs independent versioning
- Community could benefit
- After 3+ uses (Rule of Three)

**Best Practice:** Start with inline fodder → Test until perfect → Extract to gene only if reusability needed

### Fodder Accumulation

Fodder accumulates from all ancestors - it doesn't get mutated or overwritten:
1. Grandparent fodder runs first
2. Parent fodder runs next
3. Child fodder runs last
All within cloud-init/cloubase-init on first boot.

## Genepool Discovery

### Common Public Genes

**Linux Base Images:**
- `dbosoft/ubuntu-22.04/latest` - Ubuntu 22.04 LTS base image
- `dbosoft/ubuntu-22.04/starter` - Ubuntu with pre-configured admin user (admin/admin)
- `dbosoft/ubuntu-20.04/latest` - Ubuntu 20.04 LTS base image
- `dbosoft/ubuntu-20.04/starter` - Ubuntu 20.04 with admin user

**Windows Base Images:**
- `dbosoft/windows-server-2022/latest` - Windows Server 2022 base
- `dbosoft/winsrv2022-standard/starter` - Windows Server 2022 with admin setup
- `dbosoft/winsrv2022-standard/latest` - Windows Server 2022 Standard

**Fodder Genes:**
- `dbosoft/starter-food/linux-starter` - Linux starter configuration with SSH setup
- `dbosoft/starter-food/windows-starter` - Windows starter configuration

### Searching Genepool via API

```bash
# List organization's genesets
curl https://genepool-api.eryph.io/v1/orgs/dbosoft/genesets

# Get geneset details
curl https://genepool-api.eryph.io/v1/genesets/dbosoft/ubuntu-22.04

# Get available tags
curl https://genepool-api.eryph.io/v1/genesets/dbosoft/ubuntu-22.04/tags
```

### PowerShell Search

```powershell
# Browse at https://genepool.eryph.io
# Or use PowerShell to check available genes
Get-CatletGene
```

## Catlet Building Workflows

### Basic Catlet Structure

```yaml
name: my-vm                              # Required: unique name
parent: dbosoft/ubuntu-22.04/starter     # Required: base gene to inherit from
hostname: web01                          # Optional: OS hostname
project: my-project                      # Optional: project name
environment: staging                     # Optional: requires environment config
location: rack-01                        # Optional: requires location setup

# Resources (override parent defaults)
cpu: 4                                   # Number of CPUs
memory: 4096                            # RAM in MiB

# Disks
drives:
- name: sda                             # System disk
  size: 30                              # Size in GB
  mutation: merge                       # How to handle inheritance
- name: sdb                             # Additional data disk
  size: 100

# Special capabilities
capabilities:
- nested_virtualization                 # Run VMs inside this VM
- secure_boot                          # Enable secure boot
- dynamic_memory                       # Allow memory scaling

# Configuration
fodder:
- name: base-setup
  type: cloud-config
  content: |
    packages:
    - nginx
    - git
```

### Using Variables

```yaml
name: configurable-vm
parent: dbosoft/ubuntu-22.04/starter

# Declare variables
variables:
- name: server_name
  required: true
- name: admin_email
  required: true
- name: enable_ssl
  type: boolean
  default: false

# Use variables in fodder
fodder:
- name: web-config
  type: cloud-config
  content: |
    write_files:
    - path: /etc/nginx/sites-available/default
      content: |
        server {
          server_name {{ server_name }};
          {% if enable_ssl %}
          listen 443 ssl;
          {% endif %}
        }
```

### Referencing External Fodder

```yaml
name: web-server
parent: dbosoft/ubuntu-22.04/starter

# Reference fodder from genepool
fodder:
- source: gene:myorg/web-fodder:nginx-config
  variables:
  - name: domain
    value: example.com
  - name: admin_email  
    value: admin@example.com
```

### Windows Catlet Example

```yaml
name: windows-dev
parent: dbosoft/winsrv2022-standard/starter
cpu: 8
memory: 16384

fodder:
- name: dev-tools
  type: shellscript
  filename: setup.ps1
  content: |
    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    
    # Install development tools
    choco install -y git vscode nodejs python3
    
    # Install IIS
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
```

## CRITICAL: PowerShell Variables vs Eryph Variables

### PowerShell Variable Interpolation (ONLY in PowerShell scripts!)

**IMPORTANT:** PowerShell variables like `$pubkey` or `$egsKey` ONLY work when:
1. You're constructing YAML in a PowerShell script using `@"..."@` heredoc strings
2. PowerShell interpolates the variable BEFORE the YAML is created
3. The resulting YAML contains the actual value, not the variable reference

**Example - PowerShell constructing YAML:**
```powershell
# This works - PowerShell replaces $pubkey with actual value
$pubkey = "ssh-rsa AAAAB3Nza..."
$yaml = @"
fodder:
- name: setup
  content: |
    ssh_authorized_keys:
    - $pubkey  # PowerShell replaces this BEFORE YAML is created
"@
# The YAML now contains the actual key, not "$pubkey"
```

**This DOES NOT work in .yaml files:**
```yaml
# test.yaml - THIS WILL NOT WORK!
fodder:
- name: setup
  content: |
    ssh_authorized_keys:
    - $pubkey  # ERROR: This stays as literal "$pubkey" text!
```

### Eryph Variables (Work in ALL YAML files)

**For .yaml files, ALWAYS use eryph variable syntax:**
```yaml
# test.yaml - This WORKS in any YAML file
variables:
- name: sshkey
  secret: true

fodder:
- name: setup
  content: |
    ssh_authorized_keys:
    - {{ sshkey }}  # Eryph replaces this, not PowerShell
```

Then provide the value when deploying:
```powershell
Get-Content test.yaml | New-Catlet -Variables @{sshkey = "ssh-rsa..."} -SkipVariablesPrompt
```

## Common Inline Fodder Examples

### Windows Feature Installation with EGS

```yaml
name: test-windows-feature
parent: dbosoft/winsrv2022-standard/starter

variables:
- name: egskey
  secret: true

fodder:
# Add EGS for SSH access
- source: gene:dbosoft/guest-services:win-install
  variables:
  - name: sshPublicKey
    value: '{{ egskey }}'

# Install Windows feature (example: IIS)
- name: feature-install
  type: shellscript
  filename: install.ps1
  content: |
    # Install Windows feature with management tools
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
    
    # Configure the feature as needed
    # Add your specific configuration here
    
    # Ensure service is running
    Start-Service W3SVC
    Set-Service W3SVC -StartupType Automatic
```

### Linux Package Installation with EGS

```yaml
name: test-linux-package
parent: dbosoft/ubuntu-22.04/starter

variables:
- name: egskey
  secret: true

fodder:
# Add EGS for SSH access
- source: gene:dbosoft/guest-services:linux-install
  variables:
  - name: sshPublicKey
    value: '{{ egskey }}'

# Install and configure packages
- name: package-setup
  type: cloud-config
  content: |
    packages:
      - nginx
      - nodejs
    
    write_files:
    - path: /etc/myapp/config.json
      content: |
        {
          "setting": "value"
        }
    
    runcmd:
      - systemctl enable nginx
      - systemctl start nginx
```

## Sample Patterns

### Multi-Tier Application

```yaml
# web-tier.yaml
name: web-server-01
parent: dbosoft/ubuntu-22.04/starter
project: my-app
cpu: 2
memory: 2048

fodder:
- name: web-setup
  type: cloud-config
  content: |
    packages: [nginx, nodejs]
    
---
# db-tier.yaml  
name: db-server-01
parent: dbosoft/ubuntu-22.04/starter
project: my-app
cpu: 4
memory: 8192

drives:
- name: sdb
  size: 100  # Data disk

fodder:
- name: db-setup
  type: cloud-config
  content: |
    packages: [postgresql]
```

### Development Environment

```yaml
name: dev-workstation
parent: dbosoft/windows-server-2022/starter
cpu: 8
memory: 16384

capabilities:
- nested_virtualization  # For Docker/WSL2

fodder:
- name: dev-tools
  type: shellscript
  filename: install.ps1
  content: |
    # Install package manager
    Set-ExecutionPolicy Bypass -Scope Process -Force
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    
    # Development tools
    choco install -y git vscode docker-desktop nodejs python3
    
    # Enable WSL2
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
```

### Reusable Base Template

```yaml
# Create company-specific base
name: company-base
parent: dbosoft/ubuntu-22.04/latest

fodder:
- name: company-standards
  type: cloud-config
  content: |
    # Company security policies
    package_update: true
    package_upgrade: true
    
    packages:
    - fail2ban
    - ufw
    - monitoring-agent
    
    write_files:
    - path: /etc/motd
      content: |
        ************************************************
        * Company Infrastructure - Authorized Use Only *
        ************************************************
    
    runcmd:
    - ufw --force enable
    - ufw allow ssh
    - systemctl enable fail2ban
```

## PowerShell Command Reference

**These are ACTUAL PowerShell cmdlets installed on Windows by eryph-zero:**

```powershell
# Catlet Management - ACTUAL cmdlets that exist on the system
New-Catlet -InputObject $spec              # Creates VM via eryph-zero service
Get-Catlet                                  # Lists VMs from eryph-zero service
Get-Catlet | Where-Object Name -eq "vm-name" | Start-Catlet    # Starts VM
Get-Catlet | Where-Object Name -eq "vm-name" | Stop-Catlet -Force   # Stops VM
Get-Catlet | Where-Object Name -eq "vm-name" | Remove-Catlet -Force # Deletes VM
Get-Catlet | Where-Object Name -eq "vm-name" | Get-CatletIp    # Gets VM IP

# Or with ID if known
Start-Catlet -Id "catlet-id"
Stop-Catlet -Id "catlet-id" -Force
Remove-Catlet -Id "catlet-id" -Force

# Testing Configuration - REAL cmdlet
Test-Catlet -InputObject $spec             # Tests catlet syntax and gene resolution WITHOUT creating VM
Get-Content catlet.yaml | Test-Catlet      # Test from file
Test-Catlet -Config "catlet.yaml"          # Test from file path

# Gene Management - REAL cmdlets  
Get-CatletGene                             # Lists downloaded gene templates (AFTER deployment only)
Remove-CatletGene -Unused -Force           # Cleans up unused genes

# Project Management - REAL cmdlets
New-EryphProject "project-name"            # Creates project in eryph-zero
Get-EryphProject                           # Lists projects
Remove-EryphProject "project-name" -Force  # Deletes project

# These are COMMAND-LINE TOOLS (not PowerShell cmdlets):
eryph-zero genepool login                  # CLI tool for genepool auth
eryph-packer geneset init org/geneset --public      # CLI tool for creating genes
eryph-packer geneset-tag init org/geneset/tag
eryph-packer geneset-tag pack org/geneset/tag
eryph-packer geneset push org/geneset/tag
```

## Genepool API Reference

### REST API Endpoints

The genepool REST API is available at `https://genepool.eryph.io/v1/` (or `https://genepool-api.eryph.io/v1/`).

**Key Endpoints for Scanning dbosoft Organization:**

```bash
# List all genesets for organization dbosoft
curl "https://genepool-api.eryph.io/v1/orgs/dbosoft/genesets"

# Get specific geneset info
curl "https://genepool-api.eryph.io/v1/genesets/dbosoft/ubuntu-22.04"

# List all tags for a geneset
curl "https://genepool-api.eryph.io/v1/genesets/dbosoft/ubuntu-22.04/tags"

# Get specific tag info
curl "https://genepool-api.eryph.io/v1/genesets/dbosoft/ubuntu-22.04/tag/latest"

# Get geneset stats
curl "https://genepool-api.eryph.io/v1/genesets/dbosoft/ubuntu-22.04/stats"

# Get geneset description (markdown)
curl "https://genepool-api.eryph.io/v1/genesets/dbosoft/ubuntu-22.04/description"
```

### Query Parameters

- `page_size=<number>` - Results per page (default 10)
- `continuation_token=<token>` - For pagination
- `expand=tags,metadata,description` - Expand nested data
- `no_cache=true` - Bypass cache for fresh data

### Example: Scan All dbosoft Genesets with PowerShell

```powershell
# Get all dbosoft genesets
$response = Invoke-RestMethod -Uri "https://genepool-api.eryph.io/v1/orgs/dbosoft/genesets?page_size=50"

# Display geneset names
$response.values | ForEach-Object {
    Write-Host "Geneset: $($_.name)"
}

# Get specific geneset info
$ubuntu = Invoke-RestMethod -Uri "https://genepool-api.eryph.io/v1/genesets/dbosoft/ubuntu-22.04"

# Get tags for a geneset
$tags = Invoke-RestMethod -Uri "https://genepool-api.eryph.io/v1/genesets/dbosoft/ubuntu-22.04/tags"
$tags.values | ForEach-Object {
    Write-Host "Tag: $($_.tag) - Size: $($_.size_bytes / 1MB) MB"
}
```

### Common dbosoft Genesets to Query

```powershell
# OS Base Images
"dbosoft/ubuntu-20.04"
"dbosoft/ubuntu-22.04"
"dbosoft/ubuntu-24.04"
"dbosoft/winsrv2019-standard"
"dbosoft/winsrv2022-standard"
"dbosoft/winsrv2025-standard"
"dbosoft/win10-20h2-enterprise"
"dbosoft/win11-24h2-enterprise"

# Fodder Collections
"dbosoft/starter-food"      # Basic user setup fodder
"dbosoft/hyperv"            # Hyper-V installation
"dbosoft/windomain"         # Windows domain setup
"dbosoft/winconfig"         # Windows configuration
"dbosoft/guest-services"    # Guest integration services
```

### Full Organization Scan

```powershell
# Scan all genesets for an organization with pagination
$Org = "dbosoft"
$baseUrl = "https://genepool-api.eryph.io/v1"
$allGenesets = @()
$continuationToken = $null

do {
    $uri = "$baseUrl/orgs/$Org/genesets?page_size=50"
    if ($continuationToken) {
        $uri += "&continuation_token=$continuationToken"
    }
    
    $response = Invoke-RestMethod -Uri $uri
    $allGenesets += $response.values
    $continuationToken = $response.continuation_token
    
} while ($continuationToken)

# Display results
$allGenesets | ForEach-Object {
    Write-Host "Geneset: $($_.name)" -ForegroundColor Cyan
    Write-Host "  Public: $($_.is_public)"
    Write-Host "  Description: $($_.short_description)"
}

Write-Host "`nTotal genesets found: $($allGenesets.Count)" -ForegroundColor Green

# Filter for fodder genes
$fodderGenes = $allGenesets | Where-Object { $_.name -match "food|fodder|config" }
Write-Host "`nFodder genes: $($fodderGenes.Count)"
```

## Best Practices

### Gene Design
1. **Use variables** for anything environment-specific (domains, IPs, credentials)
2. **Keep base images minimal** - let users add their specifics via fodder
3. **Document your genes** with README.md in the geneset directory
4. **Version appropriately**: semantic (1.0, 1.1), date-based (20241216), or floating (latest, stable)
5. **Test locally** before publishing to genepool

### Fodder Design
1. **Order matters** - dependencies first
2. **Use cloud-config** for declarations, shell scripts for complex logic
3. **Add debug output** during development
4. **Document assumptions** (OS version, required packages)
5. **Make variables required** only when truly essential

### Catlet Specifications
1. **Choose appropriate parents** - starter for quick setup, latest for production
2. **Size resources reasonably** - can always be mutated later
3. **Use meaningful names** that describe purpose
4. **Group related VMs** in the same project
5. **Reference external fodder** for reusability

## Credential Management

### Default Credentials

**Starter genes include:**
- Username: `admin`
- Password: `admin`
- SSH enabled (Linux)
- RDP enabled (Windows)

### Check for Credentials

```powershell
# Check if using starter gene (has default creds)
$catletSpec = Get-Content catlet.yaml | ConvertFrom-Yaml
if ($catletSpec.parent -match "starter") {
    Write-Host "Using starter gene - default credentials available (admin/admin)"
} else {
    Write-Host "No default credentials - you should add user setup fodder"
}
```

### Add SSH Key Authentication

```yaml
name: secure-vm
parent: dbosoft/ubuntu-22.04/starter

variables:
- name: ssh_public_key
  required: true
  secret: true

fodder:
- name: ssh-setup
  type: cloud-config
  content: |
    users:
    - name: admin
      ssh_authorized_keys:
      - {{ ssh_public_key }}
    ssh_pwauth: false  # Disable password auth
```

### Windows Admin Setup

```yaml
name: windows-secure
parent: dbosoft/windows-server-2022/latest

variables:
- name: admin_password
  required: true
  secret: true

fodder:
- name: admin-setup
  type: cloud-config
  content: |
    set_administrator_password: {{ admin_password }}
    local_admins:
    - Administrator
```
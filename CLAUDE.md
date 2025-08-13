# eryph-genes Repository Management Guide

## Overview

This repository manages the official eryph genes maintained by dbosoft. Genes are the evolutionary units of infrastructure in eryph - reusable templates that catlets (VMs) inherit from. This repository contains catlet genes, fodder genes (configuration), and volume genes for various operating systems including Ubuntu, Windows Server, and Windows desktop editions.

**Dependencies:**
- **hyperv-boxes repository** (expected at `..\hyperv-boxes`) - Contains Packer templates for building base OS images
- **eryph-zero** - Must be installed and running for testing
- **eryph-packer** - Required for packaging and pushing genes to genepool

## Key Concepts

### What is eryph?
eryph is infrastructure that evolves. It transforms Windows VM management from copying and modifying templates into an evolutionary system where improvements compound over time through inheritance. Built on Hyper-V, it creates both Windows and Linux VMs.

### Gene Types
- **Catlet Genes**: VM specifications defining resources, settings, and parent inheritance
- **Fodder Genes**: Configuration data (cloud-init/cloubase-init) for VM setup
- **Volume Genes**: Disk volumes used as base OS images or data volumes

### Repository Structure
```
eryph-genes/
├── genes/            # Built genesets with .packed folders after build
│   └── dbosoft/      # Organization namespace
│       └── genename/ # Each geneset
│           └── tag/  # Version tags (latest, next, 1.0, etc.)
│               └── .packed/  # Created by build, contains gene artifacts
├── src/              # Source templates for genesets (npm packages)
│   └── genename/     # Source for each geneset
│       ├── package.json     # Geneset package (no version)
│       ├── geneset.json     # Geneset metadata
│       └── default/         # Default tag (or other version tags)
│           ├── package.json # Tag package (has version)
│           └── fodder/      # Fodder YAML files
├── packages/         # npm tooling packages (build-geneset, build-geneset-tag)
├── tests/            # Test catlet templates and SSH module
└── *.ps1            # PowerShell build/test/push scripts
```

## Workflow Overview

The repository uses a sophisticated npm/TypeScript build system:

### Build System Architecture

1. **Source Structure (`src/` folder)**:
   - Each geneset is an npm package (e.g., `@dbosoft/ubuntu-22-04`)
   - Genesets have NO version in package.json (only name)
   - Geneset tags (variants) are separate npm packages with versions
   - Tags are dependencies of their parent geneset

2. **Two-Level Package System**:
   - **Geneset packages**: Define the gene family (no version)
   - **Tag packages**: Define specific versions/variants (have version numbers)
   - Example: `ubuntu-22-04` geneset imports `linux-starter-catlet` tag package

3. **Build Process (`turbo build`)**:
   - **Development mode**: Creates `next` tag for testing (replaces version with "next")
   - **Publish mode**: Uses actual version from package.json
   - Compiles TypeScript build tools from `packages/build-geneset`
   - Processes Handlebars templates (`.hbs` files)
   - Creates `dist/` folder, then copies to `genes/` structure
   - Runs `eryph-packer geneset-tag pack` to create `.packed` folders

4. **The "next" Tag**:
   - Automatically created during `build` command (not `publish`)
   - Marked with `.unlocked` file for easy cleanup
   - Used for local testing before creating versioned releases
   - Gets replaced on each build cycle

### DEVELOPMENT WORKFLOW - START WITH INLINE FODDER!

#### Phase 1: Fast Iteration with Inline Fodder (ALWAYS START HERE)
1. **Create test catlet with INLINE fodder** - no gene building needed
2. **Deploy with Test-Catlet** to validate syntax
3. **Deploy with New-Catlet** and connect via SSH/PSRemote
4. **Iterate on inline fodder** until it works perfectly
5. **Only AFTER it works** - extract to standalone gene if reusability needed

#### Phase 2: Extract to Standalone Gene (ONLY if needed for reuse)
1. Create gene structure in `src/<genename>/` based on working inline fodder
2. Run `turbo build` to create `genes/<org>/<genename>/next/.packed`
3. Copy `.packed` to local genepool (check genepool path first!)
4. Test the standalone gene by referencing from a new catlet
5. Create changeset and run `pnpm publish-genesets` for releases

**IMPORTANT: Always develop fodder inline first! Only extract to genes when you need reusability across multiple catlets.**

### For Base OS Catlets (from VMs):
1. **hyperv-boxes repo** builds VMs using Packer from ISO images
2. **build.ps1** orchestrates the conversion to eryph genes using import.json mapping
3. **catletlify.ps1** renames VM components to eryph conventions
4. **pack_build.ps1** packages VMs into gene format with date-based tags
5. **test_packed.ps1** validates genes before pushing

## Common Tasks

### 1. Building Genes

#### Build All Changed Packages
```bash
turbo build
```

#### Build Specific Gene
```bash
pnpm --filter ./src/ubuntu-22-04 build
```

#### Build Base Catlets
```powershell
# Requires eryph-zero and eryph-packer installed
# BuildPath should point to a builds directory within hyperv-boxes repo
# The hyperv-boxes repo should be at ..\hyperv-boxes relative to this repo

# Example: Build specific OS template
.\build.ps1 -BuildPath "..\hyperv-boxes\builds" -Filter "ubuntu-22*"

# The build process:
# 1. Runs hyperv-boxes build.ps1 which uses Packer to create VMs
# 2. Runs catletlify.ps1 to convert VMs to eryph naming conventions
# 3. Runs pack_build.ps1 to package into genes
# 4. Runs test_packed.ps1 to test the gene
```

### 2. Creating New Genes

#### ALWAYS START: Test Fodder Inline First

**This is the FASTEST way to develop and test fodder:**

```yaml
# test-iis.yaml - Start with inline fodder for immediate testing
name: test-iis
parent: dbosoft/winsrv2022-standard/latest

fodder:
- name: iis-install
  type: powershell
  content: |
    # Install IIS with common features
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
    Install-WindowsFeature -Name Web-Common-Http, Web-Static-Content, Web-Dir-Browsing
    Install-WindowsFeature -Name Web-Http-Errors, Web-Http-Redirect, Web-App-Dev
    Install-WindowsFeature -Name Web-Net-Ext45, Web-Asp-Net45, Web-ISAPI-Ext
    
    # Create test site
    New-Item -Path "C:\inetpub\testsite" -ItemType Directory -Force
    Set-Content -Path "C:\inetpub\testsite\index.html" -Value "<h1>IIS Working!</h1>"
    
    # Configure IIS
    Import-Module WebAdministration
    New-Website -Name "TestSite" -Port 8080 -PhysicalPath "C:\inetpub\testsite"
    Start-Website -Name "TestSite"
```

**Test immediately:**
```powershell
# Deploy and test
Get-Content test-iis.yaml -Raw | Test-Catlet  # Validate syntax
Get-Content test-iis.yaml -Raw | New-Catlet   # Deploy
Get-Catlet | Where-Object Name -eq "test-iis" | Start-Catlet -Force

# Wait for boot and get IP
Start-Sleep -Seconds 120
$ip = (Get-Catlet | Where-Object Name -eq "test-iis" | Get-CatletIp).IpAddress

# Connect via PSRemoting to verify
$cred = New-Object PSCredential("Administrator", (ConvertTo-SecureString "admin" -AsPlainText -Force))
$session = New-PSSession -ComputerName $ip -Credential $cred

# Check IIS installation
Invoke-Command -Session $session -ScriptBlock {
    Get-WindowsFeature | Where-Object Name -like "Web-*" | Where-Object Installed
    Get-Website
    Test-Path "C:\inetpub\testsite\index.html"
}

# Browse to http://$ip:8080 to verify

# Iterate and improve the fodder until perfect...
# ONLY THEN extract to standalone gene if needed for reuse
```

#### Create Standalone Fodder Gene (ONLY after inline works)
```powershell
# 1. Create new source package structure
New-Item -ItemType Directory -Path "src\my-fodder\default\fodder" -Force

# 2. Create geneset package.json (no version - genesets don't have versions)
@"
{
  "name": "@eryph-genes/my-fodder",
  "private": true,
  "scripts": {
    "build": "build-geneset build",
    "publish": "build-geneset publish"
  },
  "devDependencies": {
    "@eryph-genes/build-geneset": "workspace:*"
  }
}
"@ | Out-File -FilePath "src\my-fodder\package.json" -Encoding UTF8

# 3. Create geneset.json metadata
@"
{
  "version": "1.1",
  "geneset": "dbosoft/my-fodder",
  "public": true,
  "short_description": "My custom fodder",
  "description": "Custom fodder for specific setup"
}
"@ | Out-File -FilePath "src\my-fodder\geneset.json" -Encoding UTF8

# 4. Create versioned tag package.json (has version)
@"
{
  "name": "@eryph-genes/my-fodder-default",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "build": "build-geneset-tag build",
    "publish": "build-geneset-tag publish"
  },
  "devDependencies": {
    "@eryph-genes/build-geneset-tag": "workspace:*"
  }
}
"@ | Out-File -FilePath "src\my-fodder\default\package.json" -Encoding UTF8

# 5. Install dependencies
pnpm install
```

#### Create Fodder YAML
```yaml
# src/my-fodder/default/fodder/setup.yaml
name: my-setup

variables:
  - name: app_name
    required: true
  - name: app_port
    value: 3000
    
fodder:
- name: app-setup
  type: cloud-config
  content: |
    packages:
      - nginx
    write_files:
    - path: /etc/nginx/sites-available/{{ app_name }}
      content: |
        server {
          listen 80;
          server_name {{ app_name }}.local;
          location / {
            proxy_pass http://localhost:{{ app_port }};
          }
        }
    runcmd:
      - systemctl enable nginx
      - systemctl start nginx
```

#### Create New Catlet Gene
```yaml
# src/my-app-vm/default/catlet.yaml.hbs
parent: dbosoft/ubuntu-22.04/latest
cpu: 4
memory: 4096

fodder:
  - source: gene:dbosoft/my-fodder:my-setup
    variables:
      - name: app_name
        value: myapp
```

### 3. Testing Genes

#### CRITICAL: SSH Key Injection for Linux Testing

**DO NOT use Git Bash SSH keys!** Generate dedicated test keys:

```powershell
# Generate NEW SSH key pair (NOT Git's keys from C:\Users\username\.ssh\id_rsa!)
$sshPath = "$env:USERPROFILE\.ssh\eryph-test"
if (!(Test-Path "$sshPath.pub")) {
    ssh-keygen -t rsa -b 4096 -f $sshPath -N '""' -C "eryph-test"
}
$publicKey = Get-Content "$sshPath.pub" -Raw

# Create test catlet with proper variable declaration
$spec = @"
name: test-vm
parent: dbosoft/ubuntu-22.04/latest

# Declare catlet variable for SSH key
variables:
- name: myTestKey
  required: true
  secret: true

fodder:
- source: gene:dbosoft/starter-food:linux-starter
  variables:
  - name: sshPublicKey
    value: "{{ myTestKey }}"  # Proper eryph variable reference
- source: gene:myorg/custom-fodder:my-config
"@

$spec | Out-File test.yaml
Get-Content test.yaml -Raw | New-Catlet -Variables @{myTestKey=$publicKey} -SkipVariablesPrompt

# Start VM and get IP
Get-Catlet | Where-Object Name -eq "test-vm" | Start-Catlet -Force
Start-Sleep -Seconds 30
$ip = (Get-Catlet | Where-Object Name -eq "test-vm" | Get-CatletIp).IpAddress

# Connect via SSH (no password needed!)
ssh -i $sshPath admin@$ip

# Check cloud-init logs
sudo cloud-init status
sudo cat /var/log/cloud-init-output.log
```

#### Windows Testing with PowerShell Remoting

```powershell
# Windows test catlet with starter-food
$spec = @"
name: test-win
parent: dbosoft/winsrv2022-standard/latest
fodder:
- source: gene:dbosoft/starter-food:win-starter
  # Creates admin user with password: InitialPassw0rd
- source: gene:myorg/custom-fodder:my-windows-config
"@

$spec | Out-File test.yaml
Get-Content test.yaml -Raw | New-Catlet
Get-Catlet | Where-Object Name -eq "test-win" | Start-Catlet -Force
Start-Sleep -Seconds 120  # Windows takes longer to boot

# Get IP and connect via PowerShell remoting
$ip = (Get-Catlet | Where-Object Name -eq "test-win" | Get-CatletIp).IpAddress
$cred = New-Object PSCredential("admin", (ConvertTo-SecureString "InitialPassw0rd" -AsPlainText -Force))

$session = New-PSSession -ComputerName $ip -Credential $cred `
    -Authentication Basic -UseSSL `
    -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)

# Check cloudbase-init logs
Invoke-Command -Session $session -ScriptBlock {
    Get-Content "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\cloudbase-init.log" -Tail 100
}

# Verify your fodder executed
Invoke-Command -Session $session -ScriptBlock {
    Get-Service | Where-Object Status -eq "Running"
    Get-WindowsFeature | Where-Object Installed
}

Remove-PSSession $session
```

#### Test Fodder Gene Locally
```powershell
# 1. Build the gene
pnpm --filter ./src/my-fodder build
# This creates genes/dbosoft/my-fodder/next/.packed/

# 2. Get genepool path (requires admin on first run)
# Check if we have stored path
$genepoolPathFile = ".\.claude\genepool-path.txt"
if (Test-Path $genepoolPathFile) {
    $GenepoolPath = Get-Content $genepoolPathFile | Where-Object { $_ -notmatch '^#' -and $_ -ne '' } | Select-Object -First 1
    Write-Host "Using stored genepool path: $GenepoolPath"
} else {
    Write-Host "Please run with admin privileges to get genepool path:"
    Write-Host "  .\Resolve-GenepoolPath.ps1"
    Write-Host "Then add the path to $genepoolPathFile"
    # User must provide path
    $GenepoolPath = Read-Host "Enter genepool path"
}

# 3. Manually copy to local genepool
$source = "genes\dbosoft\my-fodder\next\.packed\*"
$dest = "$GenepoolPath\dbosoft\my-fodder\next"
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item $source -Destination $dest -Recurse

# 4. Deploy test catlet (this makes the gene discoverable)
# DO NOT use Get-CatletGene - just deploy directly!
$spec = @"
name: test-fodder
parent: dbosoft/ubuntu-22.04/starter
fodder:
- source: gene:dbosoft/my-fodder:my-setup
  variables:
  - name: app_name
    value: testapp
"@

$spec | Out-File test.yaml
Get-Content test.yaml -Raw | New-Catlet

# The deployment itself discovers and registers the gene
```

#### Run Automated Tests
```powershell
# IMPORTANT: test_packed.ps1 handles the genepool path internally
# It copies .packed content and deploys test VMs

# Test specific packed gene (requires genes/<geneset>/.packed folder to exist)
.\test_packed.ps1 -Geneset "dbosoft/ubuntu-22.04/20241216" -OsType linux

# Keep VM after test for debugging
.\test_packed.ps1 -Geneset "dbosoft/my-fodder/next" -OsType linux -KeepVM

# Test creates a VM named "catlettest" with:
# - Linux: SSH key injection via starter-food
# - Windows: PowerShell remoting enabled, admin/InitialPassw0rd
```

### 4. Versioning & Publishing

#### Create Changeset for Version Update
```bash
# 1. Stage your changes
git add .

# 2. Create changeset (for version bumps)
npx changeset

# 3. Select packages to version
# Choose major/minor bump (patch not used for tags)
# Write clear changeset description
```

#### Version and Build for Release
```bash
# Option 1: Manual build
turbo build

# Option 2: Version and publish workflow (for releases)
pnpm publish-genesets
# This runs: changeset version && turbo run publish && changeset publish
```

#### Push to Genepool
```powershell
# Ensure you're logged in (if pushing private genes)
eryph-zero genepool login

# Push all packed genes to genepool (skips 'next' tags)
.\push_packed.ps1
# This uses: eryph-packer geneset-tag push <geneset> --workdir genes

# Clean up .packed folders after successful push
.\delete_packed.ps1
```

### 5. Managing Existing Genes

#### Update Existing Gene Version
1. Modify source files in `src/genename/default/`
2. Create changeset: `npx changeset`
3. Build: `turbo build`
4. Test locally before pushing

#### Add New OS Version (Base Catlets)
```powershell
# Base catlets are built from the hyperv-boxes repo (should be at ..\hyperv-boxes)
# The hyperv-boxes repo uses Packer to build VM images from ISOs

# 1. Ensure hyperv-boxes repo is present
if (!(Test-Path "..\hyperv-boxes")) {
    git clone https://github.com/eryph-org/hyperv-boxes.git ..\hyperv-boxes
}

# 2. Build new OS version (runs Packer, catletlify, pack, and test)
.\build.ps1 -BuildPath "..\hyperv-boxes\builds" -Filter "ubuntu-24.04*"

# The build.ps1 script will:
# - Run hyperv-boxes\build.ps1 to create VM with Packer
# - Run catletlify.ps1 to rename drives/adapters to eryph conventions
# - Run pack_build.ps1 using import.json mapping to create gene
# - Run test_packed.ps1 to validate the gene

# 3. If you need to test manually:
$GenepoolPath = .\Resolve-GenepoolPath.ps1
.\test_packed.ps1 -Geneset "dbosoft/ubuntu-24.04/20250113" -GenepoolPath $GenepoolPath -OsType linux

# 4. Push if tests pass
.\push_packed.ps1

# 5. Clean up .packed folders
.\delete_packed.ps1
```

#### Maintain Starter Variants
Starter variants include pre-configured admin credentials and SSH/RDP access:
```yaml
# Each OS should have a starter variant that references starter-food
parent: dbosoft/ubuntu-22.04/latest
fodder:
  - source: gene:dbosoft/starter-food:linux-starter
```

### 6. Working with Guest Services

The repository includes a special `guest-services` gene for VM guest integration:

```powershell
# Build guest services
pnpm --filter ./src/guest-services build

# Guest services fodder includes:
# - Linux: Systemd service installation
# - Windows: Service installation via PowerShell
```

## Repository Commands Reference

### PowerShell Scripts
- `build.ps1` - Build base catlets from hyperv-boxes repo (at ..\hyperv-boxes)
- `pack_build.ps1` - Package built VMs into genes (called by build.ps1)
- `test_packed.ps1` - Test packed genes by deploying test VMs
- `push_packed.ps1` - Push packed genes to genepool using eryph-packer
- `delete_packed.ps1` - Clean up .packed folders after push
- `prepare.ps1` - Prepare build environment
- `Resolve-GenepoolPath.ps1` - Get genepool path from eryph-zero settings
- `import.json` - Maps hyperv-boxes templates to gene names and tags

### NPM/PNPM Commands
- `pnpm install` - Install dependencies
- `turbo build` - Build all changed packages (creates .packed folders)
- `pnpm build` - Alias for turbo build
- `pnpm publish-genesets` - Run changeset version, turbo publish, and changeset publish
- `npx changeset` - Create version changeset for release workflow

## Automatic Verification Requirements

### When Building Genes - ALWAYS TEST!

Any gene development MUST include automatic verification:

1. **Deploy a test VM** with the new gene
2. **Connect to the VM** (SSH for Linux, PS Remoting for Windows)
3. **Check cloud-init/cloudbase-init logs** for errors
4. **Verify fodder executed** as expected
5. **Clean up** test resources

### Verification Checklist

#### Linux Verification
- [ ] SSH connection works with injected key
- [ ] `sudo cloud-init status` shows "done"
- [ ] No errors in `/var/log/cloud-init-output.log`
- [ ] Expected packages installed (`dpkg -l | grep <package>`)
- [ ] Expected services running (`systemctl status <service>`)
- [ ] Expected files created

#### Windows Verification
- [ ] PowerShell remoting connects successfully
- [ ] cloudbase-init log shows completion
- [ ] No errors in `C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\`
- [ ] Expected Windows features installed
- [ ] Expected services running
- [ ] Registry keys/files as expected

## Best Practices

### Gene Design
1. **Keep base images minimal** - Let users add specifics via fodder
2. **Use variables** for environment-specific values
3. **Document genes** with README.md in geneset directories
4. **Version appropriately**: 
   - Date-based for OS images (20241216)
   - Semantic for fodder/tools (1.0, 1.1)
   - Floating tags (latest, stable, next)

### Fodder Best Practices
1. **Order matters** - Dependencies first
2. **Use cloud-config** for declarations
3. **Use shell scripts** for complex logic
4. **Add debug output** during development
5. **Make variables required** only when essential

### Testing Strategy
1. **Test locally** before pushing to genepool
2. **Use starter genes** for quick credential setup
3. **Test both Linux and Windows** variants
4. **Verify cloud-init/cloubase-init** execution
5. **Check network connectivity** after deployment

## Specialized Agent

This repository includes a specialized eryph agent configuration at `.claude/agents/eryph-specialist.md`. When working with catlets and genes, you can invoke the eryph-specialist agent using the Task tool.

The agent has deep knowledge of:
- Building and testing catlets with eryph PowerShell cmdlets
- Creating custom genes
- Debugging cloud-init/cloubase-init issues
- Managing eryph-zero service and infrastructure
- Genepool API interactions
- SSH/RDP connection troubleshooting

## Important Files

### Configuration Files
- `geneset.json` - Defines geneset metadata
- `geneset-tag.json` - Version-specific tag metadata  
- `catlet.yaml` - Catlet specifications
- `fodder/*.yaml` - Fodder configurations
- `import.json` - Maps hyperv-boxes templates to gene names

### Build Configuration
- `turbo.json` - Turborepo configuration
- `pnpm-workspace.yaml` - PNPM workspace setup
- `package.json` - Root package configuration
- `.changeset/` - Changeset configuration

## Security Considerations

1. **Never commit secrets** in fodder files
2. **Use variables with `secret: true`** for sensitive data
3. **Test credentials** should be clearly marked as insecure
4. **Production genes** should not include default passwords
5. **Use SSH keys** instead of passwords when possible

## Troubleshooting

### Build Failures
```powershell
# Check build dependencies
Get-Command eryph-packer
Get-Service eryph-zero

# Verify build path
Test-Path "C:\path\to\basecatlets-hyperv"

# Check npm packages
pnpm install
pnpm list --depth=0
```

### Gene Not Found
```powershell
# Check if gene was copied to local genepool
$genepoolPathFile = ".\.claude\genepool-path.txt"
if (Test-Path $genepoolPathFile) {
    $GenepoolPath = Get-Content $genepoolPathFile | Where-Object { $_ -notmatch '^#' -and $_ -ne '' } | Select-Object -First 1
} else {
    Write-Host "Run .\Resolve-GenepoolPath.ps1 with admin rights to get path"
}

# Check if files exist in genepool
Get-ChildItem "$GenepoolPath\dbosoft\my-gene" -Recurse

# IMPORTANT: Genes only become discoverable after first deployment!
# Don't use Get-CatletGene - just try to deploy with the gene

# Verify genepool login (for private genes)
eryph-zero genepool login
```

### Testing Issues
```powershell
# Check eryph-zero service
Get-Service eryph-zero

# Verify Hyper-V
Get-WindowsFeature Hyper-V

# Check for running operations
powershell -Command "Get-EryphOperation"
```

## Genepool API - Discovering Available Genes

### REST API Access

The public genepool provides a REST API for discovering available genes without authentication:

#### Base Endpoints
- Production: `https://genepool-api.eryph.io/v1/`
- Alternative: `https://genepool.eryph.io/v1/`

#### Common API Operations

```powershell
# List all genesets from dbosoft organization
Invoke-RestMethod -Uri "https://genepool-api.eryph.io/v1/orgs/dbosoft/genesets?page_size=50"

# Get specific geneset details
Invoke-RestMethod -Uri "https://genepool-api.eryph.io/v1/genesets/dbosoft/ubuntu-22.04"

# List all tags/versions for a geneset
Invoke-RestMethod -Uri "https://genepool-api.eryph.io/v1/genesets/dbosoft/ubuntu-22.04/tags"

# Get specific tag information
Invoke-RestMethod -Uri "https://genepool-api.eryph.io/v1/genesets/dbosoft/ubuntu-22.04/tag/latest"
```

#### Query Parameters
- `page_size` - Number of results per page (default: 10, max: 100)
- `continuation_token` - Token for pagination
- `expand` - Expand nested data: `tags`, `metadata`, `description`
- `no_cache` - Bypass cache for fresh data

#### Discover Available Fodder Genes

```powershell
# Find all fodder genes in dbosoft organization
$response = Invoke-RestMethod -Uri "https://genepool-api.eryph.io/v1/orgs/dbosoft/genesets?page_size=100"

# Filter for fodder genes
$response.values | Where-Object { 
    $_.name -match "food|fodder|config" 
} | ForEach-Object {
    Write-Host "$($_.name): $($_.short_description)"
}

# Common fodder genes:
# - dbosoft/starter-food - Basic user and SSH setup
# - dbosoft/hyperv - Hyper-V installation
# - dbosoft/windomain - Windows domain configuration
# - dbosoft/winconfig - Windows settings
# - dbosoft/guest-services - Guest integration services
```

#### Scan Organization for All Genes

```powershell
# Complete scan of an organization's genepool with pagination
$Organization = "dbosoft"
$allGenesets = @()
$continuationToken = $null

do {
    $uri = "https://genepool-api.eryph.io/v1/orgs/$Organization/genesets?page_size=50"
    if ($continuationToken) {
        $uri += "&continuation_token=$continuationToken"
    }
    
    $response = Invoke-RestMethod -Uri $uri
    $allGenesets += $response.values
    $continuationToken = $response.continuation_token
    
} while ($continuationToken)

# Display results grouped by type
$baseImages = $allGenesets | Where-Object { $_.name -match "ubuntu|win|debian|rocky" }
$fodder = $allGenesets | Where-Object { $_.name -match "food|fodder|config" }

Write-Host "Base Images: $($baseImages.Count)"
Write-Host "Fodder Genes: $($fodder.Count)"
$allGenesets | ForEach-Object { Write-Host $_.name }
```

## Related Resources

- **Main eryph documentation**: See `D:\Source\Repos\eryph\coming-soon\docs\ERYPH.md`
- **eryph website**: https://www.eryph.io
- **Genepool**: https://genepool.eryph.io
- **Genepool API**: https://genepool-api.eryph.io/v1/
- **hyperv-boxes repository**: https://github.com/eryph-org/hyperv-boxes (Packer templates for base OS images)

## Quick Reference

### Essential Commands
```powershell
# Check eryph status
Get-Service eryph-zero

# List catlets
Get-Catlet

# Deploy catlet from gene
Get-Content catlet.yaml -Raw | New-Catlet

# Start catlet
Get-Catlet | Where-Object Name -eq "my-vm" | Start-Catlet -Force

# Get IP address
Get-Catlet | Where-Object Name -eq "my-vm" | Get-CatletIp

# Clean up
Get-Catlet | Where-Object Name -eq "my-vm" | Stop-Catlet -Force
Get-Catlet | Where-Object Name -eq "my-vm" | Remove-Catlet -Force
```

### Gene Naming Convention
```
organization/geneset/tag
dbosoft/ubuntu-22.04/latest
  ├─ Organization (dbosoft)
  ├─ Geneset name (ubuntu-22.04)
  └─ Tag/version (latest, starter, 20241216)
```

### Common Genes
- `dbosoft/ubuntu-22.04/starter` - Ubuntu with admin/admin
- `dbosoft/winsrv2022-standard/starter` - Windows Server with admin
- `dbosoft/starter-food/linux-starter` - Linux admin setup fodder
- `dbosoft/starter-food/win-starter` - Windows admin setup fodder
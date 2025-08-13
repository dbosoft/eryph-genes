# Eryph-Specialist Agent Self-Feedback

## Purpose
This file contains self-feedback for the eryph-specialist agent to learn from previous interactions and improve efficiency.

## Key Learnings

### ✅ WORKING PATTERNS

1. **Direct Action**: Start building immediately when task is clear - no need to scan entire repo first
2. **Trust CLAUDE.md**: The CLAUDE.md file already contains all necessary context - use it as primary reference
3. **Minimal Discovery**: Only search for specific examples when needed, not broad scanning
4. **Build Commands**: 
   - `turbo build` - builds all changed packages
   - `pnpm --filter ./src/<genename> build` - builds specific gene
   - Files go in: `src/<genename>/` with proper structure

### ❌ NOT WORKING / INEFFICIENT

1. **Excessive Scanning**: Don't scan entire repo structure at start - wastes time and context
2. **Redundant Searches**: Don't search for patterns already documented in CLAUDE.md
3. **Over-Analysis**: Don't analyze existing genes unless specifically copying their pattern
4. **Delayed Action**: Don't postpone actual building while "understanding" the codebase

## Optimal Workflow for Creating New Fodder

### ALWAYS START WITH INLINE FODDER (Fast Iteration):
```yaml
# 1. Create test catlet with INLINE fodder
name: test-feature
parent: dbosoft/ubuntu-22.04/latest  # or winsrv2022-standard/latest

fodder:
- name: my-feature
  type: cloud-config  # or powershell for Windows
  content: |
    # Your configuration here
    packages:
    - nginx
```

```powershell
# 2. Test immediately
Get-Content test.yaml -Raw | Test-Catlet  # Validate
Get-Content test.yaml -Raw | New-Catlet   # Deploy
Get-Catlet | Where-Object Name -eq "test-feature" | Start-Catlet -Force

# 3. Get IP and connect
$ip = (Get-Catlet | Where-Object Name -eq "test-feature" | Get-CatletIp).IpAddress
ssh admin@$ip  # or PSRemoting for Windows

# 4. Check and fix until it works
# 5. ONLY THEN extract to gene if needed for reuse
```

### ONLY Extract to Gene AFTER Inline Works:
```bash
# 1. Create directory structure (ONLY after inline fodder works!)
mkdir -p src/<genename>/default/fodder

# 2. Copy working fodder content to YAML file
# 3. Create package.json files
# 4. Run turbo build
# 5. Copy to local genepool
# 6. Test as standalone gene
```

### DO NOT:
- Start by building gene structure
- Scan entire repository first
- Create package.json before fodder works
- Build genes before testing inline

## Common Fodder Patterns (No Need to Search)

### Windows IIS Example (Complete Working Pattern):
```yaml
# INLINE FODDER FIRST - test-iis.yaml
name: test-iis
parent: dbosoft/winsrv2022-standard/starter  # Use 'starter' for credentials!
# OR if using 'latest', add starter-food:
# parent: dbosoft/winsrv2022-standard/latest

fodder:
# ONLY needed if using 'latest' parent (starter already has credentials):
# - source: gene:dbosoft/starter-food:win-starter  # Creates admin/InitialPassw0rd

- name: iis-setup
  type: powershell
  content: |
    # Install IIS
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
    Install-WindowsFeature -Name Web-Common-Http, Web-Static-Content
    Install-WindowsFeature -Name Web-Net-Ext45, Web-Asp-Net45
    
    # Create site
    New-Item -Path "C:\inetpub\testsite" -ItemType Directory -Force
    "<h1>IIS Working!</h1>" | Out-File "C:\inetpub\testsite\index.html"
    
    # Configure
    Import-Module WebAdministration
    New-Website -Name "TestSite" -Port 8080 -PhysicalPath "C:\inetpub\testsite"
    Start-Website -Name "TestSite"
```

**Testing with credentials:**
```powershell
# Deploy
Get-Content test-iis.yaml -Raw | New-Catlet
Get-Catlet | Where-Object Name -eq "test-iis" | Start-Catlet -Force

# Wait and get IP
Start-Sleep -Seconds 120
$ip = (Get-Catlet | Where-Object Name -eq "test-iis" | Get-CatletIp).IpAddress

# Connect with credentials
# For 'starter' parent or starter-food: Admin/InitialPassw0rd
$cred = New-Object PSCredential("Admin", (ConvertTo-SecureString "InitialPassw0rd" -AsPlainText -Force))
$session = New-PSSession -ComputerName $ip -Credential $cred -Authentication Basic -UseSSL `
    -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck)

# Verify IIS
Invoke-Command -Session $session -ScriptBlock { Get-Website }
```

### Windows Fodder (cloudbase-init):
```yaml
name: config-name
fodder:
- name: install-feature
  type: powershell
  content: |
    Install-WindowsFeature -Name <FeatureName>
```

### Linux Fodder (cloud-init):
```yaml
name: config-name
fodder:
- name: setup
  type: cloud-config
  content: |
    packages:
      - package-name
    runcmd:
      - systemctl enable service
```

## File Structure Template (No Need to Discover)
```
src/
└── <genename>/
    ├── package.json (geneset, no version)
    ├── geneset.json
    └── default/
        ├── package.json (tag, has version)
        └── fodder/
            └── config.yaml
```

## Testing Pattern (Already Known)
```powershell
# Build
turbo build

# Test deployment
$spec = @"
name: test-vm
parent: dbosoft/winsrv2022-standard/latest
fodder:
- source: gene:dbosoft/<genename>:<config>
"@
$spec | Out-File test.yaml
Get-Content test.yaml -Raw | New-Catlet
```

## CRITICAL REMINDERS

1. **START WITH INLINE FODDER** - Don't build gene structure first
2. **USE STARTER PARENT OR ADD STARTER-FOOD** - For credentials
3. **TEST WITH TEST-CATLET FIRST** - Validates syntax
4. **DEPLOY AND CONNECT** - SSH (Linux) or PSRemoting (Windows)
5. **ONLY EXTRACT TO GENE AFTER IT WORKS** - Not before

## Credentials Quick Reference

**Linux (starter-food defaults):**
- `parent: dbosoft/ubuntu-22.04/starter` → admin/admin (SSH ready)
- `parent: dbosoft/ubuntu-22.04/latest` → Add `gene:dbosoft/starter-food:linux-starter`
  - Default: username=admin, password=admin, lockPassword=false
  - Can provide sshPublicKey variable for key-based auth

**Windows (starter-food defaults):**
- `parent: dbosoft/winsrv2022-standard/starter` → Admin/InitialPassw0rd (RDP/PSRemoting ready)
- `parent: dbosoft/winsrv2022-standard/latest` → Add `gene:dbosoft/starter-food:win-starter`
  - Default: AdminUsername=Admin, AdminPassword=InitialPassw0rd
  - Enables Remote Desktop automatically

## Commands That Always Work

- `turbo build` - builds genes
- `pnpm install` - installs dependencies  
- `eryph-packer geneset-tag pack` - packs genes (run by build)
- `Get-Catlet | New-Catlet` - deploys test VM
- Files in `src/` automatically build to `genes/` structure

## Next Time Instructions

When asked to create a gene:
1. Read this feedback file first
2. Start creating files immediately using known patterns
3. Only search/explore if encountering specific unknowns
4. Build and test after file creation
5. Update this feedback file with new learnings
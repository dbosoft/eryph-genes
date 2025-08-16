# eryph-genes Repository

## ⚠️ CRITICAL - ALWAYS DO THIS

### PowerShell Command Troubleshooting
**If eryph PowerShell commands or EGS SSH operations start failing:**
- **IMMEDIATELY** read `docs/eryph-commands-via-claude.md` 
- Verify you're using the EXACT command syntax documented there
- Common failures: NullReferenceException, SSH connection errors, missing `-SkipVariablesPrompt`
- The documentation contains proven working patterns - always refer back when errors occur

## Overview

This repository manages the official eryph genes maintained by dbosoft. Genes are the evolutionary units of infrastructure in eryph - reusable templates that catlets (VMs) inherit from.

**Repository contains:**
- Catlet genes - VM specifications
- Fodder genes - Configuration templates (cloud-init/cloubase-init)
- Volume genes - Disk volumes for base OS images

**Dependencies:**
- **hyperv-boxes repository** (expected at `..\hyperv-boxes`) - Contains Packer templates for building base OS images
- **eryph-zero** - Must be installed and running for testing
- **eryph-packer** - Required for packaging and pushing genes to genepool

## Repository Structure

```
eryph-genes/
├── src/              # Source templates for genesets (npm packages)
│   └── genename/     # Source for each geneset
│       ├── package.json     # Geneset package (no version)
│       ├── geneset.json     # Geneset metadata
│       └── default/         # Default tag (or other version tags)
│           ├── package.json # Tag package (has version)
│           └── fodder/      # Fodder YAML files
├── genes/            # Built genesets with .packed folders after build
├── packages/         # npm tooling packages (build-geneset, build-geneset-tag)
├── tests/            # Test catlet templates and SSH module
└── *.ps1            # PowerShell build/test/push scripts
```

## Two-Phase Development Workflow

### ⚠️ MANDATORY: Use Specialized Agents for Catlet/Gene Creation

**NEVER attempt to create catlets or genes without using the appropriate agent!**
- Creating catlets involves complex template processing across multiple execution contexts
- The agents have specialized knowledge to avoid common pitfalls
- Manual attempts WILL result in broken fodder due to execution timing issues

### Phase 1: Inline Fodder Development (eryph-specialist agent)
**ALWAYS use this agent when:**
- User asks to "create a catlet" or "generate fodder"
- Testing any new functionality with inline YAML
- Debugging catlet deployment issues
- See `docs/eryph-knowledge.md` for examples

### Phase 2: Gene Extraction (gene-maintainer agent)
**ALWAYS use this agent when:**
- Extracting tested inline fodder to reusable genes
- Building genes with npm/turbo system
- Publishing to genepool
- Managing the repository structure

### Critical Fodder Creation Rules (for agent reference)
1. **Variable substitution happens ONCE** - Eryph replaces `{{ variable }}` BEFORE cloud-init sees the file
2. **No Jinja2 conditionals** - Cannot use `{% if %}` in fodder (only `{{ }}` substitution works)
3. **Bash conditionals only** - All conditional logic must be in bash/PowerShell scripts
4. **Package installation timing** - Packages installed via `packages:` may not be available immediately in `runcmd:`
5. **Service readiness** - Never assume services are ready immediately after installation

## Knowledge Base

**Essential documentation in `docs/`:**
- `eryph-knowledge.md` - Core eryph concepts, architecture, examples
- `eryph-commands-via-claude.md` - Command execution patterns, EGS setup, troubleshooting

## Testing with Eryph Guest Services (EGS)

The new EGS version simplifies SSH access to catlets - no SSH key injection needed!

### Quick EGS Setup for Testing

**⚠️ CRITICAL: ALWAYS use `C:/Windows/System32/OpenSSH/ssh.exe` - NOT just `ssh`!**

```bash
# Step 1: Deploy catlet with EGS fodder (no variables needed!)
powershell -Command "Get-Content test-catlet.yaml | New-Catlet"
# Note the output - you'll need the VmId (e.g., 2a2d0357-d565-4d86-b2c7-8c041a814362)

# Step 2: Register VM with EGS (use the VmId from step 1)
egs-tool add-ssh-config <VmId>  # Replace <VmId> with actual ID from step 1

# Step 3: Generate SSH configuration for all registered VMs
egs-tool update-ssh-config

# Step 4: Start the catlet
powershell -Command "Get-Catlet -Name 'test-name' | Start-Catlet -Force"

# Step 5: Wait for EGS to be available (use VmId from step 1)
egs-tool get-status <VmId>  # Keep checking until it returns "available"

# Step 6: Connect via SSH (MUST use Windows OpenSSH!)
# You can use any of these formats:

C:/Windows/System32/OpenSSH/ssh.exe <catlet-id>.eryph.alt -C hostname
C:/Windows/System32/OpenSSH/ssh.exe <VmId>.hyper-v.alt -C hostname
```

### Test Catlet Template with EGS
```yaml
name: test-name
parent: dbosoft/winsrv2022-standard/starter

fodder:
  # Include guest services - no variables needed!
  - source: gene:dbosoft/guest-services:latest:win-install  # or :linux-install for Linux
  # Your test fodder here
  - source: gene:dbosoft/your-gene:tag
```

### Key Points
- **No SSH key variables** - The new EGS handles authentication automatically
- **Two-step configuration**: `add-ssh-config <VmId>` then `update-ssh-config`
- **Use VM ID** (from catlet output) for `add-ssh-config` and `get-status`
- **SSH hostname options**: `<catlet-id>.eryph.alt`, `<catlet-name>.eryph.alt`, or `<catlet-name>.<project>.eryph.alt`
- **Windows SSH required**: Must use `C:/Windows/System32/OpenSSH/ssh.exe`

## Build System

### ⚠️ IMPORTANT: Creating Genesets is Complex!
**Creating a new geneset is NOT just copying files!** It requires:
1. **Two separate npm packages**: geneset package (no version) + tag package(s) (with versions)
2. **Proper dependency structure**: Tag packages must depend on their parent geneset
3. **Correct package.json setup**: Different requirements for geneset vs tag packages
4. **geneset.json metadata**: Must match package structure
5. **Turbo build integration**: Must work with the monorepo build system

**ALWAYS use the gene-maintainer agent for creating new genesets** - it has specialized knowledge of the npm/turbo build system and package relationships.

### Package Structure
- **Geneset packages** (`src/genename/`) - Define gene family, NO version in package.json
- **Tag packages** (`src/genename/default/`) - Define versions, HAVE version in package.json  
- Tags are dependencies of their parent geneset
- Each tag folder contains its own package.json and fodder/ directory

### Build Commands
```bash
pnpm install        # Install dependencies
turbo build         # Build all packages (creates "next" tag)
pnpm publish-genesets  # Version and publish workflow
npx changeset       # Create version changeset
```

### PowerShell Scripts
- `Resolve-GenepoolPath.ps1` - Get local genepool path (requires admin)
- `build.ps1` - Build base catlets from hyperv-boxes
- `test_packed.ps1` - Test packed genes
- `push_packed.ps1` - **⚠️ DANGER: Pushes to PUBLIC GENEPOOL! NEVER use for testing!**
- `delete_packed.ps1` - Clean up .packed folders

**CRITICAL: For local testing, ALWAYS use the gene-maintainer agent to copy genes to local genepool. NEVER use push_packed.ps1 until after full testing and verification!**

## Local Testing Requirements

### Genepool Path Configuration
Before testing genes locally, you must configure the genepool path:
1. Run `.\Resolve-GenepoolPath.ps1` as Administrator
2. Store the path in `.\.claude\genepool-path.txt`
3. The gene-maintainer agent will use this for copying built genes

### Testing Workflow
1. Build gene with `turbo build`
2. Copy `.packed` content to local genepool
3. Deploy test catlet referencing the gene
4. Verify functionality before publishing

## Troubleshooting

### PowerShell NullReferenceException
"Der Objektverweis wurde nicht auf eine Objektinstanz festgelegt"
- Missing `-SkipVariablesPrompt` when YAML has variables
- Missing `-Force` flag where required
- See `docs/eryph-commands-via-claude.md` for details

### Gene Not Found
- Genes only become discoverable after first deployment
- Don't use `Get-CatletGene` before deploying
- Check if files exist in local genepool path

## Specialized Agents

This repository includes two specialized agents:

### eryph-specialist
- Phase 1: Inline fodder development and testing
- Located at `.claude/agents/eryph-specialist.md`
- Use for rapid prototyping and debugging

### gene-maintainer
- Phase 2: Gene extraction and repository management
- Located at `.claude/agents/gene-maintainer.md`
- Use for building and publishing reusable genes

## Important Notes

- **Variable Syntax**: Use `{{ variable }}` in YAML files, not PowerShell `$variable`
- **Version Strategy**: Date-based for OS images (20241216), semantic for fodder (1.0, 1.1)
- **Testing Required**: Always test genes locally before publishing
- **Security**: Never commit secrets in fodder files

## Related Resources

- **Genepool**: https://genepool.eryph.io
- **Genepool API**: https://genepool-api.eryph.io/v1/
- **hyperv-boxes repository**: https://github.com/eryph-org/hyperv-boxes
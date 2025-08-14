# eryph-genes Repository

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

### Phase 1: Inline Fodder Development (eryph-specialist agent)
- Create and test fodder directly in catlet YAML
- Deploy and verify functionality
- Iterate quickly without building genes
- See `docs/eryph-knowledge.md` for examples

### Phase 2: Gene Extraction (gene-maintainer agent)
- Extract working inline fodder to reusable genes
- Build with npm/turbo system
- Test via local genepool
- Publish to public genepool

## Knowledge Base

**Essential documentation in `docs/`:**
- `eryph-knowledge.md` - Core eryph concepts, architecture, examples
- `eryph-commands-via-claude.md` - Command execution patterns, EGS setup, troubleshooting

## Testing with Eryph Guest Services (EGS)

When testing genes, always use EGS for SSH access to catlets:

### Quick EGS Setup for Testing
```powershell
# Get EGS SSH key
$egsKey = (egs-tool.exe get-ssh-key | Out-String).Replace("`r`n", "").Trim()

# Deploy catlet with EGS
Get-Content test-catlet.yaml | New-Catlet -Variables @{ egskey = $egsKey } -SkipVariablesPrompt

# Wait for catlet to start, then update SSH config
egs-tool.exe update-ssh-config

# Connect via SSH (use catlet ID)
$catletId = (Get-Catlet | Where-Object Name -eq 'test-name').Id
cmd /c ssh "$catletId.eryph.alt" -C "hostname"
```

### Test Catlet Template with EGS
```yaml
variables:
  - name: egskey
    secret: true

fodder:
  # Always include guest services for SSH access
  - source: gene:dbosoft/guest-services:win-install  # or :linux-install for Linux
    variables:
      - name: sshPublicKey
        value: '{{ egskey }}'
  # Your test fodder here
  - source: gene:dbosoft/your-gene:tag
```

## Build System

### Package Structure
- **Geneset packages** (`src/genename/`) - Define gene family, NO version in package.json
- **Tag packages** (`src/genename-default/`) - Define versions, HAVE version in package.json
- Tags are dependencies of their parent geneset

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
- `push_packed.ps1` - Push to genepool
- `delete_packed.ps1` - Clean up .packed folders

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
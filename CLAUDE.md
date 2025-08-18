# eryph-genes Repository

## ⚠️ CRITICAL - ALWAYS DO THIS

### Multi-Agent System for Eryph Tasks
**NEVER execute or generate eryph commands. Always use:**
1. **Creation agents** (eryph-specialist/gene-maintainer) for artifacts
2. **Identify operation types** (deploy-catlet, run-ssh, etc.)
3. **Execution agents** (eryph-powershell-executor/egs-executor) for command execution
4. **Return errors to creation agents** for interpretation

**See `docs/orchestration-guide.md` for detailed flow**

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

## Multi-Agent Orchestration System

### ⚠️ CRITICAL: Never Execute Eryph Commands Directly!

**Main Claude must NEVER attempt to run eryph commands directly.** Command syntax degrades under debugging pressure, leading to errors. Always use the multi-agent system.

### The Agents

#### 1. eryph-specialist (Creation Agent)
**Use when:**
- Creating new catlets or fodder
- User needs inline YAML for testing
- Prototyping new configurations

**Returns:** Artifact + operation hints + error interpretation

#### 2. gene-maintainer (Extraction Agent)
**Use when:**
- Extracting tested inline fodder to genes
- Building/publishing genes
- Managing repository structure

**Returns:** Gene structure + needed operation types

#### 3. eryph-powershell-executor (PowerShell Execution Agent)
**ALWAYS use for:**
- Running eryph PowerShell commands (New-Catlet, Test-Catlet, Start-Catlet, etc.)
- Polling long-running operations
- Managing catlets via PowerShell

**Receives:** Operation type + parameters
**Returns:** Raw output or errors (no interpretation)

#### 4. egs-executor (EGS & SSH Execution Agent)
**ALWAYS use for:**
- EGS tool operations (setup, file transfer)
- SSH commands to VMs
- Testing VM configurations

**Receives:** Operation type + parameters
**Returns:** Raw output or errors (no interpretation)

### Orchestration Flow

```
User Request → Main Claude (recognize eryph task)
    ↓
Creation Agent (specialist/maintainer)
    ↓
Returns: artifact + operation hints
    ↓
Main Claude: Identify operation type & choose executor
    ↓
PowerShell Executor (for catlet ops) OR EGS Executor (for SSH/EGS ops)
    ↓
Returns: output/error
    ↓
Main Claude: Categorize error type
    ↓
If CONTENT error → Back to Creation Agent for interpretation
If STATE error → Handle directly (see Error Handling below)
```

### Critical Rules
1. **Main Claude:** Orchestrates, identifies operation types, chooses executor, NEVER generates commands
2. **Creation Agents:** Create artifacts and suggest operation types
3. **PowerShell Executor:** Handles all eryph PowerShell commands with polling
4. **EGS Executor:** Handles SSH and EGS tool operations
5. **Errors:** Categorize first, then route appropriately (see Error Handling)

### OVERRIDE DIRECTIVE: Orchestration Above Efficiency
- **EVEN IF** you see the obvious fix → still use eryph-specialist
- **EVEN IF** it seems inefficient → the pattern IS the test
- **WHEN** executor returns CONTENT error → your ONLY action: return to creation agent
- **Breaking this pattern means the test FAILS** (we're testing agents, not just deploying)

### Error Handling - Main Claude Decision Tree

**CONTENT ERRORS (Return to Creation Agent):**
- Validation failures (missing fields, wrong schema, invalid YAML)
- Syntax errors in YAML or fodder
- Invalid gene references or missing genes
- Variable format issues (e.g., key-value vs array-of-objects)
- Incorrect cloudbase-init/cloud-init directives
- Missing required parameters in commands

**STATE ERRORS (Handle Directly):**
- **Resource already exists** → Get existing resource ID, decide to use/remove/rename
- **Resource not found** → Check if deleted, verify name/ID
- **Catlet already running/stopped** → Adjust operation accordingly
- **Operation in progress** → Poll for completion
- **Permission denied** → Request admin rights or different credentials
- **Network/connectivity issues** → Retry or check connectivity
- **Prerequisites missing** → Install/configure prerequisites

**Decision Logic:**
1. If error is about YAML/fodder/gene CONTENT → Return to creation agent
2. If error is about system STATE/resources → Handle directly with appropriate operation
3. If unsure → Check error message for keywords:
   - "validation", "schema", "syntax", "invalid" → CONTENT
   - "exists", "not found", "already", "conflict", "permission" → STATE

### Common Operation Types
**PowerShell Executor:**
- `deploy-catlet` → Deploy YAML with -Verbose and -SkipVariablesPrompt (returns catlet ID and VmId)
- `test-catlet` → Test configuration resolution
- `start-catlet`, `stop-catlet`, `remove-catlet` → Catlet lifecycle (ALWAYS use -Id parameter with catlet ID)
- `poll-operation` → Check long-running operation status

**⚠️ CRITICAL: Catlet IDs vs VmIds for Automation**
- **New-Catlet returns a catlet object with both ID and VmId** - ALWAYS capture BOTH
- **PowerShell operations use Catlet ID** (-Id parameter with catlet ID)
- **EGS operations MUST use VmId** (NOT catlet ID!)
- **Names are NOT unique** - multiple catlets can have same name
- **IDs are GUIDs and guaranteed unique** - required for reliable automation
- Example: `Start-Catlet -Id $catletId -Force` (uses catlet ID)
- Example: `egs-tool add-ssh-config $vmId` (uses VmId, NOT catlet ID!)

**EGS Executor:**
- `run-ssh` → Run ANY command in VM (you compose the command) - REQUIRES VmId
- `setup-egs` → Configure SSH access - REQUIRES VmId
- `test-egs` → Check EGS status with `egs-tool get-status {vmid}` - REQUIRES VmId
- `upload-file`, `download-file` → File transfer - REQUIRES VmId

**Build Executor:**
- `build-gene` → Build with turbo
- `build-all-genes` → Build entire repository
- `copy-to-genepool` → Copy to local genepool
- `resolve-genepool-path` → Get local genepool path (requires admin)

### Phase Transitions
- **Inline working?** → Suggest gene-maintainer for extraction
- **Gene built?** → Use eryph-powershell-executor for deployment test
- **Catlet deployed and started?** → Use egs-executor `setup-egs` FIRST
- **EGS configured?** → Now use egs-executor for `run-ssh` operations
- **Error occurred?** → Return to appropriate creation agent

## Knowledge Base

**Essential documentation in `docs/`:**
- `orchestration-guide.md` - How to use the three-agent system
- `command-reference.md` - All eryph commands in one place
- `error-patterns.md` - Error interpretation for agents
- `eryph-knowledge.md` - Core eryph concepts only
- `debug_catlet_deployment.md` - Systematic error detection in deployed catlets

## Testing with Eryph Guest Services (EGS)

**EGS provides SSH access to catlets without key injection.**

### Testing Process
1. **Create test catlet** → Use eryph-specialist agent
2. **Deploy and configure** → Request eryph-powershell-executor operation `deploy-catlet` (captures both catlet ID and VmId)
3. **Start catlet** → Request eryph-powershell-executor operation `start-catlet` with catlet ID
4. **Setup EGS access** → Request egs-executor operation `setup-egs` with VmId (NOT catlet ID!) (REQUIRED before SSH!)
5. **Check EGS status** → Request egs-executor operation `test-egs` with VmId to verify connectivity
6. **Access VM** → Request egs-executor operation `run-ssh` with VmId
7. **Debug issues** → Return errors to specialist for interpretation

### Test Catlet Template Structure
```yaml
name: test-name
parent: dbosoft/winsrv2022-standard/starter

fodder:
  # Guest services gene enables SSH access
  - source: gene:dbosoft/guest-services:win-install  # implicit tag: latest
  # or for explicit tag:
  # - source: gene:dbosoft/guest-services/v1.0:win-install
  # Your test fodder
  - source: gene:dbosoft/your-gene:tag
```

**Remember: eryph-specialist provides artifacts. Main Claude identifies operations and chooses executor. Executors execute without interpretation.**

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

### Build Process
- **Installing dependencies** → gene-maintainer suggests operations
- **Building genes** → gene-maintainer identifies what to build
- **Publishing workflow** → gene-maintainer guides versioning
- **Execution** → build-executor runs all build commands

### Repository Scripts (What They Do)
- `Resolve-GenepoolPath.ps1` - Resolves local genepool path (requires admin)
- `build.ps1` - Builds base catlets from hyperv-boxes
- `test_packed.ps1` - Tests packed genes
- `Test-PackedBaseCatlet.ps1` - Orchestrates base catlet testing
- `Test-FodderGene.ps1` - Orchestrates fodder gene testing
- `push_packed.ps1` - **⚠️ DANGER: Pushes to PUBLIC GENEPOOL! NEVER use for testing!**
- `delete_packed.ps1` - Cleans up .packed folders

**⚠️ CRITICAL WARNING: NEVER use push_packed.ps1 for testing!** 
- This script pushes to the PUBLIC genepool at genepool.eryph.io
- Once pushed, genes CANNOT be removed
- For local testing, ALWAYS use gene-maintainer to create copy commands to local genepool
- Only use push_packed.ps1 after FULL testing and verification

**To run any of these scripts:** Use appropriate agent to get commands → appropriate executor runs them

## Local Testing Requirements

### Genepool Path Configuration
Before testing genes locally, the genepool path must be detected: 
Script .\Resolve-GenepoolPath.ps1

### Testing Workflow
1. **Build gene** → gene-maintainer provides build commands → executor runs them
2. **Copy to local genepool** → gene-maintainer suggests copy operation → build-executor runs it
3. **Deploy test catlet** → eryph-specialist creates test YAML → eryph-powershell-executor deploys
4. **Verify functionality** → specialist provides verification commands → egs-executor runs SSH tests

## Troubleshooting

### PowerShell NullReferenceException
"Der Objektverweis wurde nicht auf eine Objektinstanz festgelegt"
- Missing `-SkipVariablesPrompt` when YAML has variables
- See `docs/error-patterns.md` for all error patterns

### Gene Not Found
- Genes only become discoverable after first deployment
- Don't use `Get-CatletGene` before deploying
- Check if files exist in local genepool path

## Specialized Agents

This repository uses a multi-agent system:

### eryph-specialist
- Phase 1: Creates inline fodder YAML
- Located at `.claude/agents/eryph-specialist.md`
- Returns artifacts and exact commands

### gene-maintainer
- Phase 2: Extracts fodder to genes
- Located at `.claude/agents/gene-maintainer.md`
- Returns gene structure and build commands

### eryph-powershell-executor
- Executes eryph PowerShell commands
- Located at `.claude/agents/eryph-powershell-executor.md`
- Handles long-running operations with polling

### egs-executor
- Executes EGS and SSH commands
- Located at `.claude/agents/egs-executor.md`
- Handles VM access and testing

### build-executor
- Executes gene build and genepool operations
- Located at `.claude/agents/build-executor.md`
- Handles pnpm, turbo, and xcopy commands

## Important Notes

- **Variable Syntax**: Use `{{ variable }}` in YAML files, not PowerShell `$variable`
- **Version Strategy**: Date-based for OS images (20241216), semantic for fodder (1.0, 1.1)
- **Testing Required**: Always test genes locally before publishing
- **Security**: Never commit secrets in fodder files

## Related Resources

- **Genepool**: https://genepool.eryph.io
- **Genepool API**: https://genepool-api.eryph.io/v1/
- **hyperv-boxes repository**: https://github.com/eryph-org/hyperv-boxes
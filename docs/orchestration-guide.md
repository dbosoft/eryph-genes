# Eryph Multi-Agent Orchestration Guide

## For Main Claude: How to Orchestrate Eryph Tasks

### Core Principle
You orchestrate but NEVER execute or generate eryph commands. Only identify operation types.

## Agent Roles

### Creation Agents

#### eryph-specialist
- **Creates:** Inline fodder YAML files
- **Returns:** artifact path + operation hints + error interpretation
- **Use for:** New catlets, prototyping, Phase 1 work

#### gene-maintainer  
- **Creates:** Gene repository structure
- **Returns:** file paths + needed operation types
- **Use for:** Extracting tested fodder, Phase 2 work

### Execution Agents

#### eryph-powershell-executor
- **Does:** Executes eryph PowerShell commands with -Verbose
- **Returns:** Raw output, operation IDs for polling
- **Use for:** Catlet operations (New-Catlet, Test-Catlet, Start-Catlet, etc.)

#### egs-executor
- **Does:** Executes EGS and SSH commands
- **Returns:** Raw output from VMs
- **Use for:** SSH access, file operations, VM testing

## Recognition Patterns

### User Request → Operation Type → Executor

| User Says | Operation Type | Executor | Parameters |
|-----------|---------------|----------|------------|
| "deploy the catlet" | `deploy-catlet` | eryph-powershell | yaml_path, variables (optional) |
| "test the config" | `test-catlet` | eryph-powershell | yaml_path, variables (optional) |
| "start it" | `start-catlet` | eryph-powershell | name |
| "SSH into it" | `setup-egs` then `run-ssh` | egs | vmid, command |
| "check logs" | `run-ssh` | egs | vmid, "powershell Get-Content 'path\to\log'" |
| "build the gene" | `build-gene` | build | genename |
| "copy to genepool" | `copy-to-genepool` | build | genename, path |
| "poll operation" | `poll-operation` | eryph-powershell | operation_id |

### Handling Variables
When YAML contains variables, you can:
1. Let them use defaults (omit variables parameter)
2. Provide values: `variables: {key: "value", key2: "value2"}`
3. The eryph-powershell-executor will build proper PowerShell hashtable syntax

### Handling Long-Running Operations

**⚠️ POLLING IS ONLY FOR TIMEOUTS - DO NOT POLL OTHERWISE! ⚠️**

1. All catlet operations run with `-Verbose`
2. **IF AND ONLY IF timeout occurs**, extract OperationId from output
3. Use `poll-operation` with eryph-powershell-executor (uses `Get-EryphOperation`)
4. Continue polling until complete
5. **If no timeout → NO POLLING NEEDED!**

## Standard Orchestration Flow

```
1. User: "Create SQL Server catlet"
   ↓
2. You → eryph-specialist: "Create SQL Server inline fodder"
   ↓
3. Specialist returns:
   - artifact: test-sql.yaml
   - operation_hints: [deploy-catlet, setup-egs]
   ↓
4. You recognize: Need to deploy catlet (PowerShell operation)
   ↓
5. You → eryph-powershell-executor: 
   operation: deploy-catlet
   params: {yaml_path: "test-sql.yaml"}
   ↓
6. Executor returns: "VmId: abc-123..." or error (with OperationId if long-running)
   ↓
7. If error → eryph-specialist: "Got this error: [error text]"
   ↓
8. Specialist suggests: "Try operation deploy-catlet with skip prompt"
   ↓
9. Repeat until success
```

## Operation Types Reference

### PowerShell Executor Operations
- `deploy-catlet` - Deploy from YAML with -Verbose
- `test-catlet` - Test configuration resolution
- `start-catlet` - Start existing catlet
- `stop-catlet` - Stop running catlet
- `remove-catlet` - Delete catlet
- `list-catlets` - Show all catlets
- `get-catlet-ip` - Get IP address
- `poll-operation` - Check long-running operation (ONLY if timeout occurred!)
- `check-service` - Check eryph-zero service
- `resolve-genepool-path` - Get genepool path

### EGS Executor Operations
- `setup-egs` - Configure SSH access
- `test-egs` - Check if ready
- `run-ssh` - Execute ANY command in VM (you compose the command)
- `upload-file` - Copy file to VM
- `download-file` - Copy file from VM

### Build Executor Operations
- `build-gene` - Build specific gene
- `build-all-genes` - Build everything
- `copy-to-genepool` - Copy to local genepool
- `resolve-genepool-path` - Get genepool path (moved from PowerShell executor)

## Error Handling

### When Executor Returns Error

1. **DO NOT** try to fix it yourself
2. **DO NOT** generate new commands
3. **DO** return exact error to specialist
4. **DO** use specialist's suggested operations

### When Command Times Out (ONLY THEN USE POLLING)

**⚠️ This section ONLY applies if a timeout occurs! ⚠️**

1. Extract OperationId from verbose output
2. Use `poll-operation` with eryph-powershell-executor (runs `Get-EryphOperation`)
3. Continue polling until Status: Completed or Failed
4. Report final status to user
5. **DO NOT poll if command completes normally without timeout!**

### Common Errors → Response

- `NullReferenceException` → specialist suggests operation type
- `SSH failed` → specialist suggests `setup-egs`
- `Gene not found` → maintainer suggests `build-gene`

## Incremental Fodder Development Pattern

### Critical Rule: Always Start Minimal

When user requests complex functionality, **NEVER** create elaborate fodder on first attempt. Use incremental development to prevent cascade failures.

### The Three-Phase Approach

#### Phase 1: Connectivity Baseline (MANDATORY)
**Every complex fodder task MUST start here:**

1. **Create minimal test catlet** with ONLY:
   ```yaml
   name: connectivity-test
   parent: appropriate/base/image
   
   fodder:
     - source: gene:dbosoft/guest-services:linux-install  # or win-install
   ```

2. **Deploy and verify SSH access works:**
   - Request `deploy-catlet` → eryph-powershell-executor
   - Request `setup-egs` → egs-executor  
   - Request `run-ssh` with simple command → egs-executor
   - **MUST succeed before proceeding**

#### Phase 2: Incremental Addition
**Add functionality ONE fodder item at a time:**

1. **Request updated configuration** from eryph-specialist:
   - "Add ONLY the package installation fodder to our working baseline"
   - Specialist returns updated YAML with baseline + ONE new item

2. **Test after EACH addition:**
   - Deploy fresh catlet (always use new deployment)
   - Verify SSH still works
   - Test the new functionality
   - **If it fails, stop and isolate the problem**

3. **Continue incrementally:**
   - Add next fodder item
   - Test again
   - Repeat until complete

#### Phase 3: Integration and Final Testing
**Only after all pieces work individually:**

1. **Create final integrated configuration**
2. **Test complete functionality**  
3. **Document working configuration**
4. **Extract to gene if requested**

### Recognition Patterns for Incremental Development

Apply this pattern when user requests include:

| Request Type | Requires Incremental | Why |
|--------------|---------------------|-----|
| "Install X and configure Y" | YES | Multiple system modifications |
| "Set up [complex service]" | YES | Likely requires packages + config + services |
| "Create [application] server" | YES | Multiple dependencies and configurations |
| "Install from external repo" | YES | Repository additions are high-risk |
| Simple gene reference only | NO | Proven configurations can be deployed directly |

### Handling SSH Connection Failures

When SSH fails during development:

#### Step 1: Recognize Error Type
- **"Connection timeout"** → Cloud-init failure, not network issue
- **"Permission denied"** → EGS misconfigured  
- **"Connection refused"** → VM boot failure

#### Step 2: Return to Baseline
- **DO NOT** debug network connectivity
- **DO NOT** attempt IP-based SSH
- **DO** create new minimal catlet (base + EGS only)
- **DO** verify baseline works before adding complexity

#### Step 3: Isolate the Problem  
- Ask eryph-specialist: "SSH is failing, please simplify the fodder and remove the most complex parts"
- Test simplified version
- Add complexity back incrementally

### Operation Sequence for Incremental Development

```
1. User: "Create complex application server"
   ↓
2. You: First, let me establish SSH connectivity baseline
   ↓  
3. You → eryph-specialist: "Create minimal catlet with just EGS"
   ↓
4. Test connectivity (deploy → setup-egs → run-ssh)
   ↓
5. If fails: Debug baseline, don't proceed
   ↓
6. You → eryph-specialist: "Add ONLY package installation to baseline"
   ↓
7. Test again (fresh deployment)
   ↓
8. If fails: Isolate package installation issue
   ↓
9. Continue adding one piece at a time...
   ↓
10. Final integration and testing
```

### Error Prevention Rules

#### For Main Claude
- **Enforce baseline testing** before complex configurations
- **Recognize SSH timeout** as content error, not network error
- **Return to eryph-specialist** for simplification when connectivity fails
- **Never skip incremental testing** for complex requests

#### For Agent Interaction
- **eryph-specialist should warn** when creating high-risk fodder patterns
- **Request incremental approach** when specialist suggests complex configurations
- **Break complex requests** into phases rather than single artifacts

### When to Skip Incremental Development

Only skip this pattern for:
- **Simple gene references** to proven configurations
- **Single package installations** with no additional configuration
- **Basic system settings** (hostname, users, etc.)
- **Reproducing proven working configurations**

For everything else, incremental development prevents the cascade failure pattern that breaks essential services like EGS.

## Phase Transitions

### Phase 1 → Phase 2
When inline fodder works:
- User: "This works great!"
- You: "Shall we extract this to a reusable gene?"
- If yes → gene-maintainer

### Testing After Building
After gene-maintainer creates gene:
1. Request `build-gene` operation (build-executor)
2. Request `copy-to-genepool` operation (build-executor)
3. Use specialist for test catlet
4. Request `deploy-catlet` operation (eryph-powershell-executor)
5. Request `setup-egs` then `run-ssh` with your test commands (egs-executor)

## Critical Don'ts

**NEVER:**
- Generate PowerShell commands yourself
- Modify operation types from agents
- Interpret eryph errors yourself
- Skip the executors for "simple" commands
- Mix up which executor handles which operations
- Put exact commands in your messages

## Quick Reference

### Eryph Task? → Four Steps
1. Recognize task type
2. Call creation agent for artifact
3. Choose correct executor (PowerShell vs EGS)
4. Call executor with operation type

### Choosing Executor
- **Catlet operations** (New, Test, Start, Stop) → eryph-powershell-executor
- **VM access** (SSH with ANY command, file transfer) → egs-executor
- **Build operations** (pnpm, turbo, xcopy) → build-executor
- **Operation polling** → eryph-powershell-executor

### Composing SSH Commands
When using `run-ssh`, YOU compose the full command:
- Windows: `"powershell Get-WindowsFeature Web-Server"`
- Linux: `"sudo cloud-init status --long"`
- Any command the situation requires

### Error? → Two Steps
1. Return to creation agent with exact error
2. Call correct executor with suggested operation

### Success? → Check Next Phase
- Inline working? → Suggest extraction
- Gene built? → Suggest testing
- All tested? → Done!
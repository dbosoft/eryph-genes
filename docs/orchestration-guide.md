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
1. All catlet operations run with `-Verbose`
2. If timeout occurs, extract OperationId from output
3. Use `poll-operation` with eryph-powershell-executor
4. Continue polling until complete

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
- `poll-operation` - Check long-running operation
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

### When Command Times Out

1. Extract OperationId from verbose output
2. Use `poll-operation` with eryph-powershell-executor
3. Continue polling until Status: Completed or Failed
4. Report final status to user

### Common Errors → Response

- `NullReferenceException` → specialist suggests operation type
- `SSH failed` → specialist suggests `setup-egs`
- `Gene not found` → maintainer suggests `build-gene`

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
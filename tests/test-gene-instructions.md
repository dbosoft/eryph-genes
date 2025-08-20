# Testing the Orchestration Test Gene

## Prerequisites
1. Eryph-zero must be installed and running
2. Local genepool path must be resolved (requires admin rights)
3. Gene must be built and copied to local genepool

## Testing Steps

### 1. Build the Gene
```bash
# Install dependencies and build the test gene
pnpm install
turbo build --filter=@dbosoft/test
```

### 2. Copy to Local Genepool
```powershell
# First resolve genepool path (requires admin)
.\Resolve-GenepoolPath.ps1

# Then copy the built gene
xcopy /E /I /Y "genes\test\.packed\*" "{genepool_path}\test"
```

### 3. Deploy Test Catlet
```yaml
# Use tests/test-orchestration-gene.yaml
name: test-orchestration-gene
parent: dbosoft/winsrv2022-standard/starter

variables:
  - name: environment
    value: "test-environment"
  - name: test_message
    value: "Gene extraction and deployment test completed"

fodder:
  - source: gene:dbosoft/guest-services:win-install
  - source: gene:dbosoft/test:orchestration-test
    variables:
      - name: environment
        value: "{{ environment }}"
      - name: test_message
        value: "{{ test_message }}"
```

### 4. Verify Deployment
After catlet starts, use SSH to verify:
```powershell
# Check test directory was created
Test-Path 'C:\OrchestrationTest'

# Verify test files exist
Test-Path 'C:\OrchestrationTest\test-results.txt'
Test-Path 'C:\OrchestrationTest\verification.txt'

# Check content of result files
Get-Content 'C:\OrchestrationTest\test-results.txt'
Get-Content 'C:\OrchestrationTest\verification.txt'
```

## Expected Results
- Test directory `C:\OrchestrationTest` should be created
- `test-results.txt` should contain environment and message variables
- `verification.txt` should contain confirmation text
- Variables should be properly substituted

## Multi-Agent Testing Flow
1. **eryph-specialist**: Creates test catlet YAML
2. **eryph-powershell-executor**: Deploys catlet with variables
3. **egs-executor**: Sets up SSH access and runs verification commands
4. **gene-maintainer**: Interprets any errors and suggests fixes
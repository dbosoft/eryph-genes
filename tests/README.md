# Eryph Test Framework

## Overview
This test framework validates eryph genes using EGS (Eryph Guest Services) for credential-free VM access. It provides **separate testing workflows** for base catlets and fodder genes, each with their own orchestration and validation approach.

## Architecture: Two Distinct Testing Paths

### 🔷 **Base Catlet Testing** (after `pack_build.ps1`)
Tests the packed base OS images to ensure they're properly prepared:
```
build.ps1 → pack_build.ps1 → Test-PackedBaseCatlet.ps1
```

### 🔶 **Fodder Gene Testing** (cross-OS validation)
Tests fodder genes by deploying them on multiple base OS versions:
```
Test-FodderGene.ps1 → Multiple Base OS → Validation
```

## Key Features
- **EGS Integration**: No SSH keys needed - uses Hyper-V integration for secure access
- **Two-Phase Testing**: Host validation (deployment) + In-VM validation (deep checks)
- **Pester Everywhere**: Consistent testing framework on host and inside VMs
- **OS Support**: Windows and Linux catlet testing with PowerShell Core
- **Optimized File Transfer**: Single files via `egs-tool upload-file`, directories via zip+upload
- **Parallel Testing**: Fodder genes can be tested across multiple OS in parallel

## Complete Directory Structure
```
eryph-genes/
│
├── BASE CATLET TESTING
│   ├── Test-PackedBaseCatlet.ps1         # Entry point (orchestrator)
│   ├── Test-PackedBaseCatlet.Tests.ps1   # Host-side Pester tests
│   └── tests/base-catlet/
│       ├── windows/
│       │   ├── Validate-BaseOS.Tests.ps1  # In-VM validation (Windows)
│       │   ├── CloudInit.Analyzers.psm1   # Cloudbase-init log parser
│       │   └── runner.ps1                 # Test runner script
│       └── linux/
│           ├── Validate-BaseOS.Tests.ps1  # In-VM validation (Linux)
│           └── runner.ps1                 # Test runner script
│
├── FODDER GENE TESTING
│   ├── Test-FodderGene.ps1               # Entry point (orchestrator)
│   ├── Test-FodderGene.Tests.ps1         # Host-side Pester tests
│   └── tests/fodder-genes/
│       ├── winget/
│       │   └── Validate-Winget.Tests.ps1  # In-VM validation
│       └── {gene-name}/
│           └── Validate-{Gene}.Tests.ps1  # In-VM validation
│
├── SHARED INFRASTRUCTURE
│   ├── tests/EryphTestHelpers.psm1       # Centralized helper functions
│   ├── tests/windows-egs.yaml            # Windows test catlet template
│   └── tests/linux-egs.yaml              # Linux test catlet template
│
└── LEGACY/REMOVED FILES
    ├── test_packed.ps1                   # Old SSH-based testing (removed)
    ├── tests/Eryph.SSH.psm1              # Old SSH module (removed)  
    ├── Run-FodderGeneTests.ps1           # Legacy batch runner (removed)
    └── Test-BaseCatlet.ps1               # Auto-detecting wrapper (removed)
```

## Quick Start

### 🔷 Testing Base Catlets (after pack_build.ps1)

```powershell
# Run as Administrator (required for egs-tool)

# Test a Windows base catlet
.\Test-PackedBaseCatlet.ps1 -Geneset "dbosoft/winsrv2022-standard/20241216" -GenepoolPath "C:\eryph\genepool" -OsType windows

# Test a Linux base catlet  
.\Test-PackedBaseCatlet.ps1 -Geneset "dbosoft/ubuntu-2404/20241216" -GenepoolPath "C:\eryph\genepool" -OsType linux

# Keep VM for debugging
.\Test-PackedBaseCatlet.ps1 -Geneset "dbosoft/winsrv2022-standard/20241216" -GenepoolPath "C:\eryph\genepool" -OsType windows -KeepVM
```

### 🔶 Testing Fodder Genes (cross-OS validation)

```powershell
# Test winget gene on multiple Windows versions
.\Test-FodderGene.ps1 -Gene "dbosoft/winget" -BaseOS @("dbosoft/winsrv2022-standard", "dbosoft/win11-24h2")

# Test PowerShell gene on Linux
.\Test-FodderGene.ps1 -Gene "dbosoft/powershell" -BaseOS @("dbosoft/ubuntu-2404")

# Test with specific tag and keep VMs for debugging
.\Test-FodderGene.ps1 -Gene "dbosoft/winget" -Tag "latest" -BaseOS @("dbosoft/winsrv2022-standard") -KeepVM
```

## Adding New Tests

### 🔷 Base Catlet Tests
Add tests to `tests/base-catlet/{os}/Validate-BaseOS.Tests.ps1`:

```powershell
Context "My New Validation Category" {
    It "Should check something important" {
        # Your test logic - runs INSIDE the VM
        $result = Invoke-LinuxCommand "some-command"  # Linux
        $result = Get-Service "service-name"          # Windows
        $result | Should -Be $expected
    }
}
```

### 🔶 Fodder Gene Tests
Create test structure in `tests/fodder-genes/{gene-name}/`:

```powershell
# tests/fodder-genes/my-gene/Validate-MyGene.Tests.ps1
Describe "My Gene Validation" {
    Context "Installation Validation" {
        It "Should install correctly" {
            # This runs INSIDE the VM after the gene is deployed
            $installed = Get-Command my-tool -ErrorAction SilentlyContinue
            $installed | Should -Not -BeNullOrEmpty
        }
        
        It "Should be functional" {
            # Test actual functionality
            $result = & my-tool --version
            $result | Should -Match "\d+\.\d+\.\d+"
        }
    }
}
```

**Automatic Test Discovery**: Just create the `Validate-{GeneName}.Tests.ps1` file and it will be automatically picked up!

## Architecture Deep Dive

### 🔷 Base Catlet Testing Flow
1. **Setup**: Copy `.packed` folder contents to local genepool
2. **Deploy**: Create catlet with EGS + starter-food fodder
3. **Validate Host**: Network connectivity, EGS readiness
4. **Copy Tests**: Transfer Pester + validation tests to VM
5. **Run In-VM**: Execute tests inside VM via PowerShell/PowerShell Core
6. **Cleanup**: Remove catlet (unless -KeepVM)

### 🔶 Fodder Gene Testing Flow  
1. **Setup**: For each base OS version:
2. **Deploy**: Create catlet with EGS + PowerShell + the fodder gene
3. **Validate Host**: Network connectivity, EGS readiness  
4. **Copy Tests**: Transfer Pester + gene-specific validation tests
5. **Run In-VM**: Execute gene validation tests inside VM
6. **Aggregate**: Collect results across all base OS versions
7. **Cleanup**: Remove all catlets (unless -KeepVM)

### Two-Phase Testing Pattern
- **Phase A: Host-Side** - Deployment, network, EGS setup (Pester on host)
- **Phase B: In-VM** - Deep validation, functionality tests (Pester in VM)

## Helper Functions (EryphTestHelpers.psm1)

### Core Functions
- `Wait-EGSReady`: Wait for EGS availability
- `Initialize-EGSConnection`: Setup EGS for a VM
- `Invoke-EGSCommand`: Run commands in VM
- `Copy-TestSuiteToVM`: Deploy complete test environment

### File Transfer
- `Copy-FileToVM`: Single file upload via egs-tool
- `Copy-DirectoryToVM`: Directory upload via zip+egs-tool
- `Copy-PesterToVM`: Deploy Pester module

### Log Retrieval
- `Get-CloudbaseInitLog`: Windows cloud-init logs
- `Get-CloudInitLog`: Linux cloud-init logs
- `Get-CloudInitLogs`: OS-agnostic log retrieval

## Test Execution Flow

1. **Setup Phase**
   - Copy gene to local genepool
   - Deploy catlet with EGS fodder
   - Start VM and wait for boot

2. **Host Validation**
   - Check deployment success
   - Verify IP assignment
   - Confirm EGS connectivity

3. **In-VM Validation**
   - Copy Pester + tests to VM
   - Execute validation tests
   - Analyze cloud-init logs
   - Return results

4. **Cleanup**
   - Remove test VM (unless -KeepVM)
   - Clean genepool (if gene was added)

## Troubleshooting

### Common Issues

#### EGS Connection Failed
```powershell
# Manually check EGS status
egs-tool get-status <VmId>

# Re-register VM
egs-tool add-ssh-config <VmId>
egs-tool update-ssh-config
```

#### Tests Not Found in VM
```powershell
# Check files were copied
C:/Windows/System32/OpenSSH/ssh.exe <VmId>.hyper-v.alt -C "ls C:\Tests"
```

#### Cloudbase-init Service Stopped
This is **normal** - the service stops after successful completion.

## Best Practices

1. **Always run as Administrator** - Required for egs-tool
2. **Use -KeepVM for debugging** - Preserves VM for investigation
3. **Check logs on failure** - Cloud-init logs contain valuable info
4. **Test incrementally** - Start with simple validations
5. **Use CloudInit analyzer** - For parsing cloudbase-init errors

## Performance Tips

- **Single files**: Use `egs-tool upload-file` (faster than scp)
- **Directories**: Zip locally, upload, extract (avoids SSH overhead)
- **Parallel operations**: Host tests can run while waiting for VM boot
- **Reuse Pester**: Copy once, run multiple test files

## Future Enhancements

- [ ] Linux base catlet tests
- [ ] Fodder gene test framework
- [ ] Parallel VM testing
- [ ] Test result aggregation
- [ ] CI/CD integration
- [ ] Performance benchmarking
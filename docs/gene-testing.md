# Gene Testing Documentation

## Overview

The eryph-genes repository uses a **standardized test runner pattern** that dramatically reduces boilerplate code in fodder gene tests. Instead of writing 110+ lines of repetitive setup code, each gene test requires only 2-5 lines.

## Standardized Testing Pattern

### 1. Main Test File (Minimal Boilerplate)

For a gene named `{genename}`, create exactly ONE file:
```
tests/fodder-genes/{genename}/Test-{GeneName}.Tests.ps1
```

**Template (2-5 lines only):**
```powershell
# Test-{GeneName}.Tests.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$GeneTag,
    [switch]$KeepVM
)

$runner = Join-Path $PSScriptRoot "..\..\Invoke-FodderGeneTest.ps1"
& $runner -GeneTag $GeneTag -GeneName "{genename}" -KeepVM:$KeepVM
```

**Example for winget gene:**
```powershell
# Test-Winget.Tests.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$GeneTag,
    [switch]$KeepVM
)

$runner = Join-Path $PSScriptRoot "..\..\Invoke-FodderGeneTest.ps1"
& $runner -GeneTag $GeneTag -GeneName "winget" -KeepVM:$KeepVM
```

### 2. Test Matrix Configuration

Create a test matrix file that defines test suites, OS compatibility, and test types:
```
tests/fodder-genes/{genename}/test-matrix.psd1
```

**Structure:**
```powershell
@{
    TestSuites = @(
        @{
            Name = "Basic"
            Description = "Basic functionality testing"
            CatletSpec = "catlets\basic.yaml"
            OSMatrix = @("winsrv2022-standard", "win11-24h2")
            
            # Quick host-based tests (run from host via SSH)
            HostTests = [ordered]@{
                "command --version" = "regex_pattern"
                "Test-Path C:\ExpectedFile" = "True"
            }
            
            # Complex in-VM tests (Pester files copied and run inside VM)
            InVMTests = @(
                "validation\Validate-Basic.Tests.ps1"
                "validation\Validate-Advanced.Tests.ps1"
            )
        }
    )
    
    DefaultTimeout = 300
    StopOnFailure = $false
}
```

### 3. Catlet Specifications

Create catlet YAML files referenced by the test matrix:
```
tests/fodder-genes/{genename}/catlets/{suite}.yaml
```

**Example:**
```yaml
# catlets/basic.yaml
name: test-{genename}-basic
parent: dbosoft/{{ os_version }}/starter

fodder:
  - source: gene:dbosoft/guest-services:win-install
  - source: gene:dbosoft/{genename}:{{ gene_tag }}

variables:
  # Test-specific variables if needed
  test_param: "value"
```

### 4. Validation Tests (Pester Files)

Create Pester test files for in-VM validation:
```
tests/fodder-genes/{genename}/validation/Validate-{TestName}.Tests.ps1
```

**Structure:**
```powershell
Describe "{GeneName} {TestName} Validation" {
    Context "Installation Verification" {
        It "Should have tool installed" {
            $tool = Get-Command "tool-name" -ErrorAction SilentlyContinue
            $tool | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Functionality Tests" {
        It "Should work correctly" {
            $result = & tool-name --test
            $result | Should -Match "expected"
        }
    }
}
```

## Complete Example: Winget Gene

### Directory Structure
```
tests/fodder-genes/winget/
├── Test-Winget.Tests.ps1           # Main test file (14 lines)
├── test-matrix.psd1                # Test configuration
├── catlets/
│   ├── minimal.yaml               # Basic test catlet
│   └── enterprise.yaml            # Advanced test catlet
└── validation/
    ├── common/
    │   └── Validate-Basic.Tests.ps1
    ├── scenarios/
    │   └── Validate-Enterprise.Tests.ps1
    └── compatibility/
        └── Validate-Compatibility.Tests.ps1
```

### Main Test File (14 lines vs old 110+ lines)
```powershell
# Test-Winget.Tests.ps1
# Main orchestrator for winget fodder gene testing
# Uses standardized test runner to minimize boilerplate

param(
    [Parameter(Mandatory=$true)]
    [string]$GeneTag,  # Full gene tag like "dbosoft/winget/latest"
    
    [switch]$KeepVM    # Keep VMs after testing for debugging
)

# Use the standardized fodder gene test runner
$runner = Join-Path $PSScriptRoot "..\..\Invoke-FodderGeneTest.ps1"
& $runner -GeneTag $GeneTag -GeneName "winget" -KeepVM:$KeepVM
```

### Test Matrix
```powershell
# test-matrix.psd1
@{
    TestSuites = @(
        @{
            Name = "Minimal"
            Description = "Basic winget installation without dependencies"
            CatletSpec = "catlets\minimal.yaml"
            OSMatrix = @("winsrv2022-standard", "win11-24h2")
            
            # Quick host-based tests
            HostTests = [ordered]@{
                "winget --version" = "v\d+\.\d+\.\d+"
                "winget list --accept-source-agreements" = ".*"
            }
            
            InVMTests = @()  # No complex tests needed
        }
        
        @{
            Name = "Enterprise" 
            Description = "Winget with enterprise dependencies"
            CatletSpec = "catlets\enterprise.yaml"
            OSMatrix = @("winsrv2022-standard")
            
            HostTests = [ordered]@{
                "winget --version" = "v\d+\.\d+\.\d+"
                "choco --version" = "\d+\.\d+\.\d+"
            }
            
            InVMTests = @(
                "common\Validate-Basic.Tests.ps1"
                "scenarios\Validate-Enterprise.Tests.ps1"
            )
        }
    )
}
```

## Test Types Explained

### Host Tests (HostTests)
- **Quick commands** run from host via SSH
- **Key-value pairs**: `"command" = "regex_pattern"`
- **Perfect for**: Version checks, simple file existence, basic functionality
- **Automatic validation**: Command output must match regex pattern

```powershell
HostTests = [ordered]@{
    "winget --version" = "v\d+\.\d+\.\d+"        # Version check
    "Test-Path C:\Program Files\app" = "True"     # File existence  
    "Get-Service AppService" = "Running"          # Service status
}
```

### In-VM Tests (InVMTests)
- **Complex Pester tests** copied to VM and executed inside
- **Perfect for**: Detailed functionality, file content validation, complex scenarios
- **Full Pester support**: Multiple contexts, test cases, detailed assertions

```powershell
InVMTests = @(
    "validation\Validate-Installation.Tests.ps1"
    "validation\Validate-Configuration.Tests.ps1"
)
```

## Advanced Features

### Custom Validation Hooks

#### Option 1: Custom Validation File
Create `Custom-{GeneName}-Validation.ps1` in your test directory:

```powershell
# Custom-Winget-Validation.ps1
param($VmId, $TestResult)

# Custom logic here
$customCheck = Invoke-Command -VMId $VmId -ScriptBlock {
    # Special validation logic
}

if (-not $customCheck) {
    throw "Custom validation failed"
}
```

#### Option 2: Scriptblock Parameters
```powershell
# In Test-Gene.Tests.ps1 - pass custom hooks to runner
$customValidation = {
    param($VmId, $TestResult)
    # Custom validation logic
}

$beforeAllTests = {
    # Setup logic before any tests
}

$afterAllTests = {
    # Cleanup logic after all tests
}

& $runner -GeneTag $GeneTag -GeneName "genename" -KeepVM:$KeepVM `
    -CustomValidation $customValidation `
    -BeforeAllTests $beforeAllTests `
    -AfterAllTests $afterAllTests
```

### Placeholder Substitution

The test runner automatically substitutes placeholders in catlet specs:
- `{{ os_version }}` → Current OS from matrix (e.g., "winsrv2022-standard")
- `{{ gene_tag }}` → Current gene tag being tested (e.g., "latest")

**Catlet spec example:**
```yaml
name: test-{{ gene_name }}-{{ os_version }}
parent: dbosoft/{{ os_version }}/starter

fodder:
  - source: gene:dbosoft/guest-services:win-install
  - source: gene:dbosoft/myapp:{{ gene_tag }}
```

## What to Test

### Focus on EFFECTS, not implementation
- ✅ **Files/directories created** by the gene
- ✅ **Services installed and running**
- ✅ **Tools functioning correctly**
- ✅ **Variable substitution results**
- ✅ **Cross-OS compatibility**
- ❌ NOT the YAML structure itself
- ❌ NOT the deployment process

### Common Test Patterns

#### Host Tests (Quick validation)
```powershell
HostTests = [ordered]@{
    # Tool installation
    "Get-Command tool-name" = ".*tool-name.*"
    
    # Version verification
    "tool --version" = "v?\d+\.\d+\.\d+"
    
    # File existence
    "Test-Path 'C:\Program Files\App'" = "True"
    
    # Service status
    "(Get-Service ServiceName).Status" = "Running"
    
    # Registry verification
    "Get-ItemProperty 'HKLM:\Software\App' -Name Version" = "\d+\.\d+"
}
```

#### In-VM Tests (Detailed validation)
```powershell
# validation/Validate-Installation.Tests.ps1
Describe "Tool Installation" {
    Context "Files and Directories" {
        It "Should create program directory" {
            Test-Path "C:\Program Files\Tool" | Should -Be $true
        }
        
        It "Should create config file" {
            Test-Path "C:\ProgramData\Tool\config.json" | Should -Be $true
        }
    }
    
    Context "Functionality" {
        It "Should run without errors" {
            { & tool-name --test } | Should -Not -Throw
        }
        
        It "Should produce expected output" {
            $output = & tool-name --info
            $output | Should -Match "Tool version"
        }
    }
}
```

## Execution

### Running Tests
```powershell
# Run specific gene test
.\tests\fodder-genes\winget\Test-Winget.Tests.ps1 -GeneTag "dbosoft/winget/latest"

# Keep VM for debugging
.\tests\fodder-genes\winget\Test-Winget.Tests.ps1 -GeneTag "dbosoft/winget/latest" -KeepVM
```

### What the Framework Handles
The `Invoke-FodderGeneTest.ps1` runner automatically:
- ✅ **Loads test matrix** configuration
- ✅ **Creates test catlets** dynamically for each OS
- ✅ **Deploys with gene** and dependencies
- ✅ **Sets up EGS/SSH access** to VMs
- ✅ **Executes host tests** via SSH
- ✅ **Copies and runs Pester tests** inside VMs
- ✅ **Collects and validates** all results
- ✅ **Handles cleanup** (unless -KeepVM specified)
- ✅ **Provides detailed** error reporting

## Migration from Old Pattern

### OLD (110+ lines of boilerplate):
```powershell
# Every test file had all this repetitive code:
BeforeAll {
    # 20+ lines of setup
}

Describe "Gene Tests" {
    # 80+ lines of test matrix loading
    # Gene tag parsing
    # Test case creation
    # Path resolution
    # Error handling
}

AfterAll {
    # 10+ lines of cleanup
}
```

### NEW (2-5 lines total):
```powershell
param([string]$GeneTag, [switch]$KeepVM)
$runner = Join-Path $PSScriptRoot "..\..\Invoke-FodderGeneTest.ps1"
& $runner -GeneTag $GeneTag -GeneName "genename" -KeepVM:$KeepVM
```

## Best Practices

1. **Start simple** - Use host tests for basic validation, add in-VM tests only when needed
2. **Use clear test names** - "Should install winget" not "Test 1"
3. **Group by functionality** - Use Context blocks to organize related tests
4. **Test cross-platform** - Include multiple OS versions in your matrix
5. **Use regex patterns** - Host test patterns should be specific but flexible
6. **Keep catlets minimal** - Only include what's needed for the specific test
7. **Document test suites** - Use descriptive names and descriptions in test matrix

## Framework Components

### Core Files
- `tests/Invoke-FodderGeneTest.ps1` - Standardized test runner
- `tests/EryphTestHelpers.psm1` - Shared helper functions
- Each gene has minimal `Test-{Gene}.Tests.ps1` file

### Convention-Based Discovery
- Test directory: `tests/fodder-genes/{genename}/`
- Matrix config: `test-matrix.psd1`
- Catlet specs: `catlets/*.yaml`
- Validation tests: `validation/*.Tests.ps1`
- Custom validation: `Custom-{GeneName}-Validation.ps1` (optional)

The standardized pattern reduces maintenance overhead, ensures consistency across all gene tests, and makes it easy to add new tests by following established conventions.
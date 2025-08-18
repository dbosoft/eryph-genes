# Winget Fodder Gene Tests

This directory contains realistic tests for the winget fodder gene across different Windows versions.

## Test Structure

### Test Matrix (`test-matrix.psd1`)
Defines test suites with realistic expectations:

1. **WingetBasicFunctionality** - Tests basic winget installation and availability
2. **WingetSourceManagement** - Tests source management capabilities 
3. **WingetPackageSearch** - Tests package search and information retrieval
4. **WingetCompatibilityCheck** - Validates OS compatibility and limitations
5. **WingetAdvancedFeatures** - Tests advanced features (Windows 11 only)

### OS Coverage and Expectations

#### Windows Server 2019 (`winsrv2019-standard`)
- **Expected**: Limited or no winget support
- **Tests**: Compatibility checks only
- **Behavior**: winget may not be available or may have limited functionality
- **Validation**: Accepts both "not available" and "surprisingly working" outcomes

#### Windows Server 2022 (`winsrv2022-standard`)
- **Expected**: Full winget support
- **Tests**: Basic functionality, source management, package search
- **Behavior**: Should install and work correctly
- **Features**: search, show, source management

#### Windows 10 20H2 Enterprise (`win10-20h2-enterprise`)
- **Expected**: Full winget support
- **Tests**: Basic functionality, source management, package search
- **Behavior**: Should install and work correctly
- **Features**: search, show, basic source management

#### Windows 11 24H2 Enterprise (`win11-24h2-enterprise`)
- **Expected**: Complete winget support with all features
- **Tests**: All test suites including advanced features
- **Behavior**: Should install and work correctly with full feature set
- **Features**: All winget capabilities including export/import, validation

## Test Categories

### Host Tests (SSH-based)
- Execute winget commands remotely via SSH
- Test basic functionality without complex setup
- Validate command availability and basic operations
- Check version information and source listings

### Custom Validation
- OS-specific expectation handling
- Realistic failure acceptance (e.g., Server 2019 limitations)
- Feature availability verification
- Error pattern recognition

## Catlet Specifications

All catlet specs include:
- Guest services for SSH access
- The winget gene being tested
- Minimal additional setup (temp directories for advanced tests)

Template variables:
- `{{OS_VERSION}}` - Replaced with target OS version
- `{{GENE_TAG}}` - Replaced with gene tag being tested

## Running Tests

Use the standardized test runner:

```powershell
# Test basic functionality across all OS versions
.\Test-Winget.Tests.ps1 -GeneTag "dbosoft/winget/latest"

# Test specific version
.\Test-Winget.Tests.ps1 -GeneTag "dbosoft/winget/v1.0" -KeepVM
```

## Expected Outcomes

### Success Scenarios
- **Server 2022, Win10, Win11**: All basic and source management tests pass
- **Win11**: All tests including advanced features pass
- **Server 2019**: Compatibility tests pass with appropriate "not supported" messages

### Acceptable Outcomes
- **Server 2019**: winget installation fails or has limited functionality
- **All OS**: Some advanced features may not work in test environment
- **Export/Import**: May succeed without content if no packages installed

### Failure Scenarios
- Gene installation fails on supported OS versions
- Basic winget commands don't work on Win10/Win11/Server2022
- Network connectivity issues preventing package searches

## Implementation Notes

### Winget Gene Capabilities
The winget gene is sophisticated and handles:
- OS build detection and compatibility checking
- Automatic dependency installation (VCLibs, XAML)
- PATH configuration for pre-installed winget
- Graceful fallback for unsupported OS versions

### Test Design Principles
1. **Realistic Expectations**: Tests reflect actual winget behavior per OS
2. **Graceful Degradation**: Accepts expected limitations gracefully
3. **Network Independence**: Basic tests don't require package installation
4. **Version Awareness**: Different expectations per Windows version
5. **Error Tolerance**: Distinguishes between expected and unexpected failures

### Maintenance Notes
- Update OS expectations as winget support evolves
- Add new Windows versions to matrix as they become available
- Monitor winget feature changes and update advanced tests accordingly
- Keep compatibility checks current with actual OS support matrix
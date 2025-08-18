# Eryph Specialist Debugging - Test Orchestration YAML Fix

## Schema Analysis Performed
- Read catlet-schema-v1.0.json lines 386-535
- Identified fodder oneOf structure with 4 types:
  1. fodder_reference (requires: source)
  2. fodder_cloudinit (requires: name, content, type: cloud-config)
  3. fodder_other (requires: name, content, type: shellscript/etc)
  4. fodder_remove (requires: name, remove: true)

## Error Analysis
- Validation error: "At $.configuration.fodder[1], the name or source must be specified"
- Second fodder item has `content: |` with PowerShell (#ps1_sysnative)
- Missing required `name` field for inline fodder
- Missing required `type` field (should be "shellscript")

## Schema Verification
- Variables format: ✓ Array-of-objects (lines 4-10)
- First fodder: ✓ fodder_reference with valid source
- Second fodder: ❌ Missing name and type for inline content

## Fix Applied
- Added `name: orchestration-test-script` 
- Added `type: shellscript`
- Maintained exact content indentation (4 spaces from content:)
- Verified all PowerShell here-strings maintain proper indentation

## Validation Checks Performed
- ✓ Schema compliance for both fodder items
- ✓ All content after | is indented minimum 2 spaces from content: position
- ✓ PowerShell here-strings (@" "@) maintain indentation
- ✓ Variables remain in array-of-objects format
- ✓ No tabs, only spaces
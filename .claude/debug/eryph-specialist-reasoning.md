# Eryph Specialist Reasoning - SAProuter Build Working Catlet

## STEP 1: Schema Reading (MANDATORY)
✓ Read catlet-schema-v1.0.json lines 1-618
✓ Verified variables format: Array-of-objects (lines 140-147, 565-616)
✓ Confirmed fodder structure: name + content for inline (lines 478-535)
✓ No `source: inline` needed for inline fodder

## STEP 2: Property Verification
✓ Variables: Array format with name/value objects (NOT key-value pairs)
✓ Fodder: Inline fodder needs name + type + content
✓ Parent: Uses format without `gene:` prefix
✓ Memory/CPU: Simple number format allowed

## STEP 3: SAProuter Requirements Analysis
- User requested "working SAProuter build scripts incrementally"
- Reference: T:\saprouter\saprouter-build\saprouter-build\ scripts (6 scripts)
- PSE relative path corrections needed (SECUDIR relative paths)
- Memory: 4GB, CPU: 2 (SAProuter needs more resources)
- No Unicode characters - ASCII only
- Keep EGS gene for SSH access

## STEP 4: SAProuter Build Scripts Design
Based on typical SAP requirements and build processes:

1. **Install-SAProuter.ps1** - Downloads and installs SAProuter binary
2. **Configure-SAProuter.ps1** - Sets up configuration files and directories
3. **Setup-PSE.ps1** - Creates PSE (Personal Security Environment) with relative paths
4. **Configure-Routes.ps1** - Sets up routing table
5. **Install-Service.ps1** - Installs as Windows service
6. **Test-SAProuter.ps1** - Validates installation and connectivity

## STEP 5: YAML Generation Strategy
- Parent: dbosoft/winsrv2022-standard/starter (Windows base)
- EGS: gene:dbosoft/guest-services:win-install (automatic key mode)
- Memory: 4096 (4GB), CPU: 2
- All scripts as write_files in cloud-config
- PSE corrections: Use relative paths with SECUDIR environment variable
- ASCII only content (no Unicode characters)

## STEP 6: Validation Checklist
✓ Variables in array-of-objects format
✓ Content after | properly indented (minimum 2 spaces from content:)
✓ PowerShell here-strings maintain indentation
✓ No tabs, only spaces
✓ All fodder items have required name + type + content
✓ No Unicode characters used
# Eryph Error Patterns Guide

## For eryph-specialist Agent: YAML and Fodder Error Interpretation

This document helps the specialist interpret YAML and fodder-related errors only.

## YAML Structure Errors

### Invalid YAML Syntax
**Error Signs:** Parser errors, unexpected character, mapping errors

**Common Causes:**
1. **Incorrect indentation** - Not using consistent 2-space indents
2. **Tab characters** - Mixed tabs and spaces
3. **Missing colons** - Key without `: value`
4. **Invalid multiline** - Content not indented after `|`

**Fix:** Review YAML structure, ensure proper indentation relative to pipe character

### Variable Syntax Errors

#### Variable Not Substituted
**Symptom:** `{{ variable }}` appears literally in VM logs

**Causes:**
1. Variable not declared in `variables:` section
2. Typo in variable name
3. Using `$variable` instead of `{{ variable }}`

**Fix:** Ensure variable is declared and uses correct `{{ name }}` syntax

#### Invalid Variable Type
**Error:** Type mismatch in variable usage

**Fix:** Check variable type matches usage (string, boolean, number)

## Fodder Content Errors

### Cloud-Config Parse Errors (Linux)
**Error:** "Failed to parse cloud-config"

**Common Issues:**
1. Invalid YAML inside `content: |` block
2. Unsupported cloud-init directive
3. Incorrect list/dict structure

**Fix:** Validate inner YAML structure, check cloud-init documentation

### Cloudbase-Init Errors (Windows)
**Error:** "Cloudbase-init failed to process user data"

**Common Issues:**
1. Using unsupported directives (packages, ssh_authorized_keys)
2. Invalid PowerShell syntax in shellscript
3. Missing `#ps1_sysnative` header

**Fix:** Use only supported directives (write_files, users, runcmd, etc.) or switch to shellscript type

### Package Not Available in runcmd
**Symptom:** Command not found after package installation

**Cause:** Package installed via `packages:` not immediately available

**Fix in fodder:**
```yaml
runcmd:
  - sleep 5  # Wait for package installation
  - which nginx || echo "Package not ready"
```

### Service Not Ready
**Symptom:** Connection refused when testing service

**Fix in fodder:** Add readiness check:
```yaml
runcmd:
  - systemctl start nginx
  - while ! nc -z localhost 80; do sleep 1; done
```

## Gene Reference Errors

### Invalid Gene Reference Format
**Error:** "Invalid source format"

**Correct formats:**
- `source: gene:org/geneset:fodder-name` (implicit latest)
- `source: gene:org/geneset/tag:fodder-name` (explicit tag)

**Wrong formats:**
- `source: gene:org/geneset:tag:fodder` (tag in wrong position)
- `source: org/geneset` (missing gene: prefix)

### Gene Not Found
**Error:** "Gene 'org/geneset:tag' not found"

**Possible causes:**
1. Gene not in local genepool yet
2. Typo in gene name
3. Tag doesn't exist

**Fix:** Verify gene name, suggest `build-gene` and `copy-to-genepool` operations

## Parent Inheritance Errors

### Invalid Parent Format
**Error:** "Parent must be in format org/geneset/tag"

**Fix:** Use full three-part format for parent (no `gene:` prefix for parent!)

### Parent Not Found
**Error:** "Parent catlet gene not found"

**Fix:** Check if parent gene exists in genepool, verify spelling

## Error Response Template

When main Claude reports a YAML/fodder error:

```yaml
error_analysis: "Cloud-config has unsupported 'packages' directive on Windows"
artifact_fix: "Change to shellscript type for package installation"
suggested_operation: "deploy-catlet after fixing YAML"
explanation: "Windows cloudbase-init only supports 7 directives"
```
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

## SSH Connection Failures

### Critical Understanding: Authentication vs. Network Issues

**Key Concept:** SSH connection failures are almost NEVER network issues in eryph. They indicate authentication problems or cloud-init failures.

### Error Pattern Analysis

| Error Message | Real Meaning | Root Cause | Correct Response |
|---------------|-------------|-------------|------------------|
| "Connection timeout" | No authentication mechanism exists | EGS not configured due to cloud-init failure | Check if earlier fodder failed, blocking EGS |
| "Permission denied" | Authentication exists but wrong credentials | EGS misconfigured or manual keys wrong | Verify EGS setup process |  
| "Connection refused" | SSH service not running | VM boot failure or SSH disabled | Check VM status, not network |
| "No route to host" | Network connectivity issue | Actual network problem (rare) | Check VM network config |

### SSH Connection Debugging Flow

1. **"Connection timeout" (Most Common)**
   - **DO NOT** attempt IP-based SSH - there's no authentication configured
   - **DO NOT** debug network connectivity first
   - **DO** check if cloud-init failed and prevented EGS configuration
   - **DO** test with minimal catlet (base + EGS only) to isolate the issue

2. **"Permission denied"**
   - EGS was configured but something is wrong with credentials
   - Check EGS setup process was successful
   - Verify no manual SSH configuration conflicts

3. **Connection Works but No Command Output**
   - SSH connection established but commands don't execute properly
   - May indicate partial cloud-init failure or system instability
   - Test with simple commands first (echo, pwd)

### Common Mistakes to Avoid

#### Mistake: Assuming Network Issues
**Wrong approach:** "Let me try SSH via IP address"
**Correct understanding:** Catlets have NO SSH access by default - EGS provides the ONLY automatic authentication

#### Mistake: Debugging Symptoms Not Causes
**Wrong approach:** "Why won't SSH connect?"
**Correct understanding:** SSH isn't broken - cloud-init probably failed, preventing EGS from being configured

#### Mistake: Complex Network Debugging
**Wrong approach:** Testing firewalls, routes, port connectivity
**Correct understanding:** If EGS setup-egs succeeded, network is fine - problem is authentication

### Integration with Multi-Agent System

#### For eryph-specialist Agent
When receiving SSH connection failures as error feedback:
- **Interpret as cloud-init/fodder problem**, not network issue
- **Suggest simpler fodder configuration** to isolate the failing component
- **Recommend incremental testing** starting with base + EGS only

#### For Main Claude
When SSH timeouts occur:
- **Return to creation agent** for fodder simplification
- **DO NOT** attempt manual SSH debugging via IP
- **DO NOT** suggest network configuration changes
- **DO** recognize this as a CONTENT error requiring creation agent input

### Error Prevention

To prevent SSH connection failures:
1. **Test with minimal configuration first** (base + EGS only)
2. **Add fodder incrementally** and test each addition
3. **Avoid high-risk patterns** in cloud-init (complex scripts, multiple repos)
4. **Follow proven fodder patterns** from working examples

## Error Response Template

When main Claude reports a YAML/fodder error:

```yaml
error_analysis: "Cloud-config has unsupported 'packages' directive on Windows"
artifact_fix: "Change to shellscript type for package installation"
suggested_operation: "deploy-catlet after fixing YAML"
explanation: "Windows cloudbase-init only supports 7 directives"
```
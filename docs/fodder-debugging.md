# Fodder Debugging Guide

This guide provides systematic debugging methodology for fodder development failures, with emphasis on preventing cascade failures that break essential services like EGS.

## Critical Concept: Fodder Execution Chain

**Fodder items execute sequentially during cloud-init as a single process chain.** A failure in any fodder item can prevent subsequent items from executing properly or cause them to run in a corrupted environment.

### Key Understanding
- All fodder items are combined into a single cloud-init configuration
- Items run in the order they appear in the YAML
- If one fails, subsequent items may not execute at all
- EGS configuration is just another fodder item - vulnerable to earlier failures
- Complex shell scripts are high-risk failure points

## Common Failure Pattern: EGS Not Working

### Symptoms
- SSH connection timeout when trying to access catlet
- `egs-tool get-status` returns "unknown" 
- Cannot access VM for debugging even though it appears "Running"

### Root Cause Analysis
**Most common cause:** Earlier fodder item failed during cloud-init, preventing EGS from being properly configured.

**Not the cause:** Network connectivity issues, firewall blocks, or EGS service problems

### Solution Pattern
1. Strip back to absolute minimum: base + EGS only
2. Verify SSH connectivity works
3. Add one fodder item at a time
4. Test after each addition
5. When failure occurs, you've identified the problematic fodder

## Debug Methodology

### Phase 1: Establish Baseline (ALWAYS START HERE)

Create minimal test catlet:
```yaml
name: debug-connectivity-test
parent: dbosoft/ubuntu-24.04/starter  # or appropriate base

fodder:
  - source: gene:dbosoft/guest-services:linux-install  # or win-install
```

**Test Requirements:**
- Deploy and start catlet
- Setup EGS access
- Verify SSH connectivity works
- **Only proceed if this succeeds**

### Phase 2: Incremental Addition

Add ONE fodder item at a time to your baseline:
```yaml
name: debug-increment-test
parent: dbosoft/ubuntu-24.04/starter

fodder:
  - source: gene:dbosoft/guest-services:linux-install
  # Add your next fodder item here - only ONE at a time
  - name: test-item-1
    type: cloud-config
    content:
      # Your test configuration
```

**After each addition:**
1. Deploy fresh catlet
2. Test EGS connectivity
3. If it fails, you've found the problematic fodder
4. If it succeeds, add the next item

### Phase 3: Isolation and Fix

When you identify the failing fodder:
1. **Simplify the configuration** - Remove complex operations
2. **Split into smaller pieces** - Break complex shell scripts into steps
3. **Add error handling** - Include logging and validation
4. **Test each piece separately** - Ensure each part works before combining

## High-Risk Fodder Patterns

### Red Flags (High Failure Probability)
- **Multiple package repository additions** - Each repo can fail differently
- **Complex shell scripts (>50 lines)** - More code = more failure points  
- **systemctl daemon-reload or service modifications** - Can break system state
- **Downloading external content** - Network failures, missing files
- **Kernel module modifications** - Requires reboot, can hang system
- **Multiple runcmd items** - Each can fail independently

### Safe Patterns
- **Single package installations** - Well-tested, predictable
- **Simple file writes** - Usually work or fail quickly
- **Basic system configuration** - Hostname, users, etc.
- **Proven gene references** - Tested configurations

## SSH Connection Failure Interpretation

### Error Pattern Analysis

| Error Message | Actual Meaning | Debug Action |
|---------------|----------------|--------------|
| "Connection timeout" | No authentication mechanism configured | Check if EGS was configured successfully |
| "Permission denied" | Authentication exists but credentials wrong | Check EGS setup or manual key config |
| "Connection refused" | SSH service not running | Check if VM actually booted properly |
| "No route to host" | Network connectivity issue | Check VM status and network config |

**Critical Understanding:** "Connection timeout" is NOT a network issue - it means there's no way to authenticate. In eryph, this usually means EGS wasn't configured.

## Common Mistakes to Avoid

### 1. Assuming IP-based SSH Works
**Mistake:** Trying to SSH directly to VM IP address
**Reality:** Catlets have NO SSH access by default - EGS provides the ONLY automatic authentication
**Solution:** Always use EGS-based SSH access

### 2. Debugging Symptoms Instead of Causes  
**Mistake:** Focusing on "why won't SSH connect"
**Reality:** SSH isn't the problem - cloud-init failure is
**Solution:** Check if earlier fodder items failed first

### 3. Complex Initial Configurations
**Mistake:** Creating elaborate fodder configurations on first try
**Reality:** Complex configurations have exponential failure probability
**Solution:** Always start minimal and add incrementally

### 4. Ignoring Cloud-Init Logs
**Mistake:** Not checking what actually failed during initialization
**Reality:** Cloud-init logs contain specific failure information
**Solution:** Access logs via VM console or other catlets to debug

## Recovery Strategies

### When EGS Fails Completely
1. **Create new test catlet** with minimal configuration
2. **Use VM console access** if available to check cloud-init logs
3. **Deploy diagnostic catlet** to same network for investigation
4. **Start over with proven baseline** rather than trying to fix

### When Partial Configuration Works
1. **Identify the last working state** - What was the last fodder item that succeeded?
2. **Split the failing item** - Break complex operations into smaller pieces
3. **Add logging and validation** - Make failures more visible
4. **Test each piece separately** - Isolate the actual problem

### When Everything Seems to Fail
1. **Check base parent compatibility** - Is the base image appropriate?
2. **Verify gene dependencies** - Are referenced genes available?  
3. **Test with known-good configurations** - Use examples from repository
4. **Consider resource constraints** - Is the VM adequately sized?

## Best Practices for Reliable Fodder

### Development Pattern
1. **Always start with connectivity test** (base + EGS only)
2. **Add functionality incrementally** (one fodder item at a time)
3. **Test after each addition** (full deploy-start-EGS-SSH cycle)
4. **Document what works** (save working configurations)
5. **Keep successful patterns** (reuse proven approaches)

### Configuration Guidelines
- **Prefer simple over complex** - Multiple simple fodder items beat one complex one
- **Include error handling** - Add logging and validation to custom scripts
- **Use proven patterns** - Reference existing successful configurations
- **Avoid bleeding edge** - Use stable, well-tested packages and approaches
- **Plan for failure** - Design configurations that fail fast and clearly

### Testing Requirements
- **Test with fresh deployment** every time - Don't reuse VMs
- **Verify complete functionality** - Not just "it starts"
- **Test edge cases** - What happens when things go wrong?
- **Document failure modes** - Keep track of what doesn't work

## Integration with Multi-Agent System

When using the eryph multi-agent system, this debugging methodology applies:

### eryph-specialist Agent
- Should warn when creating high-risk fodder patterns
- Should suggest incremental testing approach for complex configurations
- Should recommend splitting complex requirements into phases

### Main Claude Orchestration
- Should enforce incremental testing pattern for new configurations
- Should recognize SSH timeout as likely cloud-init failure, not network issue
- Should return to creation agent when content errors occur, not try IP-based debugging

### Execution Agents
- PowerShell/EGS executors should provide raw output for proper interpretation
- Should not attempt to interpret cloud-init related failures
- Should escalate systematic connectivity failures to Main Claude

This debugging guide prevents the cascade failure pattern that breaks essential services and provides clear methodology for developing reliable fodder configurations.
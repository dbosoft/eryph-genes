# Eryph Error Patterns

How to interpret errors from the eryph MCP tools and from provisioning. Tools are described in
[tooling.md](tooling.md); the step-by-step debugging method is in
[fodder-debugging.md](fodder-debugging.md).

## Error categories (MCP)

Every MCP tool error starts with a category:

| Prefix | Meaning | Action |
|---|---|---|
| `[content error]` | The catlet/fodder definition is wrong | Fix the YAML, re-run `validate_catlet` |
| `[state error]` | System state blocks the operation (e.g. exists, not found, running/stopped) | Change state (remove, start/stop, ...), then retry |
| `[transient error]` | Temporary failure | Retry |

Always run `validate_catlet` before `deploy_catlet`; it catches all content errors below. The bundled
JSON schema (`docs/catlet-schema-v1.0.json`) is stricter than eryph and is not authoritative.

## Validation errors (verified, eryph-zero 0.5.1)

| Message (excerpt) | Cause | Fix |
|---|---|---|
| `$.name: The Name is required.` | No `name` in the catlet (PowerShell cmdlets; the MCP tools default it to `catlet`) | Add `name:` |
| `Property 'foo' not found on type '...CatletConfig'` + "Make sure to use snake case for names, e.g. 'network_adapters'" | Unknown or misspelled property | Use a valid property name (see [eryph-knowledge.md](eryph-knowledge.md)) |
| Same error for `file_name` | `file_name` is not a property; the snake-case hint is misleading here | Use `filename` (matching is case-insensitive, `fileName` also works) |
| `Expected 'SequenceStart', got 'MappingStart'` (at `variables`) | `variables` written as a key/value map | Use a list: `- name: x` / `value: y` |
| `The gene identifier is malformed. It must be gene:geneset:genename.` | Fodder `source:` without fodder name, e.g. `gene:dbosoft/starter-food` | `gene:org/geneset[/tag]:fodder-name` |
| `Could not resolve the gene set tag 'org/geneset/tag'. The gene set ... is not available in local or remote gene pools.` | Typo, wrong tag, or a locally built gene not yet copied to the local genepool | Check name/tag against `genes/dbosoft/`; for unpublished genes build and copy to the local genepool (gene-maintainer) |

Other reference rules:
- `parent:` has no `gene:` prefix (`parent: dbosoft/ubuntu-24.04/starter`); `source:` always has it.
- An omitted tag resolves to `latest`.

Things that validate but still do not work:
- Jinja (`{% if %}`, `## template: jinja`) - not evaluated by eryph or by egs on Windows. Only
  `{{ var }}` is substituted.
- Linux-only cloud-config keys (`packages`, `apt`, `snap`) on Windows - accepted and ignored.
- Random passwords on Windows - skipped by egs; set an explicit password.

## Runtime / provisioning patterns

### Provisioning never completes

`wait_for_provisioning` times out, or `catlet_exec` cannot reach the guest.

- Usually a fodder problem, not a network problem. Read `get_provisioning_log` first.
- Linux: an earlier failing module or script can stop later fodder. Check `cloud-init status --long`,
  `/var/log/cloud-init.log`, `/var/log/cloud-init-output.log`.
- Reduce the catlet to parent only, confirm it provisions, then add fodder back one entry at a time.

### Windows: a script failed but provisioning finished

On Windows, a non-zero exit code is logged and the **next script still runs**, so provisioning can
report completion while one step failed. Check:
1. `C:\ProgramData\eryph\provisioning\state.json` - `completedStages` should contain Local, Network,
   Config, Final.
2. `C:\ProgramData\eryph\provisioning\logs\<order>-<filename>.log` - per-script output and exit code.
3. `C:\ProgramData\eryph\guest-services\logs\agent.log` - module and reboot events.

Reboot exit codes: `1001` (reboot, continue), `1003` (reboot, re-run script). `1002` is not supported.

### Windows: script silently not run

A script that cannot be classified is skipped with a warning in `agent.log` (e.g. a `.sh` filename
or a `#!/bin/bash` shebang). Use `filename: name.ps1` or a `#ps1_sysnative` header.

### Variable not substituted

`{{ name }}` appears literally in the guest: the variable is not declared in the scope where it is
used (catlet `variables`, fodder gene `variables`, or `variables` on the `source:` reference), or the
name is misspelled. `$name` is never substituted in YAML files.

### catlet_exec hangs

The exec channel does not close stdin (eryph-org/guest-services#68). Commands that read stdin can
hang - redirect it (`< /dev/null` on Linux) or use non-interactive flags. On Windows the shell is
PowerShell: `sc` and `type` are aliases, use `sc.exe` and `Get-Content`.

## PowerShell test scripts

The repo's test scripts (`Test-PackedBaseCatlet.ps1`, `Test-FodderGene.ps1`) use the eryph cmdlets.

| Symptom | Cause | Fix |
|---|---|---|
| `NullReferenceException` / "Der Objektverweis wurde nicht auf eine Objektinstanz festgelegt" from `New-Catlet`/`Test-Catlet` | YAML with variables piped without `-SkipVariablesPrompt` (no console to prompt) | Add `-SkipVariablesPrompt` and pass values with `-Variables` |

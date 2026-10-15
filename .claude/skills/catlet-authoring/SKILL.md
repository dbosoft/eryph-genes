---
name: catlet-authoring
description: Write and debug eryph catlet YAML and inline fodder (cloud-config / shellscript) for Linux and Windows catlets, test it with the eryph MCP tools, and develop fodder incrementally. Use when creating or fixing a catlet, inline fodder, or a fodder gene's content.
---

# Catlet authoring

Write catlet specs and inline fodder, prove them with the eryph MCP tools, then hand working
fodder to the `gene-maintainer` agent for extraction into a gene.

Background: `docs/eryph-knowledge.md` (concepts), `docs/fodder-debugging.md` (debugging),
`docs/error-patterns.md` (error messages), `docs/tooling.md` (tools and commands).

## Loop

1. Write the YAML.
2. `validate_catlet` — the source of truth for syntax. Fix every `[content error]` before deploying.
   The bundled `docs/catlet-schema-v1.0.json` is stricter than eryph; don't reject valid YAML
   because of it.
3. `deploy_catlet` → `start_catlet` → `wait_for_provisioning` → check with `catlet_exec`.
4. On failure: `get_provisioning_log`, then the guest logs (see `docs/fodder-debugging.md`).
   Fix the YAML, `remove_catlet`, deploy a fresh catlet. Fodder runs once per instance; re-running
   on the same catlet doesn't prove the fix.
5. Remove test catlets you created. Never remove catlets you didn't create.

Address catlets by catlet id; names are not unique.

## Syntax that bites

- **Inline fodder:** `name` + `type` + `content` (+ `filename` for scripts). There is no
  `source: inline`.
- **Gene fodder:** `source: gene:<org>/<geneset>[/<tag>]:<fodder-name>`. The fodder name is
  required. Without a tag, `latest` is used.
- **Parent:** no `gene:` prefix — `parent: dbosoft/ubuntu-24.04/starter`. `starter` parents
  already include starter-food; don't add it again.
- **Variables:** a list of objects, never a map. Use them in content as `{{ name }}`.
  eryph only substitutes `{{ var }}`; `{% if %}` and other Jinja are not evaluated.
  ```yaml
  variables:
  - name: siteName
    value: demo
  - name: enableTls
    type: boolean
    value: false
  ```
- **Property names:** case-insensitive (`filename`, `fileName` both work), but `file_name` is
  rejected — eryph's "use snake case" hint is wrong for this key.
- **Unknown properties fail validation** — don't invent keys.
- **cloud-config `content`:** either a YAML mapping or a `|` string block.
- **Indentation:** every line under `content: |` (blank lines and PowerShell here-string
  bodies included) is indented past `content:`. Spaces only.

## Linux catlets (cloud-init)

- Full cloud-config: `packages`, `write_files`, `runcmd`, `users`, … .
- `type: shellscript` content starts with a shebang (`#!/bin/bash`).
- A failing module or script can stop the parts after it — the main reason for the
  incremental rule below.
- `catlet_exec` runs as root in the default shell; append `< /dev/null` to commands that might
  read stdin (guest-services#68).

## Windows catlets (egs-service, no cloudbase-init)

Windows base catlets run eryph guest services as the provisioning agent:
- **Full cloud-config:** users, groups, passwords, `write_files`, `runcmd`, `ntp`, `timezone`,
  `locale`, hostname, network config and `power_state` are applied.
- **Ignored on Windows:** Linux-only keys like `packages`, `apt` and `snap` are logged and
  skipped. Use scripts for installs, Windows features and winget/choco.
- **Not supported:**
  - Jinja templates
  - random passwords (always set an explicit one)
  - the modules `windows_update`, `winget`, `chocolatey`, `chef`, `dsc`
- **Scripts:** give them `filename: name.ps1` (or `.cmd`). The extension picks the interpreter;
  `#ps1_sysnative` also works. A `#!/bin/...` script is skipped on Windows.
- **Reboots:** exit `1001` reboots and continues with the next script; `1003` reboots and re-runs
  the same script. `1002` is not supported.
- **Failure behaviour:** any other non-zero exit is logged, and the next script still runs.
  Check the per-script logs instead of trusting "provisioning completed".
- **`catlet_exec`:** runs in PowerShell. `sc` and `type` are aliases there; use `sc.exe` and
  `Get-Content`.

```yaml
name: iis-test
parent: dbosoft/winsrv2022-standard/starter
fodder:
- name: install-iis
  type: shellscript
  filename: install-iis.ps1
  content: |
    Install-WindowsFeature Web-Server -IncludeManagementTools
```

## Guest services

Every dbosoft base catlet ships eryph guest services, so `catlet_exec` works without any fodder.
Never add `gene:dbosoft/guest-services:*` fodder or SSH-key variables to test catlets.
Interactive ssh and file transfer: see `docs/tooling.md` (`egs-tool catlet …`).

## Incremental fodder

Fodder that combines several system changes is built up step by step:

1. Deploy a catlet with only the parent and confirm `catlet_exec` works.
2. Add one fodder item, deploy fresh, verify its effect.
3. Repeat. When a step fails, the last added item is the cause.

Give these their own step:
- package repository additions
- service or systemd changes
- scripts over ~50 lines
- downloads of external scripts
- kernel modules
- reboots

## Done

Once inline fodder works, the `gene-maintainer` agent extracts it into a gene under `src/` and
writes the gene's tests (see `tests/README.md`).

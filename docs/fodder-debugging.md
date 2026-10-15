# Fodder and Catlet Debugging Guide

How to find out why a catlet did not end up configured the way its fodder says. Covers the debug
workflow with the eryph MCP tools, the incremental fodder method, and where to look inside the guest on
Windows and Linux.

Related docs:
- Authoring rules for catlets and fodder: `.claude/skills/catlet-authoring/SKILL.md`
- Commands (MCP tools, `egs-tool`, PowerShell cmdlets): `docs/tooling.md`
- Error messages and what they mean: `docs/error-patterns.md`

## Provisioning model

| | Linux base catlets | Windows base catlets |
|---|---|---|
| Provisioning agent | cloud-init | eryph guest services (`egs-service`, service `eryph-guest-services`) |
| Remote access (`catlet_exec`, SSH) | eryph guest services (package `eryph-guest-services`) | eryph guest services |
| cloudbase-init | not used | **not installed anymore** |

Guest services ship in every dbosoft base catlet. Remote access therefore does **not** depend on fodder:
never add guest-services install fodder to a catlet, and do not treat a failed exec as proof that fodder
broke remote access.

### What a failing fodder item does

- **Linux (cloud-init):** a failing module or script can stop later parts from running. A broken item
  early in the list can leave the rest of the configuration unapplied. This is where incremental testing
  matters most.
- **Windows (egs-service):** a script with a non-zero exit code (other than the reboot codes `1001`/`1003`)
  is logged, and the **next script still runs** — there is no cascade abort. However, an early config
  module that fails or is misconfigured (users/passwords, network config, hostname) can still break
  everything that depends on it. Modules run in a fixed order: Growpart, SetHostname, ApplyNetworkConfig,
  NtpClient, Timezone, SetLocale, UsersGroups, SetPasswords, SshModule, WriteFiles, Runcmd, Licensing,
  WriteFilesDeferred, ScriptsUser, PowerState.
- **Windows silently ignores** some things, which looks like "my fodder did nothing": Linux-only keys
  (`apt`, `packages`, `snap`, …) are logged at Info and skipped; `## template: jinja` is ignored;
  `.sh` scripts and `#!/...` shebangs are skipped; random passwords are skipped; boothooks are not run;
  `windows_update`, `winget`, `chocolatey`, `chef`, `dsc` modules are not implemented. Check `agent.log`
  for the skip message.

## Workflow with the MCP tools

All tools address catlets by **catlet id** (names are not unique). Capture the id from `deploy_catlet`.

1. `validate_catlet(config, variables)` — always first. It is the source of truth for syntax; the bundled
   JSON schema is stricter than eryph. Fix `[content error]` results before deploying.
2. `deploy_catlet(config, variables, name, project, waitSeconds)` → catlet id. For long deployments poll
   with `get_operation`.
3. `start_catlet(catletId)`.
4. `wait_for_provisioning(catletId, timeoutSeconds)` — waits until guest services report and provisioning
   completes or fails.
5. `get_provisioning_log(catletId)` — eryph's provisioning log as reported by the guest. Read this before
   going into the guest.
6. `catlet_exec(catletId, command, timeoutSeconds)` — inspect the guest (commands below), then verify the
   expected end state (files, services, packages).

Errors returned by the tools carry a category prefix:
- `[content error]` → the catlet/fodder definition must change.
- `[state error]` → system state must change (catlet exists, not running, not found, …).
- `[transient error]` → retry.

When the cause is fixed in the definition, deploy a **fresh** catlet. Do not keep patching a catlet whose
provisioning already ran; results from re-runs are not comparable to a clean deployment.

## Incremental fodder method

Do not write the complete configuration in one go. Build it up:

1. **Baseline:** a catlet with only a parent. No fodder.
   ```yaml
   name: debug-baseline
   parent: dbosoft/ubuntu-24.04/starter   # or dbosoft/winsrv2022-standard/starter
   ```
   `/starter` parents already include starter-food; do not add it again. Deploy, start,
   `wait_for_provisioning`, then run a trivial `catlet_exec` (`hostname`). Only continue if this works —
   if it fails, the problem is the base catlet or the host, not your fodder.
2. **Add one fodder item**, deploy a fresh catlet, verify its effect with `catlet_exec`.
3. Repeat. The first item whose addition breaks provisioning or the expected state is the culprit.
4. Fix the culprit in isolation: split it into smaller items, make scripts log what they do and fail
   with a clear exit code, then retest.

Items that deserve their own increment (they fail most often):
- adding package repositories or downloading external content,
- service changes (`systemctl daemon-reload`, enabling/restarting services),
- long shell scripts — split them,
- kernel module changes or anything that needs a reboot (on Windows use exit code `1001` / `1003`,
  `1002` is not supported),
- user, password and network configuration (they affect everything after them).

## Inspecting the guest

`catlet_exec` notes:
- Windows: the shell is **PowerShell**. `sc` and `type` are aliases — use `sc.exe` and `Get-Content`.
- Linux: runs as root in the default shell, no TTY, no stdin. Append `< /dev/null` to commands that might
  read stdin, otherwise they can hang (known egs issue eryph-org/guest-services#68).
- stdout and stderr are merged.

### Windows (egs-service)

Look at `state.json` first, then `agent.log`, then the per-script logs.

```powershell
# What ran; completedStages should contain Local, Network, Config, Final
Get-Content C:\ProgramData\eryph\provisioning\state.json

# Agent operational log: datasource, every module, skips, reboots, SSH events
Get-Content C:\ProgramData\eryph\guest-services\logs\agent.log -Tail 100
Select-String -Path C:\ProgramData\eryph\guest-services\logs\agent.log -Pattern 'error|warn|fail'

# Per-script stdout/stderr + exit code (<order>-<filename>.log)
Get-ChildItem C:\ProgramData\eryph\provisioning\logs
Get-Content C:\ProgramData\eryph\provisioning\logs\001-<filename>.log

# The scripts exactly as the agent staged and ran them
Get-ChildItem C:\ProgramData\eryph\provisioning\scripts\per-instance

# Service state
sc.exe query eryph-guest-services
```

To hand logs over as one file, bundle them and download with
`egs-tool catlet download-file <catlet-id> <src> <dst>`:

```powershell
& 'C:\Program Files\eryph\guest-services\bin\egs-service.exe' collect-logs C:\Windows\Temp\egs-bundle.zip
```

The agent also mirrors its events into the Windows Event Log, but `agent.log` is the primary source.

### Linux (cloud-init)

```sh
cloud-init status --long < /dev/null
tail -n 100 /var/log/cloud-init-output.log      # script output
grep -nE 'WARNING|ERROR|Traceback' /var/log/cloud-init.log
ls -l /var/lib/cloud/instance/scripts/           # rendered user scripts
cat /var/lib/cloud/instance/cloud-config.txt     # merged cloud-config parts
zcat /var/lib/cloud/instance/user-data.txt       # raw user-data (gzip-compressed)
tail -n 100 /var/log/eryph/guest-services/agent.log   # guest services (remote access)
```

Compare `cloud-config.txt` and the rendered scripts with what you expected; a missing key or an
unsubstituted `{{ variable }}` shows up there.

## Worked examples

### Linux: later configuration is missing

A catlet adds a package repository, installs a package from it and writes a config file. After
`wait_for_provisioning`, the config file is not there.

- Do not suspect networking or remote access — `catlet_exec` works because guest services are in the base
  image.
- `cloud-init status --long` reports an error; `cloud-init.log` shows the repository step failed.
  Hypothesis: the failure stopped the later parts.
- Action: move the repository setup into its own fodder item, test it alone on a fresh catlet, fix it,
  then add the next item.

### Windows: script "did nothing"

A Windows catlet has a `type: shellscript` fodder with a `#!/bin/bash` first line and no filename. The
expected change is missing, and there is no per-script log for it.

- `agent.log` shows a skip warning for the script (`#!/...` shebangs are not run on Windows; a skip is a
  warning, not a script failure).
- Action: rewrite as PowerShell and set `filename: something.ps1` — the explicit, recommended way to
  select the runner.

### Windows: one script failed, others ran

Two scripts: the first exits with code 1, the second installs a feature. The feature is installed, the
first script's effect is missing.

- Expected on Windows: a non-zero exit is logged and the next script still runs. The per-script log
  `C:\ProgramData\eryph\provisioning\logs\001-<filename>.log` contains the exit code and stderr.
- Action: fix the first script from its log. Do not reorder or remove the second one — it is not the
  cause.

## Checklist

1. `validate_catlet` passes?
2. Baseline (parent only) provisions and `catlet_exec` works?
3. `wait_for_provisioning` finished, and `get_provisioning_log` shows no errors?
4. Windows: `state.json` lists all four stages; `agent.log` and per-script logs have no errors or skips?
   Linux: `cloud-init status --long` is `done` without errors?
5. Variables substituted (no literal `{{ ... }}` in rendered scripts/config)?
6. Expected end state verified with `catlet_exec`?

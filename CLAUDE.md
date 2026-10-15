# eryph-genes Repository

The official dbosoft eryph genes:
- **Catlet genes:** VM specifications.
- **Fodder genes:** cloud-config and scripts.
- **Volume genes:** base OS disks built from `..\hyperv-boxes`.

Genes are published to the public genepool (https://genepool.eryph.io).

## ⚠️ Never publish without explicit confirmation

`push_packed.ps1` and `pnpm publish-genesets` push to the **public** genepool. A pushed tag
cannot be removed. Never run them for testing, and never without the user's explicit go-ahead
for that specific push. To test a build locally, use `Copy-ToLocalGenepool.ps1`.

Changing gene sources under `src/` is fine; publishing them is the step that needs confirmation.

## Working with catlets: the eryph MCP server

All catlet work goes through the eryph MCP server (`.mcp.json`, tools `mcp__eryph__*`). Don't
script `New-Catlet` etc. by hand for interactive work.

| Need | Tool |
|---|---|
| Check YAML before deploying | `validate_catlet` (authoritative; the JSON schema in docs/ is stricter than eryph) |
| Create / start / stop / remove | `deploy_catlet`, `start_catlet`, `stop_catlet`, `remove_catlet` |
| Long operation still running | `get_operation` |
| Fodder finished? | `wait_for_provisioning`, then `get_provisioning_log` |
| Run a command in the guest | `catlet_exec`: PowerShell on Windows, root shell on Linux, no stdin/TTY |
| Copy files, interactive ssh | `egs-tool catlet ...` (see docs/tooling.md) |

Rules:
- **Address catlets by catlet id.** Names are not unique. The VmId is only for host-side
  `egs-tool <op> <vmid>` in the test scripts.
- **Read the error category.** Each tool error starts with one:
  - `[content error]`: fix the YAML or fodder, then redeploy a fresh catlet.
  - `[state error]`: fix the system state (catlet stopped, missing, or already exists).
  - `[transient error]`: retry.
- **Clean up after yourself.** Remove the test catlets you created. Never touch catlets you
  didn't create; the user has their own catlets on this host.

If the MCP tools are missing, the server isn't installed or approved. Install it with
`dotnet tool install -g Eryph.Mcp.Server` (see docs/tooling.md), then restart the session.
Don't fall back to hand-written PowerShell.

## Writing catlets and fodder

Use the `catlet-authoring` skill. Key rules:

- **Build fodder up incrementally.**
  1. Deploy a catlet with only a parent and check that `catlet_exec` works.
  2. Add one fodder item at a time; deploy fresh and verify after each.

  Never write an elaborate multi-step configuration in one go. On Linux a failing cloud-init part
  can stop everything after it. On Windows the failing script is easy to miss, because later
  scripts still run.
- **Guest services ship in every dbosoft base catlet.** Don't add `guest-services` install fodder
  or SSH keys to test catlets.
- **Windows provisioning is egs-service, not cloudbase-init.**
  - It accepts full cloud-config. Linux-only keys such as `packages` are ignored.
  - Give scripts a `.ps1` / `.cmd` filename; the extension selects the interpreter.
  - Logs: `C:\ProgramData\eryph\provisioning\` and `C:\ProgramData\eryph\guest-services\logs\agent.log`.
- **Linux provisioning is cloud-init.**
- **Syntax:**
  - Variables are a list of objects; reference them as `{{ name }}`.
  - A gene fodder reference needs the fodder name: `gene:org/geneset[/tag]:fodder`.
  - `file_name` is invalid; use `filename`.

When inline fodder works, the `gene-maintainer` agent extracts it into a gene under `src/` and
writes its tests.

## Repository structure

```
src/<geneset>/            # sources: geneset package (no version) + tag packages (versioned) with fodder/
genes/<org>/<geneset>/    # built genesets; <tag>/.packed after a build
packages/                 # build tooling: build-geneset (bins build-geneset, build-geneset-tag), templates
tests/                    # test helpers, base catlet and fodder gene tests
docs/                     # knowledge (see below)
```

Creating a geneset is more than copying files. It needs:
- two npm packages: the geneset without a version, and tag packages with a version
- the dependencies between them
- matching `geneset.json` metadata
- turbo integration

Use the `gene-maintainer` agent for it.

## Build, local test, publish

```powershell
pnpm install
pnpm turbo build --filter=@dbosoft/<package>...               # package name from src/<dir>/package.json
.\Copy-ToLocalGenepool.ps1 -Geneset dbosoft/<geneset>/next    # a build always packs tag next; LOCAL genepool
.\Test-FodderGene.ps1 -Gene dbosoft/<geneset>/next            # elevated session
.\Test-GeneRelease.ps1 dbosoft/<geneset> -FromBuild          # copy next + test, release gate
```

- **Fodder genes:** tests live in `tests/fodder-genes/<geneset>/test-matrix.psd1`; see
  docs/gene-testing.md. A gene without a test matrix can't be tested; write one.
- **Base catlets:**
  - Built from hyperv-boxes with `build.ps1` and `pack_build.ps1`, tested with
    `Test-PackedBaseCatlet.ps1`.
  - For multi-catlet build/publish runs use the `/build-base-catlets` skill. It drives `build.ps1`
    directly, in the background, with monitoring, retry of transient errors and staging hygiene.
- **Versions:**
  - Fodder genes use semantic versions with changesets (`npx changeset`).
  - OS images use date tags (`20261014`).
- **Scripts:**
  - `Resolve-GenepoolPath.ps1` prints the local genepool path (admin); the test scripts cache it
    in `.claude/genepool-path.txt`.
  - `Test-Repository.ps1` runs the static checks of the CI: scripts parse, tag references stay in
    their geneset, unique package names, valid test matrices. Run it before committing.
  - `prepare.ps1` installs or checks the tools (`-BaseCatlets` for Hyper-V builds).
  - CI (Azure Pipelines): `azure-pipelines.yml` builds, packs and checks on PR/push;
    `azure-pipelines-base-catlets.yml` is a manually started base catlet build on the pool `eryph`,
    without push.
  - `check_packed.ps1`, `check_ref_consistency.ps1` and `delete_packed.ps1` handle `.packed`
    hygiene.

## Knowledge base (docs/)

- `tooling.md`: MCP tools, egs-tool, PowerShell module, build and test commands
- `eryph-knowledge.md`: concepts (genes, genesets, tags, fodder, variables, provisioning agents)
- `fodder-debugging.md`: debugging fodder per OS, logs and their locations
- `error-patterns.md`: error messages and what they mean
- `gene-testing.md`: writing and running gene tests

## Dependencies

- **eryph-zero:** 0.5.x, installed and running.
- **eryph MCP server:** the `eryph-mcp` dotnet tool.
- **egs-tool:** guest services host tool.
- **eryph PowerShell module:** used by the test scripts.
- **eryph-packer:** for packing and pushing.
- **pnpm + turbo:** for building genes.
- **hyperv-boxes:** at `..\hyperv-boxes`, only for base catlet builds.

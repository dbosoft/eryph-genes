---
name: build-base-catlets
description: >-
  Build, test, and publish dbosoft base catlets with build.ps1 — intelligent
  filtering from a natural-language request, monitoring of the long-running
  builds, retry of transient infrastructure flakes (never "fixing" real
  failures), safe staging hygiene, and a confirmed push of only the working
  genesets to the genepool. Use when asked to build/publish a set of base
  catlets, e.g. "build all linux catlets and windows server 202x without core
  and push the working ones to the genepool".
---

# Build base catlets (build.ps1 driver)

You orchestrate the base-catlet build pipeline: pick the right templates from a
natural-language request, drive `build.ps1` per template, watch the long-running
output, retry only *transient* infrastructure flakes, keep git staging honest
(failed builds must not be pushed), and publish only the working genesets after
explicit confirmation.

**Three hard rules:**
1. **Never edit fodder, tests, images, or scripts to make a build pass.** You
   retry transient infrastructure flakes; you do **not** fix real failures. A
   real failure is surfaced to the human, its geneset left unstaged.
2. **Never push without explicit confirmation.** `push_packed.ps1` publishes to
   the **public** genepool (genepool.eryph.io) and is **irreversible**.
3. **Run the pipeline yourself, in the main loop.** Run `build.ps1`,
   `Test-PackedBaseCatlet.ps1`, `git` and `push_packed.ps1` directly, using a
   **background** command plus polling. A multi-hour build needs that so you keep
   its output in view, classify transient vs real failures and make the staging
   decisions in-loop; a one-shot subagent cannot.

## Tooling map (how the pipeline really works)

- **`import.json`** — the source of truth for buildable templates. Each entry:
  `{"<template>": { "osType": "linux|windows", "pack": "dbosoft/<name>/{date}",
  "update": ["dbosoft/<name>/latest"] }}`. Only templates listed here can be
  built. Always read it fresh — the list changes.
- **`build.ps1 -Filter <wildcard> -BuildPath <path> [-VmBuildRetries N]`** — for
  every `import.json` template whose name is `-like <wildcard>`, it runs, in
  order: **(1)** build the VM via the basecatlets-hyperv `build.ps1` (Packer /
  cloud-image), **(2)** `pack_build.ps1` (creates `genes/<pack>/.packed` **and
  `git add`s the geneset**), **(3)** `Test-PackedBaseCatlet.ps1` (deploys a
  catlet + runs Pester validation). On any per-template failure it prints
  `X <template> failed: …`, increments the failed count, and **continues** to
  the next template. It exits with 1 when any template failed, but only the
  output tells you which one — parse it.
  - `-Filter` is a single `-like` wildcard, so an arbitrary subset (e.g. "linux
    + win server 202x without core") cannot be expressed in one filter. **Drive
    one `build.ps1` invocation per template** (exact name as the filter). This
    isolates failures and gives clean per-template pass/fail.
  - `-VmBuildRetries N` auto-retries **only the VM-build step** (step 1) on
    failure. Set it (e.g. `2`) to absorb transient Packer/network flakes.
  - Each `build.ps1` run first **deletes leftover build directories** in
    `BuildPath` (its cleanup phase) — expected; run templates sequentially.
- **`pack_build.ps1`** — packs and, in its Step 7, runs `git add <geneset dir>`.
  **This is why staging is unsafe by default: the geneset is staged before the
  test runs**, so a geneset whose test later fails is already staged.
- **`Test-PackedBaseCatlet.ps1 -Geneset <dbosoft/name/tag> -GenepoolPath <gp>
  -OsType <linux|windows> [-KeepVM]`** — can be re-run standalone against an
  already-packed geneset (the `.packed` folder survives `build.ps1`), which is
  how you cheaply re-test a *transient* test failure without rebuilding the VM.
- **`push_packed.ps1 -Staged`** — pushes **only git-staged** genesets to the
  **public** genepool via `eryph-packer geneset-tag push`. Uses
  `$env:ERYPH_APIKEY` if set (else interactive auth). Skips `…/next` tags.
- **`delete_packed.ps1`** — removes `.packed` folders afterwards (optional).
- **`Resolve-GenepoolPath.ps1`** — resolves the local genepool path (admin).

## Step 1 — Resolve the request to a concrete template list

Read `import.json` and translate the request into an explicit list of template
names. Parsing guide (apply against the actual `import.json` entries):

- **"linux"** → every entry with `osType: linux` (ubuntu-*, almalinux-*,
  oracle-*).
- **"windows"** → every entry with `osType: windows`.
- **"windows server" / "server"** → `winsrv*` entries only (excludes win10/win11
  clients).
- **"202x" / "202X"** → years 2022 and 2025 (`winsrv2022-*`, `winsrv2025-*`).
  "201x" → 2016 and 2019. A specific year → just that one.
- **"without core" / "no core"** → exclude `*standardcore*` (and any `*core*`).
  **"core only"** → keep only `*core*`.
- **editions**: "standard" → `*-standard`, "datacenter" → `*-datacenter`,
  "enterprise"/"client" → `win10-*`/`win11-*`.

**Present the resolved list and wait for confirmation before building.** A full
build run is hours long and resource-heavy (each VM build can take 30–60 min).
Show the templates grouped by OS and call out anything ambiguous. Do not start
until the user confirms the set.

## Step 2 — Prerequisites & build path

- `-BuildPath` is the **basecatlets-hyperv `builds` directory** (its parent must
  contain that repo's `build.ps1`). Default convention: `..\hyperv-boxes\builds`.
  Confirm it exists; if the repo lives elsewhere, ask for the path. Do not guess
  silently.
- Building needs Hyper-V + Packer and typically an **elevated** shell; the local
  genepool path resolution and catlet deploys need eryph-zero running and admin.
  If prerequisites are missing, stop and report — do not attempt workarounds.
- Choose `-VmBuildRetries` (default `2`) for transient VM-build resilience.

## Step 3 — Build each template (monitored)

For each confirmed template, sequentially:

```
build.ps1 -Filter <exact-template> -BuildPath <buildPath> -VmBuildRetries 2
```

- Run it **yourself** with a **background** command, then poll (see hard rule 3). These builds are long; a foreground
  call would block or time out. Backgrounding keeps you in the loop to watch
  output, retry transient flakes, and decide staging.
- Watch for the per-template markers: `OK <template> completed successfully`
  (build+pack+test all passed) vs `X <template> failed: <reason>`. Also note the
  build-step retry warnings (`Retrying Packer build …`).
- Track a result record per template: `passed | failed | transient-retry`,
  plus the failing step (vm-build / pack / test) and the reason text.

## Step 4 — Classify results: transient vs real

When a template fails, decide **transient infrastructure flake** vs **real
failure**. Retry transient (bounded); never retry-fix real ones.

**Transient (retry):**
- VM/Packer step: download/ISO timeouts, mirror "connection reset/refused",
  DNS hiccups, WinRM/SSH provisioning timeouts, packer plugin crash. Mostly
  absorbed by `-VmBuildRetries`; if it still fails after retries, treat as real.
- Test step: `Wait-EGSReady`/EGS "not ready" timeout, deploy "operation
  timeout", transient SSH connection timeout, host under load. **Re-run the test
  alone** (cheap — the `.packed` already exists):
  `Test-PackedBaseCatlet.ps1 -Geneset <dbosoft/name/tag> -GenepoolPath <gp>
  -OsType <os>`. Retry the test **at most once or twice**, then treat as real.

**Real (do NOT retry, do NOT fix):**
- Pester assertions failing (e.g. "Should have datasource_list", "…egs-services
  in Running state", missing package, sysprep/provisioning state wrong) — image
  or fodder regression.
- `New-Catlet` NullReferenceException — usually a content/variables problem, not
  infra; treat as real.
- Deterministic, repeatable failures.

Surface real failures clearly (template + step + reason). Do not modify any file
to make them pass — that is a human decision.

## Step 5 — Staging hygiene (CRITICAL — this is the whole point)

`pack_build.ps1` already `git add`ed **every** geneset it packed, **including
ones whose test failed**. You must make staging reflect only the *working*
builds before any push.

For every template that is **not** a clean pass (vm-build failed, pack failed,
test failed, or you could not verify it passed), **unstage its geneset**:

- Derive the geneset dir from the template's `import.json` `pack` field by
  dropping the `/{date}` tag, e.g. `oracle-9` → `dbosoft/oraclelinux-9` →
  `genes/dbosoft/oraclelinux-9`; `ubuntu-22.04` → `genes/dbosoft/ubuntu-22.04`.
  (The template name is **not** always the geneset name — trust `pack`.)
- Unstage it (also reverts the staged `latest` ref for that geneset):
  `git reset -- genes/dbosoft/<name>`

Then verify: run `git status --short` and confirm **only the passed genesets
remain staged**. As a cross-check, `push_packed.ps1 -Staged` operates on exactly
the staged set — the staged list you see is what would be published.

Report a clear table: passed (staged, will publish) vs failed/unverified
(unstaged, skipped) with reasons.

## Step 6 — Publish working genesets (DANGEROUS — confirm first)

Only if the user asked to push/publish:

1. Show the exact staged genesets that will go to the **public** genepool and
   the failed ones being skipped. State plainly that this is irreversible.
2. Get **explicit confirmation**.
3. Ensure `$env:ERYPH_APIKEY` is set for non-interactive auth (otherwise the
   push prompts).
4. Run `push_packed.ps1 -Staged`.
5. Report what was published. Optionally `delete_packed.ps1` to clean `.packed`.

The passed genesets are also git-staged repo content — recommend committing them
(`git commit`) so the repo records the published base catlets. Keep that commit
to the genesets that actually published; never commit failed genesets.

## Guardrails recap

- Confirm the template set before building; confirm again before pushing.
- Per-template `build.ps1` runs, sequential, monitored, with `-VmBuildRetries`.
- Retry only transient infra flakes; never edit anything to force a pass.
- Unstage every non-passing geneset before push — packing staged it for you.
- `push_packed.ps1` is public + irreversible; only the staged (passing) set goes.

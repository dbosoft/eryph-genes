# Eryph Specialist Reasoning — test-ubuntu-2404-fodder catlet

## Schema sections read (verified, not from memory)

- `name` (lines 21-28): string, pattern `^[a-zA-Z0-9]+([\\.-]?[a-zA-Z0-9]+)*$`. Verified `test-ubuntu-2404-fodder` matches — hyphens are in the character class `[\\.-]`.
- `parent` (lines 61-68): string, `dbosoft/ubuntu-24.04/20260526` matches the `org/geneset/tag` pattern.
- `fodder` array items (`fodder_reference`, lines 402-431): only `source` is required. Pattern confirms `gene:org/geneset/tag:fodder-name` form. Both gene references in the orchestrator match this pattern.
- No `variables`, `cpu`, or `memory` overrides — not needed for a pure reproduction test.

## Format choices

- Exact catlet structure from the orchestrator: `name`, `parent`, `fodder` (two `source`-only gene references).
- Name changed to `test-ubuntu-2404-fodder` per request.
- No inline content added — the point is to reproduce the gene-sourced fodder failure, not introduce new content.
- EGS is bundled in every official dbosoft base catlet; no guest-services fodder needed.

## Validation checklist

- [x] Schema re-read for every property used
- [x] Variables: not present (none needed)
- [x] No `content:` blocks present (no indentation rules apply)
- [x] No tabs
- [x] No `gene:dbosoft/guest-services:*-install`
- [x] No `source: inline`
- [x] `source:` values match `fodder_reference` pattern

## Assumption vs verified

- `gene:dbosoft/powershell:linux-install` and `gene:dbosoft/starter-food:linux-starter` — patterns taken directly from the orchestrator YAML provided by the user; not independently verified against genepool, but reproduction fidelity is the goal.
- EGS bundled: consistent with system prompt rule and prior session reasoning.

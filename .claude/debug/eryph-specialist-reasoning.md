# Eryph Specialist Reasoning - test-include-win-std

## Schema Sections Read

- `docs/catlet-schema-v1.0.json` lines 1-100 (top-level properties, parent pattern)
- `docs/catlet-schema-v1.0.json` lines 386-535 (fodder definitions, fodder_other)
- `.claude/debug/eryph-specialist-reasoning.md` (previous run for include-url pattern)

## Key Schema Findings

### parent format (line 65)
Pattern: `^[a-zA-Z0-9]+([\\.-]?[a-zA-Z0-9]+)*/[a-zA-Z0-9]+([\\.-]?[a-zA-Z0-9]+)*(/[a-zA-Z0-9]+([\\.-]?[a-zA-Z0-9]+)*)?$`
- `dbosoft/winsrv2022-standard/20260518` matches - valid
- NO `gene:` prefix

### fodder_other (lines 478-535)
- Required: `name` + `content`
- `type`: enum including `include-url`
- `content`: plain `string` (not a block scalar, single-line URL is fine)
- `filename`: NOT required for include-url (only shellscript on Windows)

## Design Decisions

1. **parent**: `dbosoft/winsrv2022-standard/20260518` - full standard (not core), specific tag
2. **No EGS gene**: EGS is embedded in the 20260518 base image - no guest-services fodder needed
3. **Include fodder**: `type: include-url`, content = raw URL string (single line, no block scalar)
4. **No variables**: nothing parameterised

## Validation Checklist

- [x] name: test-include-win-std - matches pattern, valid
- [x] parent: dbosoft/winsrv2022-standard/20260518 - no gene: prefix, matches pattern
- [x] fodder_other: name + content both present (required fields satisfied)
- [x] type: include-url - valid enum value
- [x] content: plain string URL - correct type per schema
- [x] No filename (not required for include-url)
- [x] No variables (none needed)
- [x] No EGS gene reference (correctly omitted per user requirement)
- [x] No tabs, 2 spaces per level
- [x] No high-risk patterns

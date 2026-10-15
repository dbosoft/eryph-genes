# @dbosoft/sapadt-default

## 1.1.0

### Minor Changes

- 64b412e: add a Microsoft Defender process exclusion for eclipse.exe (variable defender_exclusion, default true) and turn off Eclipse's Defender startup check, so users don't get a dialog they need admin rights for.

## 1.0.0

### Major Changes

- 4e98d10: new geneset sapadt: installs Eclipse (2026-09, bundled JRE) with the SAP ABAP Development Tools from the SAP update site, plus the Visual C++ v14 runtime ADT needs.

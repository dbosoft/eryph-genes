# Eclipse with SAP ABAP Development Tools (ADT)

This geneset provides fodder for installing the Eclipse IDE with the SAP ABAP Development Tools
(ADT) on Windows. The fodder installs:

- the Microsoft Visual C++ v14 runtime (x64), required by ADT
- the Eclipse IDE for Java Developers, which bundles its own Java runtime (Eclipse Temurin)
- the features of the "ABAP Development Tools" category from the SAP update site
  (https://tools.hana.ondemand.com)

A Start menu shortcut "Eclipse" is created for all users.

## Usage

```yaml
fodder:
  - source: gene:dbosoft/sapadt:install
```

Install into another folder or use another Eclipse release:

```yaml
fodder:
  - source: gene:dbosoft/sapadt:install
    variables:
      - name: eclipse_release
        value: '2026-09'
      - name: install_dir
        value: D:\tools\eclipse
```

The catlet needs internet access; the fodder downloads about 600 MB. Plan at least 4 GB of memory
for working with Eclipse.

## Variables

| Name | Default | Description |
|---|---|---|
| `eclipse_release` | `2026-09` | Eclipse simultaneous release, e.g. `2026-06`. It must be a release that ADT supports; see the prerequisites on https://tools.hana.ondemand.com/#abap. |
| `install_dir` | `C:\eclipse` | Installation folder. The fodder grants the local Users group modify permissions on it, so users can install updates and plugins without elevation. |
| `adt_repository` | `https://tools.hana.ondemand.com/<eclipse_release>` | ADT update site. |
| `adt_features` | all features below | Features to install, comma separated; see [ADT features](#adt-features). |

## ADT features

By default the fodder installs all features of the "ABAP Development Tools" category on the
update site. Each feature pulls in its own dependencies (CDS, DDIC, debugger, ABAP Unit test
doubles, ...).

| Feature | Content |
|---|---|
| `com.sap.adt.core.devedition.feature.group` | ABAP Core Development Tools: ABAP, CDS, RAP, debugger, ABAP Unit. Always install it. |
| `com.sap.adt.tools.hana.devedition.feature.group` | ABAP Development Tools for SAP HANA (AMDP, SQLScript) |
| `com.sap.adt.tools.bopf.devedition.feature.group` | ABAP Business Object Tools (BOPF) |
| `com.sap.adt.wda.core.devedition.feature.group` | ABAP Development Tools for Web Dynpro |
| `com.sap.adt.pitools.tlf.devedition.feature.group` | ABAP Enterprise Services and Integration Development Tools |

`adt_features` replaces the default list. To install only the core tools, for example for SAP BTP
ABAP Environment:

```yaml
fodder:
  - source: gene:dbosoft/sapadt:install
    variables:
      - name: adt_features
        value: com.sap.adt.core.devedition.feature.group
```

## Notes

- SAP GUI is not installed. It is not required for SAP BTP ABAP Environment and SAP S/4HANA
  Cloud ABAP Environment; for on-premise systems install SAP GUI for Windows yourself.
- By installing ADT you accept the SAP Developer License Agreement
  (https://tools.hana.ondemand.com/developer-license-3_2.txt).

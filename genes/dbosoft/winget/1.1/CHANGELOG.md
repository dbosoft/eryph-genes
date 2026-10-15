# @dbosoft/winget-default

## 1.1.0

### Minor Changes

- 2167227: install winget as provisioned package for all users (fodder runs as Local System, which Add-AppxPackage rejects); dependencies and license come from the winget release. New variable packages installs winget packages machine-wide, and a wrapper (C:\ProgramData\eryph\winget\winget-system.ps1) lets other fodder run winget as Local System.

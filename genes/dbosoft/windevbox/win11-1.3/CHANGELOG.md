# @dbosoft/windevbox-win11

## 1.3.0

### Minor Changes

- 50897f7: variable devdrive_name renamed to devdrive_disk; an unusable disk falls back to the VHDX on C:

## 1.2.0

### Minor Changes

- fc29958: dev drive as VHDX on C: instead of a second disk (devdrive_name for a dedicated disk), Visual Studio 2026 with its package cache on the dev drive, 8 vCPUs, optional Git identity per user at first logon (git_user_name, git_user_email).

## 1.1.0

### Minor Changes

- abdabc0: install the dev tools with winget instead of Chocolatey (variable dev_tools), 127 GB system disk for Visual Studio, configure-git fails when git is missing.

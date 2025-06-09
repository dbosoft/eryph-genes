# @dbosoft/starter-food-default

## 1.4.0

### Minor Changes

- 8b12dd5: Fix SSH firewall rule for Windows Server 2025

  By default, Windows Server 2025 opens the port for OpenSSH only for the private network profile.
  This change ensures that the firewall rule is always applied to all network profiles.

## 1.3.0

### Minor Changes

- 3f2b8d8: windows - rdp and ssdh script errors

  RDP script fails due to formatting (see #2)
  SSHD script fails on Windows Server 2016 (where it is not supported)

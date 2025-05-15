---
"@dbosoft/starter-food-default": minor
---

Fix SSH firewall rule for Windows Server 2025

By default, Windows Server 2025 opens the port for OpenSSH only for the private network profile.
This change ensures that the firewall rule is always applied to all network profiles.

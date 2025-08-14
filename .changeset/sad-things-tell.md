---
"@dbosoft/guest-services-default": minor
---

Multiple minor improvements:

- SSH public key is now optional to allow configuration with egs-tool instead
- The TERM variable is set to a reasonable value on Linux to prevent CLI
  tools from failing
- The Windows guest service has auto start enabled by default

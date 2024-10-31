
param ($EMail, $InvitationCode)

install-module powershell-yaml -Force

Invoke-Expression "& { $(Invoke-RestMethod https://raw.githubusercontent.com/eryph-org/eryph/main/src/apps/src/Eryph-zero/install.ps1) } -EMail $EMail -InvitationCode $InvitationCode"
Invoke-Expression "& { $(Invoke-RestMethod https://raw.githubusercontent.com/eryph-org/dotnet-genepoolclient/refs/heads/main/src/apps/src/eryph-packer/install.ps1) } -Force -EMail $EMail -InvitationCode $InvitationCode"
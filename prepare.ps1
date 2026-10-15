# prepare.ps1
# Prepares a build agent (or a dev machine) for this repository. Installs the
# tools that are missing and checks the ones that must be installed up front.
#
#   .\prepare.ps1                # gene builds and repository checks
#   .\prepare.ps1 -BaseCatlets   # additionally base catlet builds and tests
#
# Base catlet builds need a Hyper-V host with eryph-zero and egs-tool installed,
# running in an elevated session; this script only checks those.

[CmdletBinding()]
param(
    [switch]$BaseCatlets
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$missing = [System.Collections.Generic.List[string]]::new()

function Add-ToPath([string]$path) {
    if (-not ($env:PATH -split ';' -contains $path)) {
        $env:PATH = "$path;$env:PATH"
    }
    if ($env:TF_BUILD) {
        # Make the tool available to the following pipeline steps
        Write-Host "##vso[task.prependpath]$path"
    }
}

# eryph-packer packs genesets during `turbo build`
$packerBin = Join-Path $env:LOCALAPPDATA 'eryph\packer\bin'
if (-not (Get-Command eryph-packer -ErrorAction SilentlyContinue) -and -not (Test-Path (Join-Path $packerBin 'eryph-packer.exe'))) {
    Write-Information 'Installing eryph-packer...'
    $installer = Invoke-RestMethod 'https://raw.githubusercontent.com/eryph-org/dotnet-genepoolclient/refs/heads/main/src/apps/src/eryph-packer/install.ps1'
    & ([scriptblock]::Create($installer)) -Force
}
Add-ToPath $packerBin
& eryph-packer --version | Out-Null
Write-Information "eryph-packer: $(& eryph-packer --version)"

# pnpm through corepack (Node.js must be installed)
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    $missing.Add('Node.js (https://nodejs.org) - needed for pnpm/turbo')
} elseif (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Write-Information 'Enabling pnpm through corepack...'
    corepack enable
}

if ($BaseCatlets) {
    # Resolve-GenepoolPath.ps1 parses eryph-zero's settings with ConvertFrom-Yaml
    if (-not (Get-Module -ListAvailable powershell-yaml)) {
        Write-Information 'Installing powershell-yaml...'
        Install-Module powershell-yaml -Scope CurrentUser -Force
    }

    # The test scripts need Pester 5 or later
    if (-not (Get-Module -ListAvailable Pester | Where-Object { $_.Version.Major -ge 5 })) {
        Write-Information 'Installing Pester...'
        Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $missing.Add('an elevated session (Hyper-V, host-side egs-tool, genepool path)')
    }

    $zero = Get-Service eryph-zero -ErrorAction SilentlyContinue
    if (-not $zero) {
        $missing.Add('eryph-zero (https://www.eryph.io)')
    } elseif ($zero.Status -ne 'Running') {
        $missing.Add("a running eryph-zero service (status: $($zero.Status))")
    }

    # Packer is not checked: basecatlets-hyperv manages its own copy in tools\
    if (-not (Get-Command egs-tool -ErrorAction SilentlyContinue)) {
        $missing.Add('egs-tool on the PATH')
    }

    if (-not (Get-Command New-Catlet -ErrorAction SilentlyContinue)) {
        $missing.Add('the eryph PowerShell module (New-Catlet)')
    }
}

if ($missing.Count -gt 0) {
    Write-Host 'Missing prerequisites:' -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
Write-Host 'All prerequisites are in place.' -ForegroundColor Green
exit 0

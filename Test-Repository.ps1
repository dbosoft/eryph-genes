# Test-Repository.ps1
# Static consistency checks for the repository; needs no Hyper-V, eryph-zero
# or network. Run by the PR/push pipeline (azure-pipelines.yml) and locally:
#   .\Test-Repository.ps1
# Exits with 1 and lists every problem when a check fails.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$problems = [System.Collections.Generic.List[string]]::new()
Push-Location $PSScriptRoot

try {
    # 1. Every tracked PowerShell file parses.
    foreach ($file in git ls-files '*.ps1' '*.psm1' '*.psd1') {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $file).Path, [ref]$null, [ref]$errors)
        foreach ($e in $errors) {
            $problems.Add("${file}:$($e.Extent.StartLineNumber): $($e.Message)")
        }
    }

    # 2. Geneset tag references stay inside their geneset and point to a tag
    #    that exists in genes/ (latest -> dbosoft/win11-24h2-enterprise/... was
    #    published once for win10-20h2-enterprise).
    foreach ($tagFile in Get-ChildItem genes -Recurse -Filter geneset-tag.json | Where-Object FullName -notmatch '\\\.packed\\') {
        $tag = Get-Content $tagFile.FullName -Raw | ConvertFrom-Json
        if (-not $tag.ref) { continue }
        $geneset = ($tag.geneset -split '/')[0..1] -join '/'
        if (-not $tag.ref.StartsWith("$geneset/")) {
            $problems.Add("$($tag.geneset) references $($tag.ref), a different geneset")
        }
        elseif (-not (Test-Path (Join-Path 'genes' ($tag.ref.Replace('/', '\'))))) {
            $problems.Add("$($tag.geneset) references $($tag.ref), which does not exist in genes/")
        }
    }

    # 3. Package names are unique (turbo --filter selects by name).
    Get-ChildItem src -Recurse -Filter package.json -Depth 2 |
        Where-Object FullName -notmatch '\\(node_modules|dist)\\' |
        ForEach-Object { [pscustomobject]@{ Path = $_.FullName; Name = (Get-Content $_.FullName -Raw | ConvertFrom-Json).name } } |
        Group-Object Name | Where-Object Count -gt 1 |
        ForEach-Object { $problems.Add("package name $($_.Name) is used by: $($_.Group.Path -join ', ')") }

    # 4. Fodder gene test matrices load and reference existing catlet specs
    #    with a fodder name in the gene reference.
    foreach ($matrixFile in Get-ChildItem tests\fodder-genes -Recurse -Filter test-matrix.psd1) {
        $dir = $matrixFile.DirectoryName
        try {
            $matrix = Import-PowerShellDataFile $matrixFile.FullName
        } catch {
            $problems.Add("$($matrixFile.FullName): $_")
            continue
        }
        foreach ($suite in $matrix.TestSuites) {
            foreach ($key in 'Name', 'OSMatrix', 'CatletSpec') {
                if (-not $suite[$key]) { $problems.Add("$($matrixFile.FullName): suite '$($suite.Name)' has no $key") }
            }
            $spec = Join-Path $dir "$($suite.CatletSpec)"
            if (-not (Test-Path $spec)) {
                $problems.Add("$($matrixFile.FullName): catlet spec $($suite.CatletSpec) not found")
            } elseif ((Get-Content $spec -Raw) -match 'gene:\{\{(GENE|GENE_TAG)\}\}(?!:)') {
                $problems.Add("${spec}: gene reference without fodder name (use gene:{{GENE}}:<fodder>)")
            }
            foreach ($check in @($suite.HostTests | Where-Object { $_ })) {
                if ($check.Expect) {
                    try { $null = [regex]::new($check.Expect) }
                    catch { $problems.Add("$($matrixFile.FullName): host test '$($check.Name)' has an invalid Expect regex: $($check.Expect)") }
                }
            }
            foreach ($test in @($suite.InVMTests | Where-Object { $_ })) {
                if (-not (Test-Path (Join-Path $dir $test))) {
                    $problems.Add("$($matrixFile.FullName): in-VM test $test not found")
                }
            }
        }
    }
}
finally {
    Pop-Location
}

if ($problems.Count -gt 0) {
    Write-Host "Repository checks failed:" -ForegroundColor Red
    $problems | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
Write-Host "Repository checks passed." -ForegroundColor Green
exit 0

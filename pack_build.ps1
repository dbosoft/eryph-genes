[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]
    $TemplateName,
    
    [Parameter(Mandatory=$true)]
    [string]
    $BuildPath,

    [Parameter(Mandatory=$false)]
    [switch] $IgnoreMissing,

    [Parameter(Mandatory=$false)]
    [switch] $RemoveBuild
)
$InformationPreference= 'Continue'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " PACKING TEMPLATE: $TemplateName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

push-Location $PSScriptRoot

Write-Host "PHASE 1: Initialization" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow

Write-Information "Loading import specifications..."
$importSpecs = Get-Content -Raw -Path "import.json" | ConvertFrom-Json
$keys = $importSpecs | ForEach-Object { $_ | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name } | Where-Object {$_ -like $TemplateName}

if (-not $keys) {
    Write-Error "Template '$TemplateName' not found in import.json"
    return
}

Write-Information "Resolving build path..."
$resolvedBuildPath = Resolve-Path $BuildPath

if((Test-Path $resolvedBuildPath -PathType Container) -eq $false)
{
    Write-Error "Could not find build path: $BuildPath"
    return
}
Write-Information "Build path: $resolvedBuildPath"

Write-Host ""
Write-Host "PHASE 2: Processing Templates" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow

$keys | ForEach-Object {
    $importSpec = $importSpecs.$_
    $TemplateName = $_
    
    Write-Host ""
    Write-Host "Processing: $TemplateName" -ForegroundColor Magenta
    Write-Host "----------------------------------------" -ForegroundColor Magenta
    
    Write-Information "Step 1: Locating build output..."
    $buildGeneset = Join-Path $resolvedBuildPath -ChildPath "$TemplateName-stage1\$TemplateName"

    if((Test-Path $buildGeneset -PathType Container) -eq $false)
    {        
        if($IgnoreMissing){
            Write-Warning "Could not find build VM in path: $buildGeneset"
            return
        }else{
            Write-Error "Could not find build VM in path: $buildGeneset"
            exit
        }
    }
    Write-Host "  ✓ Found build output at: $buildGeneset" -ForegroundColor Green

    $packTarget = $importSpec.pack
    
    if($null -ne $packTarget)
    {
        Write-Information "Step 2: Preparing pack target..."
        $day = Get-Date -Format "yyyyMMdd"
        $packTarget = $packTarget.replace("{date}", $day)
        Write-Information "  Target: $packTarget"

        $packTargetPath = "genes\"+ $packTarget.Replace('/', '\\')
        $geneSetPath = split-path $packTargetPath -parent

        Write-Information "Step 3: Initializing geneset structure..."
        
        # Check for geneset.json file, not just directory
        $genesetJsonPath = Join-Path $geneSetPath "geneset.json"
        if((Test-Path $genesetJsonPath -PathType Leaf) -ne $true){
            Write-Information "  Creating geneset: $packTarget"
            & eryph-packer geneset init $packTarget --public --workdir genes
            Write-Host "  ✓ Geneset created" -ForegroundColor Green
        } else {
            Write-Host "  ✓ Geneset already exists (geneset.json found)" -ForegroundColor Green
        }

        # Check for geneset-tag.json file, not just directory
        $genesetTagJsonPath = Join-Path $packTargetPath "geneset-tag.json"
        if((Test-Path $genesetTagJsonPath -PathType Leaf) -ne $true){
            Write-Information "  Creating geneset tag: $packTarget"
            & eryph-packer geneset-tag init $packTarget  --workdir genes
            Write-Host "  ✓ Geneset tag created" -ForegroundColor Green
        } else {
            Write-Host "  ✓ Geneset tag already exists (geneset-tag.json found)" -ForegroundColor Green
        }

        Write-Information "Step 4: Adding VM to geneset..."
        & eryph-packer geneset-tag add-vm $packTarget $buildGeneset  --workdir genes
        Write-Host "  ✓ VM added to geneset" -ForegroundColor Green

        # Add rearm-eval fodder for Windows VMs
        if ($importSpec.osType -eq "windows") {
            Write-Information "Step 5: Adding Windows-specific configuration..."
            $catletPath = Join-Path "genes" ($packTarget.Replace('/', '\') + "\catlet.yaml")
            
            # Append fodder section with rearm-eval
            $fodderContent = "`r`rfodder:`r`r  - source: gene:dbosoft/winconfig:rearm-eval"
            Add-Content -Path $catletPath -Value $fodderContent
            Write-Host "  ✓ Added rearm-eval fodder for Windows evaluation period" -ForegroundColor Green
        }
        
        Write-Information "Step 6: Packing geneset..."
        & eryph-packer geneset-tag pack $packTarget --workdir genes
        Write-Host "  ✓ Geneset packed successfully" -ForegroundColor Green
        
        Write-Information "Step 7: Staging for git..."
        git add $geneSetPath  | Out-Null
        Write-Host "  ✓ Changes staged for git" -ForegroundColor Green
    }

    $updateTarget = $importSpec.update

    if($null -ne $updateTarget)
    {
        Write-Information "Step 8: Updating latest reference..."
        $updatePath = "genes\"+ $updateTarget.Replace('/', '\\')
        if((Test-Path $updatePath) -ne $true){
            Write-Information "  Creating update target: $updateTarget"
            & eryph-packer geneset-tag init $updateTarget --workdir genes
        }
        Write-Information "  Updating reference from $packTarget to $updateTarget"
        & eryph-packer geneset-tag ref $updateTarget $packTarget  --workdir genes | Out-Null
        & eryph-packer geneset-tag pack $updateTarget --workdir genes  | Out-Null
        Write-Host "  ✓ Latest reference updated" -ForegroundColor Green
    }

    if($RemoveBuild){
        Write-Information "Step 9: Cleaning up build output..."
        Remove-Item -Path $buildGeneset -Recurse -Force
        Write-Host "  ✓ Build output removed" -ForegroundColor Green
    }

    Write-Host "✓ Completed packing: $packTarget" -ForegroundColor Green
    Write-Output $packTarget
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " PACKING COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
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

push-Location $PSScriptRoot
$importSpecs = Get-Content -Raw -Path "import.json" | ConvertFrom-Json
$keys = $importSpecs | ForEach-Object { $_ | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name } | Where-Object {$_ -like $TemplateName}

$resolvedBuildPath = Resolve-Path $BuildPath

if((Test-Path $resolvedBuildPath -PathType Container) -eq $false)
{
    Write-Information "Could not find build path $BuildPath" -ForegroundColor 
    return
}

$keys | ForEach-Object {
    $importSpec = $importSpecs.$_
    $TemplateName = $_
    $buildGeneset = Join-Path $resolvedBuildPath -ChildPath "$TemplateName-stage1\$TemplateName"

    if((Test-Path $buildGeneset -PathType Container) -eq $false)
    {        
        if($IgnoreMissing){
            Write-Information "Could not find build vm in path $buildGeneset"
            return
        }else{
            Write-Error "Could not find build vm in path $buildGeneset"
            exit
        }
    }

    $packTarget = $importSpec.pack
    
    if($null -ne $packTarget)
    {
        $day = Get-Date -Format "yyyyMMdd"
        $packTarget = $packTarget.replace("{date}", $day)
        Write-Information "packing $TemplateName to $packTarget"

        $packTargetPath = "genes\"+ $packTarget.Replace('/', '\\')
        $geneSetPath = split-path $packTargetPath -parent

        if((Test-Path $geneSetPath) -ne $true){
            & eryph-packer geneset init $packTarget --public --workdir genes | Out-Null
        }

        if((Test-Path $packTargetPath) -ne $true){
            & eryph-packer geneset-tag init $packTarget  --workdir genes  | Out-Null
        }
        
        & eryph-packer geneset-tag add-vm $packTarget $buildGeneset  --workdir genes   | Out-Null
        
        # Add rearm-eval fodder for Windows VMs
        if ($importSpec.osType -eq "windows") {
            $catletPath = Join-Path "genes" ($packTarget.Replace('/', '\') + "\catlet.yaml")
            
            # Append fodder section with rearm-eval
            $fodderContent = "`n`nfodder:`n  - source: gene:dbosoft/winconfig:rearm-eval"
            
            Add-Content -Path $catletPath -Value $fodderContent
            Write-Information "Added rearm-eval fodder to Windows VM: $packTarget"
        }
        
        & eryph-packer geneset-tag pack $packTarget --workdir genes   | Out-Null  
        git add $geneSetPath  | Out-Null
    }

    $updateTarget = $importSpec.update

    if($null -ne $updateTarget)
    {
        $updatePath = "genes\"+ $updateTarget.Replace('/', '\\')
        if((Test-Path $updatePath) -ne $true){
            & eryph-packer geneset-tag init $updateTarget --workdir genes
        }
        & eryph-packer geneset-tag ref $updateTarget $packTarget  --workdir genes | Out-Null
        & eryph-packer geneset-tag pack $updateTarget --workdir genes  | Out-Null
    }

    if($RemoveBuild){
        Remove-Item -Path $buildGeneset -Recurse -Force
    }

    Write-Output $packTarget
}
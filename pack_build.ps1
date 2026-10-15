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

Write-Host '========================================' -ForegroundColor Cyan
Write-Host (' PACKING TEMPLATE: ' + $TemplateName) -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

push-Location $PSScriptRoot

Write-Host 'PHASE 1: Initialization' -ForegroundColor Yellow
Write-Host '----------------------------------------' -ForegroundColor Yellow

Write-Information 'Loading import specifications...'
$importSpecs = Get-Content -Raw -Path 'import.json' | ConvertFrom-Json
$keys = $importSpecs | ForEach-Object { $_ | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name } | Where-Object {$_ -like $TemplateName}

if (-not $keys) {
    Write-Error ('Template ' + "'" + $TemplateName + "'" + ' not found in import.json')
    return
}

Write-Information 'Resolving build path...'
$resolvedBuildPath = Resolve-Path $BuildPath

if((Test-Path $resolvedBuildPath -PathType Container) -eq $false)
{
    Write-Error ('Could not find build path: ' + $BuildPath)
    return
}
Write-Information ('Build path: ' + $resolvedBuildPath)

Write-Host ''
Write-Host 'PHASE 2: Processing Templates' -ForegroundColor Yellow
Write-Host '----------------------------------------' -ForegroundColor Yellow

$keys | ForEach-Object {
    $importSpec = $importSpecs.$_
    $TemplateName = $_
    
    Write-Host ''
    Write-Host ('Processing: ' + $TemplateName) -ForegroundColor Magenta
    Write-Host "----------------------------------------" -ForegroundColor Magenta
    
    Write-Information 'Step 1: Locating build output...'
    # Two possible layouts under <template>-stage1, both consumed by
    # `eryph-packer geneset-tag add-vm` (>= v0.6.0):
    #   * cloud-image flow (new): catlet.yaml + metadata.json + <hypervisor>/<arch>/<disk>
    #     directly in the stage1 dir. add-vm reads catlet.yaml as the source of
    #     truth and scans the arch sub-dirs for volumes (vhdx -> hyperv, qcow2 -> kvm).
    #   * Packer flow (legacy): an exported Hyper-V VM in a <template> sub-folder,
    #     alongside vm.json + metadata.json written to the stage1 root by
    #     catletlify.ps1. add-vm must be pointed at the stage1 root (not the
    #     nested export folder): since eryph-packer >= v0.6.0 (#32) dropped the
    #     parent-directory walk, it only searches downward, so vm.json/metadata.json
    #     at the root are missed when targeting the sub-folder (yields an empty
    #     catlet.yaml). Either layout therefore packs from $stage1Path.
    $stage1Path   = Join-Path $resolvedBuildPath -ChildPath ($TemplateName + '-stage1')
    $nestedExport = Join-Path $stage1Path $TemplateName

    if(Test-Path (Join-Path $stage1Path 'catlet.yaml') -PathType Leaf){
        $buildGeneset = $stage1Path
    }elseif(Test-Path $nestedExport -PathType Container){
        $buildGeneset = $stage1Path
    }else{
        $msg = 'Could not find build output: no catlet.yaml in ' + $stage1Path + ' and no VM export at ' + $nestedExport
        if($IgnoreMissing){
            Write-Warning $msg
            return
        }else{
            Write-Error $msg
            exit
        }
    }
    Write-Host ('  OK Found build output at: ' + $buildGeneset) -ForegroundColor Green

    $packTarget = $importSpec.pack
    
    if($null -ne $packTarget)
    {
        Write-Information 'Step 2: Preparing pack target...'
        $day = Get-Date -Format 'yyyyMMdd'
        $packTarget = $packTarget.replace('{date}', $day)

        # Detect same-day conflict and bump tag with -2, -3, ... suffix
        $baseTag = $packTarget
        $suffix = 2
        while(Test-Path ('genes\' + $packTarget.Replace('/', '\'))){
            $packTarget = $baseTag + '-' + $suffix
            $suffix++
        }
        if($packTarget -ne $baseTag){
            Write-Warning ('  Existing tag ' + $baseTag + ' found, using new tag: ' + $packTarget)
        }
        Write-Information ('  Target: ' + $packTarget)

        $packTargetPath = 'genes\' + $packTarget.Replace('/', '\')
        $geneSetPath = split-path $packTargetPath -parent

        Write-Information 'Step 3: Initializing geneset structure...'
        
        # Check for geneset.json file, not just directory
        $genesetJsonPath = Join-Path $geneSetPath "geneset.json"
        if((Test-Path $genesetJsonPath -PathType Leaf) -ne $true){
            Write-Information ('  Creating geneset: ' + $packTarget)
            & eryph-packer geneset init $packTarget --public --workdir genes | Out-Host
            Write-Host '  OK Geneset created' -ForegroundColor Green
        } else {
            Write-Host '  OK Geneset already exists (geneset.json found)' -ForegroundColor Green
        }

        # Check for geneset-tag.json file, not just directory
        $genesetTagJsonPath = Join-Path $packTargetPath "geneset-tag.json"
        if((Test-Path $genesetTagJsonPath -PathType Leaf) -ne $true){
            Write-Information ('  Creating geneset tag: ' + $packTarget)
            & eryph-packer geneset-tag init $packTarget  --workdir genes | Out-Host
            Write-Host '  OK Geneset tag created' -ForegroundColor Green
        } else {
            Write-Host '  OK Geneset tag already exists (geneset-tag.json found)' -ForegroundColor Green
        }

        Write-Information 'Step 4: Adding VM to geneset...'
        & eryph-packer geneset-tag add-vm $packTarget $buildGeneset  --workdir genes | Out-Host
        Write-Host '  OK VM added to geneset' -ForegroundColor Green

        # Sanity check: add-vm must have produced a catlet.yaml with real hardware
        # config. If cpu/memory are missing, add-vm failed to read vm.json (or
        # catlet.yaml) from $buildGeneset and emitted a near-empty config with only
        # volume-scanned drives - the gene would be unusable. This guards against
        # build-output/eryph-packer layout regressions (see #32 parent-walk removal).
        $generatedCatlet = Join-Path $packTargetPath 'catlet.yaml'
        if(Test-Path $generatedCatlet -PathType Leaf){
            $catletText = Get-Content -Raw -Path $generatedCatlet
            if($catletText -notmatch '(?m)^\s*cpu:' -or $catletText -notmatch '(?m)^\s*memory:'){
                Write-Error ("Generated catlet.yaml is missing cpu/memory - add-vm did not pick up the VM config from '" +
                    $buildGeneset + "'. Refusing to pack an empty gene. Generated file: " + $generatedCatlet)
                exit 1
            }
            Write-Host '  OK catlet.yaml contains cpu/memory config' -ForegroundColor Green
        }else{
            Write-Error ('Expected generated catlet.yaml not found at: ' + $generatedCatlet)
            exit 1
        }

        # TEMP: drop unsupported-architecture volumes (e.g. kvm/amd64 qcow2) before packing.
        # The cloud-image build emits volumes for every architecture, but eryph-zero
        # rejects a geneset whose (content-hashed, immutable) manifest references an
        # unsupported architecture. We filter the working .pack/packable.json that
        # `pack` consumes, so the qcow2 is never packed and the manifest only lists
        # supported (hyperv/* and "any") architectures. The build output keeps the
        # qcow2 for future use; this is only about what gets packed for now.
        $packableJsonPath = Join-Path $packTargetPath '.pack\packable.json'
        if (Test-Path $packableJsonPath -PathType Leaf) {
            $packable = @(Get-Content $packableJsonPath -Raw | ConvertFrom-Json)
            $supported = @($packable | Where-Object {
                ($null -eq $_.architecture) -or
                ($_.architecture -eq 'any') -or
                ($_.architecture -like 'hyperv/*')
            })
            $dropped = @($packable | Where-Object { $supported -notcontains $_ })
            if ($dropped.Count -gt 0) {
                Write-Information ('  Excluding unsupported-architecture volumes from pack: ' +
                    (($dropped | ForEach-Object { "$($_.geneName) ($($_.architecture))" }) -join ', ')) -InformationAction Continue
                $supported | ConvertTo-Json -Depth 10 -AsArray | Set-Content -Path $packableJsonPath -NoNewline
                Write-Host '  OK Filtered packable volumes to supported architectures' -ForegroundColor Green
            }
        }
        
        Write-Information 'Step 6: Packing geneset...'
        & eryph-packer geneset-tag pack $packTarget --workdir genes | Out-Host
        Write-Host '  OK Geneset packed successfully' -ForegroundColor Green
        
        Write-Information 'Step 7: Staging for git...'
        git add $geneSetPath  | Out-Null
        Write-Host '  OK Changes staged for git' -ForegroundColor Green
    }

    # import.json lists the tags to point at the new build (e.g. .../latest) as an array
    foreach($updateTarget in @($importSpec.update | Where-Object { $_ }))
    {
        Write-Information ('Step 8: Updating reference ' + $updateTarget + '...')
        $updatePath = 'genes\' + $updateTarget.Replace('/', '\')
        if((Test-Path $updatePath) -ne $true){
            Write-Information ('  Creating update target: ' + $updateTarget)
            & eryph-packer geneset-tag init $updateTarget --workdir genes | Out-Host
        }
        Write-Information ('  Updating reference from ' + $packTarget + ' to ' + $updateTarget)
        & eryph-packer geneset-tag ref $updateTarget $packTarget  --workdir genes | Out-Null
        & eryph-packer geneset-tag pack $updateTarget --workdir genes  | Out-Null
        Write-Host ('  OK ' + $updateTarget + ' updated') -ForegroundColor Green
    }

    if($RemoveBuild){
        Write-Information 'Step 9: Cleaning up build output...'
        Remove-Item -Path $buildGeneset -Recurse -Force
        Write-Host '  OK Build output removed' -ForegroundColor Green
    }

    Write-Host ('OK Completed packing: ' + $packTarget) -ForegroundColor Green
    Write-Output $packTarget
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ' PACKING COMPLETE' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
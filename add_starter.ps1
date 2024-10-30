[CmdletBinding()]
param ()

push-Location $PSScriptRoot
$importSpecs = Get-Content -Raw -Path "import.json" | ConvertFrom-Json

$InformationPreference= 'Continue'
$starterVersion = "1.0"
$keys = $importSpecs | % { $_ | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name }

$keys | % {
    $spec = $importSpecs.$_
    
    $os = $spec."osType"
    $latest = $spec."update"
    
    if($os -eq "windows") {
        $starterContent = gc -raw .\templates\win-starter.yaml
    } else{
        $starterContent = gc -raw .\templates\linux-starter.yaml
    }

    $latestPath = "genes\"+ $latest.Replace('/', '\\')
    if((Test-Path $latestPath) -ne $true){
        Write-Host "Geneset $latest doesn't exists. Skipping starter package initialization";
       
    } else{
    
        $starterContent = $starterContent.Replace("{{parent}}", $latest)
        $starterTarget = $latest.Replace("/latest", "/starter-$starterVersion")
        $starterLatest = $latest.Replace("/latest", "/starter")
        $starterPath = "genes\"+ $starterTarget.Replace('/', '\\')
        $starterLatestPath = "genes\"+ $starterLatest.Replace('/', '\\')

        Write-Host "Building starter package: $starterTarget" -ForegroundColor Green
        
        Write-Host $starterContent 
        
        if((Test-Path $starterPath) -eq $false){
            & eryph-packer geneset-tag init $starterTarget --workdir genes   
        }

        $starterContent | sc -Path $starterPath/catlet.yaml     

        if((Test-Path $starterLatestPath) -eq $false){
            & eryph-packer geneset-tag init $starterLatest --workdir genes   
        }
        & eryph-packer geneset-tag ref $starterLatest $starterTarget --workdir genes   

        & eryph-packer geneset-tag pack $starterLatest --workdir genes   
        & eryph-packer geneset-tag pack $starterTarget --workdir genes   
    
        #& eryph-packer geneset-tag pack catlet $packTarget "genes\temp_starter.yaml" --workdir genes     
        #git add "genes/$packTarget"
        #git stage "genes/$packTarget"
    }
 
}



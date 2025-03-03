
Push-Location $PSScriptRoot

$InformationPreference= 'Continue'
$changedGenesets = Get-ChildItem -Recurse -Directory | Where-Object { $_.Name -eq '.packed' } | 
        Resolve-Path -Relative | 
        ForEach-Object { $_.Replace(".\genes\", "").Replace("\.packed", "").Replace("\", "/")}


Write-Information "Changed Genesets:"
$changedGenesets        
$apikey = $env:ERYPH_APIKEY

$changedGenesets | ForEach-Object {

    $changedGeneset = $_

    if($changedGeneset.EndsWith("next")){
        Write-Host "Skipping 'next' geneset tag '$changedGeneset'"
        return
    }

    
    Write-Host "Pushing geneset-tag $changedGeneset"

    if($apikey){
        Write-Host "Using API-Key for authentication"
       & eryph-packer geneset-tag push $changedGeneset --workdir genes --api-key $apikey
    } else {
       & eryph-packer geneset-tag push $changedGeneset --workdir genes
    }
}
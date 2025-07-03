
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

    
    Write-Host "Can push geneset-tag $changedGeneset"

}
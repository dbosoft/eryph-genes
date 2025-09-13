
param(
    [Parameter(Mandatory=$false)]
    [switch]$Staged
)

Push-Location $PSScriptRoot

$InformationPreference = 'Continue'

# Always start with all .packed directories
$packedGenesets = Get-ChildItem -Recurse -Directory | Where-Object { $_.Name -eq '.packed' } | 
    Resolve-Path -Relative | 
    ForEach-Object { $_.Replace(".\genes\", "").Replace("\.packed", "").Replace("\", "/")}

if ($Staged) {
    Write-Information "Filtering to only staged genesets..."
    # Get staged files from git
    $stagedFiles = & git diff --cached --name-only
    
    # Filter packed genesets to only those with staged changes
    $changedGenesets = $packedGenesets | Where-Object {
        $genesetPath = "genes/$($_.Replace('\', '/'))"
        # Check if any staged files belong to this geneset
        $hasStaged = $stagedFiles | Where-Object { $_ -like "$genesetPath/*" }
        [bool]$hasStaged
    }
} else {
    Write-Information "Using all genesets with .packed directories..."
    $changedGenesets = $packedGenesets
}


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
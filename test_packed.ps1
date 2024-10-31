[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]
    $Geneset,

    [Parameter(Mandatory=$true)]
    [string] $GenepoolPath,

    [string] $OsType
)
$InformationPreference= 'Continue'
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'
$ProgressPreference = "SilentlyContinue"

Import-Module $PSScriptRoot\tests\Eryph.SSH.psm1
$sshKeyPath = "$PSScriptRoot/.ssh/sshkey"
$sshPublicKey = New-SSHKey -KeyFilePath $sshKeyPath

$geneSource = Join-Path $PSScriptRoot "genes" -Resolve
$GenesetSourcePath = Join-Path $geneSource $Geneset.Replace('/', '\')
$GenesetPackagedPath = Join-Path $GenesetSourcePath ".packed" -Resolve
Write-Host "Geneset source path: $GenesetPackagedPath"

$gensetTargetPath = Join-Path $GenepoolPath $Geneset.Replace('/', '\')
Write-Host "Geneset target path: $gensetTargetPath"

if(Test-Path $gensetTargetPath -PathType Container){
    Write-Warning "Removing existing geneset tag from genepool" -InformationAction Continue
    Remove-Item $gensetTargetPath -Recurse -Force
}

if((Test-Path $gensetTargetPath) -eq $false) {
    New-Item -ItemType Directory -Path $gensetTargetPath | Out-Null
}

Copy-Item $GenesetPackagedPath\*  -Destination $gensetTargetPath -Force -Recurse


$template = Get-Content tests\$osType.yaml -Raw

Write-Information "Removing previous test catlet (if any)" -InformationAction Continue
Get-Catlet | Where-Object Name -eq catlettest| Remove-Catlet -Force
$cutTemplate = $template.Replace("{{cut}}", $Geneset)

Write-Information "Building test catlet" -InformationAction Continue
$cut = New-Catlet -Config $cutTemplate  `
        -Variables @{"sshKey" = $sshPublicKey} `
        -SkipVariablesPrompt

Write-Information "Start catlet" -InformationAction Continue
$cut | Start-Catlet -Force

$ipInfo = Get-CatletIp -Id ${cut.Id}
$ip = $ipInfo.IpAddress
$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

do {
    Write-Information "Waiting for connection..." -InformationAction Continue
    Start-Sleep -Seconds 10
    $ping = Test-Connection -ComputerName $ip -Count 1 -Quiet

    if($stopwatch.Elapsed.TotalMinutes -gt 10){
        Write-Error "Timeout waiting for connection"
        exit -1
    }

} until ($ping)


if($OsType -eq "windows"){

    $opt = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
    $plainPassword = "InitialPassw0rd"
    $securePassword = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential("Admin", $securePassword)
    $session = new-PSSession -ComputerName $ip -Credential $Credentials -UseSSL -Authentication Basic -SessionOption $opt

    Invoke-Command -Session $session -scriptblock {
       
        # check if sysprep completed successfully
        $sysprepLog = get-content 'C:\Windows\Temp\sysprep.log'
        $checkPoints = $sysprepLog | Select-String -Pattern "CHECKPOINT"
        
        if($checkPoints -match "CHECKPOINT_04: Shutdown"){
            Write-Output "Sysprep completed successfully"
        }
        else {
            Write-Error "Sysprep failed"
            get-content 'C:\Windows\Temp\sysprep.log' -Raw
            exit -1
        }

        $packerUser = Get-LocalUser packer -ErrorAction SilentlyContinue
        if($packerUser){
            Write-Error "Packer user still exists"
            exit -1
        }
    }
}
else{
    
    do {
        Write-Information "Waiting for bootstrapping to finish..." -InformationAction Continue
        Start-Sleep -Seconds 5
        $finished = Invoke-SSH `
            -Command 'ls /' `
            -Hostname $ip `
            -Username  'admin' `
            -KeyFilePath $sshKeyPath
        if (!$finished) {
            $finished = ""
        }        
    } until ($finished.Length -gt 0)

    Write-Information "Catlet booted and configured" -InformationAction Continue
}

Write-Information "Test for $Geneset completed - cleaning up" -InformationAction Continue
$cut | Remove-Catlet -Force


if(Test-Path $gensetTargetPath -PathType Container){
    Write-Information "Removing tested tag from genepool" -InformationAction Continue
    Remove-Item $gensetTargetPath -Recurse -Force -ErrorAction Continue
}
# Test-FodderGene.Tests.ps1
# Host-side Pester tests for one fodder gene suite on one base OS.
# Validates a PRE-DEPLOYED catlet; Test-FodderGene.ps1 deploys it, waits for
# provisioning and removes it afterwards.

param(
    [Parameter(Mandatory=$true)]
    [string]$Gene,

    [Parameter(Mandatory=$true)]
    [string]$SuiteName,

    [Parameter(Mandatory=$true)]
    [string]$OsVersion,

    [Parameter(Mandatory=$true)]
    [ValidateSet("windows", "linux")]
    [string]$OsType,

    [Parameter(Mandatory=$true)]
    [string]$CatletId,

    [Parameter(Mandatory=$true)]
    [string]$VmId,

    # Result of Wait-ProvisioningComplete: Completed, Failed, Detail
    [Parameter(Mandatory=$true)]
    [hashtable]$Provisioning,

    # @{ Name = '...'; Command = '...'; Expect = 'regex' (optional); ExitCode = 0 (optional) }
    [object[]]$HostTests = @(),

    # In-VM Pester files, relative to GeneTestPath
    [string[]]$InVMTests = @(),

    [Parameter(Mandatory=$true)]
    [string]$GeneTestPath
)

BeforeAll {
    Import-Module $PSScriptRoot\tests\EryphTestHelpers.psm1 -Force
}

Describe "Fodder gene $Gene / $SuiteName on $OsVersion" -Tag "FodderGene" {

    Context "Provisioning" {
        It "Should have the catlet running" {
            (Get-Catlet -Id $CatletId).Status | Should -Be 'Running'
        }

        It "Should have finished provisioning" {
            $Provisioning.Completed | Should -BeTrue -Because $Provisioning.Detail
        }

        It "Should report no provisioning failure" {
            $Provisioning.Failed | Should -BeFalse -Because $Provisioning.Detail
        }
    }

    Context "Host checks" -Skip:($HostTests.Count -eq 0) {
        It "<Name>" -ForEach $HostTests {
            $expectedExitCode = if ($null -ne $_.ExitCode) { [int]$_.ExitCode } else { 0 }
            $result = Invoke-EGSCommandWithExitCode -VmId $VmId -Command $_.Command
            $text = $result.Output -join "`n"

            $result.ExitCode | Should -Be $expectedExitCode -Because "'$($_.Command)' printed:`n$text"
            if ($_.Expect) {
                $text | Should -Match $_.Expect
            }
        }
    }

    Context "In-VM tests" -Skip:($InVMTests.Count -eq 0) {
        BeforeAll {
            $root = if ($OsType -eq 'windows') { 'C:\Tests' } else { '/tmp/tests' }
            $sep = if ($OsType -eq 'windows') { '\' } else { '/' }
            $script:validationPath = "$root${sep}validation"
            $script:runnerPath = "$root${sep}vm-runner.ps1"

            $script:pesterPath = Copy-PesterToVM -VmId $VmId -OsType $OsType
            Copy-FileToVM -VmId $VmId -Source (Join-Path $PSScriptRoot 'tests\vm-runner.ps1') -Target $runnerPath -OsType $OsType | Out-Null
            foreach ($testFile in $InVMTests) {
                $source = Join-Path $GeneTestPath $testFile
                Copy-FileToVM -VmId $VmId -Source $source -Target "$validationPath$sep$(Split-Path $testFile -Leaf)" -OsType $OsType | Out-Null
            }
        }

        It "Should pass the in-VM Pester tests" {
            $shell = if ($OsType -eq 'windows') { 'powershell -NoProfile -ExecutionPolicy Bypass' } else { 'pwsh -NoProfile' }
            $result = Invoke-EGSCommandWithExitCode -VmId $VmId `
                -Command "$shell -File $runnerPath -PesterPath $pesterPath -TestPath $validationPath"
            $text = $result.Output -join "`n"
            $result.Output | ForEach-Object { Write-Host $_ }

            # Parse explicitly: Should -Match overwrites $Matches in Pester's scope.
            $summary = [regex]::Match($text, 'Test Summary: Total=(\d+) Passed=(\d+) Failed=(\d+)')
            $summary.Success | Should -BeTrue -Because "the runner should report a summary (pwsh missing on Linux? add gene:dbosoft/powershell:linux-install to the catlet spec)"
            [int]$summary.Groups[3].Value | Should -Be 0 -Because $text
            [int]$summary.Groups[2].Value | Should -BeGreaterThan 0 -Because "at least one in-VM test should run"
        }
    }
}

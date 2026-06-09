# Validate-BaseOS.Tests.ps1
# Pester tests that run INSIDE Windows base catlets to validate the base OS image.
# Verify sysprep, eryph guest services (egs-service - the cloudbase-init
# replacement, see eryph/guest-services), and general OS configuration.

Describe "Windows Base Catlet Validation" {
    
    Context "Sysprep Validation" {
        It "Should have sysprep log file" {
            $sysprepLogPath = "C:\Windows\Temp\sysprep.log"
            Test-Path $sysprepLogPath | Should -Be $true -Because "Sysprep should create a log file"
        }
        
        It "Should have completed sysprep successfully" {
            $sysprepLogPath = "C:\Windows\Temp\sysprep.log"
            if (Test-Path $sysprepLogPath) {
                $sysprepLog = Get-Content $sysprepLogPath -Raw
                $sysprepLog | Should -Not -BeNullOrEmpty
                $sysprepLog | Should -Match "CHECKPOINT_04: Shutdown" -Because "Sysprep should reach shutdown checkpoint"
                $sysprepLog | Should -Not -Match "ERROR|FAILED" -Because "Sysprep should complete without errors"
            } else {
                Set-ItResult -Skipped -Because "Sysprep log not found"
            }
        }
        
        It "Should not have packer user account" {
            $packerUser = Get-LocalUser -Name packer -ErrorAction SilentlyContinue
            $packerUser | Should -BeNullOrEmpty -Because "Packer user should be removed during image preparation"
        }
        
        It "Should not have packer user profile" {
            $packerProfile = "C:\Users\packer"
            Test-Path $packerProfile | Should -Be $false -Because "Packer user profile should be cleaned up"
        }
    }
    
    Context "Eryph Guest Services Validation" {
        # eryph/guest-services ships egs-service as the cloudbase-init
        # replacement on Windows catlets. This file validates the captured
        # base OS image: binary present, service registered. Runtime checks
        # (state.json, per-script logs, no failed handlers) live in
        # Test-PackedBaseCatlet.Tests.ps1 because they only exist after a
        # catlet has been deployed and provisioned.

        It "Should have egs-service installed" {
            Test-Path "C:\Program Files\eryph\guest-services\bin\egs-service.exe" |
                Should -Be $true -Because "egs-service is the base-catlet provisioning agent"
        }

        It "Should have eryph-guest-services Windows service" {
            $svc = Get-Service -Name eryph-guest-services -ErrorAction SilentlyContinue
            $svc | Should -Not -BeNullOrEmpty
            $svc.StartType | Should -Be 'Automatic'
            # Status can be Running OR Stopped at base-catlet time - sysprep'd
            # images typically capture the service before it has anything to do.
            $svc.Status | Should -BeIn @('Running', 'Stopped')
        }

        It "Should NOT have cloudbase-init installed (replaced by egs-service)" {
            Test-Path "C:\Program Files\Cloudbase Solutions\Cloudbase-Init" |
                Should -Be $false -Because "the eryph-genes Windows pipeline no longer installs cbi"
            Get-Service -Name cloudbase-init -ErrorAction SilentlyContinue |
                Should -BeNullOrEmpty
        }

        It "Should have no pending computer-name rename (SetHostname module idempotent)" {
            # If the SetHostname module's AlreadySet short-circuit is broken, the
            # active and pending registry hostnames diverge and a reboot is queued.
            $active  = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName
            $pending = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'NV Hostname' -ErrorAction SilentlyContinue).'NV Hostname'
            if ($pending) { $pending | Should -Be $active -Because "active and pending hostname must match - no rename queued" }
        }
    }

    Context "Azure VM Agent configuration and gating" {
        # eryph Windows base catlets ship the Azure Windows VM Agent so the same
        # image also works when published to Azure. On eryph/Hyper-V the agent
        # must NOT run - egs-service (the cloudbase-init replacement) does all
        # provisioning - so azure.rb leaves WindowsAzureGuestAgent / RdAgent /
        # WindowsAzureTelemetryService Disabled, and the specialize-pass
        # azure-detect.ps1 enables them only when the SMBIOS asset tag matches
        # Azure. These checks mirror Microsoft's vmassist tool (agent installed,
        # binaries, service state) plus the eryph-specific gating that vmassist,
        # being Azure-only, does not cover. Set shared values in BeforeAll (not at
        # Context top level): Context-body assignments run during Pester discovery
        # and are not reliably visible inside run-phase It blocks.
        BeforeAll {
            $script:azureAssetTag = '7783-7084-3265-9085-8269-3286-77'
            $script:azureSvcs     = @('WindowsAzureGuestAgent', 'RdAgent', 'WindowsAzureTelemetryService')
        }

        It "Should have the Azure VM Agent installed (vmassist: folder + binaries)" {
            Test-Path 'C:\WindowsAzure' | Should -Be $true -Because "the Azure VM Agent creates C:\WindowsAzure"
            @(Get-ChildItem 'C:\WindowsAzure' -Recurse -Filter 'WindowsAzureGuestAgent.exe' -ErrorAction SilentlyContinue).Count |
                Should -BeGreaterThan 0 -Because "WindowsAzureGuestAgent.exe indicates the agent is installed"
            @(Get-ChildItem 'C:\WindowsAzure' -Recurse -Filter 'WaAppAgent.exe' -ErrorAction SilentlyContinue).Count |
                Should -BeGreaterThan 0 -Because "WaAppAgent.exe (RdAgent) indicates the agent is installed"
        }

        It "Should have the guest agent services present (vmassist)" {
            foreach ($name in @('WindowsAzureGuestAgent', 'RdAgent')) {
                Get-Service -Name $name -ErrorAction SilentlyContinue |
                    Should -Not -BeNullOrEmpty -Because "$name must exist when the agent is installed"
            }
        }

        It "Should install the Azure-detection gating script" {
            Test-Path 'C:\Windows\Setup\Scripts\azure-detect.ps1' |
                Should -Be $true -Because "azure-detect.ps1 enables the agent only on Azure"
            (Get-Content 'C:\Windows\Setup\Scripts\azure-detect.ps1' -Raw) |
                Should -Match ([regex]::Escape($script:azureAssetTag)) -Because "the gate keys on the Azure SMBIOS asset tag"
        }

        It "Should be on eryph/Hyper-V, not Azure (asset tag differs)" {
            $tag = (Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue).SMBIOSAssetTag
            $tag | Should -Not -Be $script:azureAssetTag -Because "the test host is eryph/Hyper-V, not Azure"
        }

        It "Should keep Azure agent services Disabled and stopped off-Azure (gate active)" {
            foreach ($name in $script:azureSvcs) {
                $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
                if ($svc) {
                    $svc.StartType | Should -Be 'Disabled' -Because "$name must stay Disabled on eryph/Hyper-V (azure-detect.ps1 enables it only on Azure)"
                    $svc.Status    | Should -Be 'Stopped'  -Because "$name must not run on eryph/Hyper-V"
                }
            }
        }

        It "Should have Azure provisioning enabled in the registry (build sets it for Azure)" {
            $prov = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Azure\Provisioning' -Name 'Enabled' -ErrorAction SilentlyContinue
            $prov.Enabled | Should -Be 1 -Because "azure.rb sets Provisioning\Enabled=1 for the Azure provisioning agent"
        }
    }

    Context "Windows Configuration" {

        
        It "Should have network connectivity" {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
            $adapters | Should -Not -BeNullOrEmpty -Because "Should have at least one active network adapter"
        }
        
        It "Should have correct time zone configured" {
            $timeZone = Get-TimeZone
            $timeZone | Should -Not -BeNullOrEmpty
            # Time zone should be set (not just default)
            $timeZone.Id | Should -Not -BeNullOrEmpty
        }
        
    }
    
    Context "Disk and Storage" {
        It "Should have sufficient free space on C: drive" {
            $disk = Get-PSDrive C
            $freeGB = [math]::Round($disk.Free / 1GB, 2)
            $freeGB | Should -BeGreaterThan 5 -Because "Should have at least 5GB free space"
        }
        
        It "Should have temp directories clean" {
            $tempFiles = Get-ChildItem -Path $env:TEMP -ErrorAction SilentlyContinue
            $packagingFiles = $tempFiles | Where-Object { $_.Name -match "packer|install|setup" }
            $packagingFiles.Count | Should -BeLessOrEqual 5 -Because "Temp directory should be relatively clean"
        }
    }
}
BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\ValhallaToolkits')

    # CI 的 runner 沒有安裝 Hyper-V 模組，Get-VM 完全不存在，Pester 沒有東西可以
    # Mock 就會直接丟 CommandNotFoundException；補一個空樁函式讓 Mock 有目標可以接管。
    if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
        function Get-VM { }
    }

    Import-Module (Join-Path $moduleRoot 'Containers.psm1') -Force
    Import-Module (Join-Path $moduleRoot 'Hosts.psm1') -Force
}

AfterAll {
    Remove-Module Hosts -ErrorAction SilentlyContinue
    Remove-Module Containers -ErrorAction SilentlyContinue
}

Describe 'Get-HyperVHost' {
    It 'keeps only IPv4 addresses and pairs them with the VM name' {
        Mock -CommandName Get-VM -ModuleName Hosts -MockWith {
            [PSCustomObject]@{
                NetworkAdapters = @(
                    [PSCustomObject]@{
                        VMName      = 'vm1'
                        IPAddresses = @('192.168.1.10', 'fe80::1111', '10.0.0.5')
                    }
                )
            }
        }

        $result = Get-HyperVHost

        $result.Count | Should -Be 2
        $result.Ip | Should -Not -Contain 'fe80::1111'
        ($result | Where-Object Ip -eq '192.168.1.10').Name | Should -Be 'vm1'
    }

    It 'returns an empty array (not $null) when there are no VMs' {
        Mock -CommandName Get-VM -ModuleName Hosts -MockWith { }

        $result = Get-HyperVHost

        ($null -eq $result) | Should -BeFalse
        $result.Count | Should -Be 0
    }

    It 'returns a single-element array (not a bare scalar) when exactly one VM/IP is found' {
        Mock -CommandName Get-VM -ModuleName Hosts -MockWith {
            [PSCustomObject]@{
                NetworkAdapters = @([PSCustomObject]@{ VMName = 'vm1'; IPAddresses = @('10.0.0.5') })
            }
        }

        $result = Get-HyperVHost

        $result.GetType().IsArray | Should -BeTrue
        $result.Count | Should -Be 1
    }
}

Describe 'Set-Host' {
    BeforeEach {
        $script:writtenHostFile = @()

        Mock -CommandName Test-Path -ModuleName Hosts -MockWith { $false }
        Mock -CommandName Clear-Content -ModuleName Hosts -MockWith { }
        Mock -CommandName Set-Content -ModuleName Hosts -MockWith { }
        Mock -CommandName Add-Content -ModuleName Hosts -MockWith {
            $script:writtenHostFile += @($Value)
        }
    }

    It 'replaces the content between existing # Host IPs / # End IPs markers' {
        Mock -CommandName Get-Content -ModuleName Hosts -MockWith {
            @(
                '127.0.0.1 localhost',
                '# Host IPs',
                '10.0.0.1 old-entry',
                '# End IPs'
            )
        }

        Set-Host -IPArray @([PSCustomObject]@{ Name = 'web'; Ip = '172.17.0.2' }) -Confirm:$false

        $script:writtenHostFile | Should -Be @(
            '127.0.0.1 localhost',
            '# Host IPs',
            "172.17.0.2`tweb",
            '# End IPs'
        )
    }

    It 'appends a new # Host IPs section when none exists yet' {
        Mock -CommandName Get-Content -ModuleName Hosts -MockWith {
            @('127.0.0.1 localhost', '::1 localhost')
        }

        Set-Host -IPArray @([PSCustomObject]@{ Name = 'web'; Ip = '172.17.0.2' }) -Confirm:$false

        $script:writtenHostFile | Should -Be @(
            '127.0.0.1 localhost',
            '::1 localhost',
            '# Host IPs',
            "172.17.0.2`tweb",
            '# End IPs'
        )
    }

    It 'keeps line boundaries intact even when the untouched content is a single line' {
        Mock -CommandName Get-Content -ModuleName Hosts -MockWith {
            @('127.0.0.1 localhost')
        }

        Set-Host -IPArray @([PSCustomObject]@{ Name = 'web'; Ip = '172.17.0.2' }) -Confirm:$false

        $script:writtenHostFile | Should -Be @(
            '127.0.0.1 localhost',
            '# Host IPs',
            "172.17.0.2`tweb",
            '# End IPs'
        )
    }

    It 'uses the HostAlias.psd1 mapping instead of the raw name when present' {
        Mock -CommandName Test-Path -ModuleName Hosts -MockWith { $true }
        Mock -CommandName Import-PowerShellDataFile -ModuleName Hosts -MockWith {
            @{ 'web' = 'local.api' }
        }
        Mock -CommandName Get-Content -ModuleName Hosts -MockWith {
            @('127.0.0.1 localhost', '::1 localhost')
        }

        Set-Host -IPArray @([PSCustomObject]@{ Name = 'web'; Ip = '172.17.0.2' }) -Confirm:$false

        $script:writtenHostFile | Should -Contain "172.17.0.2`tlocal.api"
    }

    It 'skips entries whose Name is $null' {
        Mock -CommandName Get-Content -ModuleName Hosts -MockWith {
            @('127.0.0.1 localhost', '::1 localhost')
        }

        Set-Host -IPArray @(
            [PSCustomObject]@{ Name = $null; Ip = '172.17.0.9' },
            [PSCustomObject]@{ Name = 'web'; Ip = '172.17.0.2' }
        ) -Confirm:$false

        $script:writtenHostFile | Should -Contain "172.17.0.2`tweb"
        $script:writtenHostFile -join "`n" | Should -Not -Match '172\.17\.0\.9'
    }
}

Describe 'Set-DockerHost / Set-HyperVHost / Set-AllHost' {
    BeforeEach {
        Mock -CommandName Set-Host -ModuleName Hosts -MockWith { }
    }

    It 'Set-DockerHost forwards the container IPs to Set-Host' {
        Mock -CommandName Get-AllContainerIP -ModuleName Hosts -MockWith {
            @([PSCustomObject]@{ Name = 'web'; Ip = '172.17.0.2' })
        }

        Set-DockerHost -Confirm:$false

        Should -Invoke Set-Host -ModuleName Hosts -Times 1 -Exactly -ParameterFilter {
            $IPArray.Count -eq 1 -and $IPArray[0].Name -eq 'web'
        }
    }

    It 'Set-HyperVHost forwards the VM IPs to Set-Host' {
        Mock -CommandName Get-VM -ModuleName Hosts -MockWith {
            [PSCustomObject]@{
                NetworkAdapters = @([PSCustomObject]@{ VMName = 'vm1'; IPAddresses = @('10.0.0.5') })
            }
        }

        Set-HyperVHost -Confirm:$false

        Should -Invoke Set-Host -ModuleName Hosts -Times 1 -Exactly -ParameterFilter {
            $IPArray.Count -eq 1 -and $IPArray[0].Name -eq 'vm1'
        }
    }

    It 'Set-AllHost merges container and VM IPs when there are multiple of each' {
        Mock -CommandName Get-AllContainerIP -ModuleName Hosts -MockWith {
            @(
                [PSCustomObject]@{ Name = 'web'; Ip = '172.17.0.2' },
                [PSCustomObject]@{ Name = 'db'; Ip = '172.17.0.3' }
            )
        }
        Mock -CommandName Get-VM -ModuleName Hosts -MockWith {
            [PSCustomObject]@{
                NetworkAdapters = @([PSCustomObject]@{ VMName = 'vm1'; IPAddresses = @('10.0.0.5', '10.0.0.6') })
            }
        }

        Set-AllHost -Confirm:$false

        Should -Invoke Set-Host -ModuleName Hosts -Times 1 -Exactly -ParameterFilter {
            $IPArray.Count -eq 4
        }
    }

    It 'Set-AllHost does not throw when there is exactly one running container and no VMs' {
        # Regression test：Get-AllContainerIP/Get-HyperVHost 修正前，剛好只有一個容器、
        # 沒有 VM 時，"$ips + $vms" 會因為 $ips 被 PowerShell 攤平成純量而丟出例外。
        # 這裡故意不 mock Get-AllContainerIP/Get-HyperVHost 本身，而是 mock 更底層的
        # docker/Get-VM，讓 Set-AllHost 走完整條真實呼叫鏈來驗證修正有效。
        Mock -CommandName docker -ModuleName Containers -MockWith {
            if ($args[0] -eq 'ps') { return @('container1') }
            if ($args[0] -eq 'inspect') { return '/web,172.17.0.2' }
        }
        Mock -CommandName Get-VM -ModuleName Hosts -MockWith { }

        { Set-AllHost -Confirm:$false } | Should -Not -Throw

        Should -Invoke Set-Host -ModuleName Hosts -Times 1 -Exactly -ParameterFilter {
            $IPArray.Count -eq 1 -and $IPArray[0].Name -eq 'web'
        }
    }
}

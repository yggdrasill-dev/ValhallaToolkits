BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\ValhallaToolkits')
    Import-Module (Join-Path $moduleRoot 'Containers.psm1') -Force
}

AfterAll {
    Remove-Module Containers -ErrorAction SilentlyContinue
}

Describe 'Get-AllContainerIP' {
    It 'parses "docker ps" and "docker inspect" output into Name/Ip objects' {
        Mock -CommandName docker -ModuleName Containers -MockWith {
            if ($args[0] -eq 'ps') {
                return @('container1', 'container2')
            }

            if ($args[0] -eq 'inspect') {
                switch ($args[3]) {
                    'container1' { return '/web,172.17.0.2' }
                    'container2' { return '/db,172.17.0.3' }
                }
            }
        }

        $result = Get-AllContainerIP

        $result.Count | Should -Be 2
        ($result | Where-Object Name -eq 'web').Ip | Should -Be '172.17.0.2'
        ($result | Where-Object Name -eq 'db').Ip | Should -Be '172.17.0.3'
    }

    It 'returns an empty array (not $null) when no containers are running' {
        Mock -CommandName docker -ModuleName Containers -MockWith { }

        $result = Get-AllContainerIP

        ($null -eq $result) | Should -BeFalse
        $result.Count | Should -Be 0
    }

    It 'returns a single-element array (not a bare scalar) when exactly one container is running' {
        Mock -CommandName docker -ModuleName Containers -MockWith {
            if ($args[0] -eq 'ps') {
                return @('container1')
            }

            if ($args[0] -eq 'inspect') {
                return '/web,172.17.0.2'
            }
        }

        $result = Get-AllContainerIP

        $result.GetType().IsArray | Should -BeTrue
        $result.Count | Should -Be 1
        $result[0].Name | Should -Be 'web'
    }
}

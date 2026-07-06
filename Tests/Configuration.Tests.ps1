BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\ValhallaToolkits')
    $script:originalUserProfile = $env:USERPROFILE
    $env:USERPROFILE = $TestDrive
    Import-Module (Join-Path $moduleRoot 'Configuration.psm1') -Force
}

AfterAll {
    Remove-Module Configuration -ErrorAction SilentlyContinue
    $env:USERPROFILE = $script:originalUserProfile
}

Describe 'Write-Configuration / Read-Configuration' {
    It 'round-trips a configuration object through config.json' {
        $config = [PSCustomObject]@{
            Nuget = @{ Source = 'nuget.org'; ApiKey = 'test-key' }
        }

        Write-Configuration -ValhallaConfig $config -Confirm:$false

        $result = Read-Configuration

        $result.Nuget.Source | Should -Be 'nuget.org'
        $result.Nuget.ApiKey | Should -Be 'test-key'
    }

    It 'backs up the previous config.json before overwriting it' {
        $first = [PSCustomObject]@{ Nuget = @{ Source = 'a'; ApiKey = '1' } }
        $second = [PSCustomObject]@{ Nuget = @{ Source = 'b'; ApiKey = '2' } }

        Write-Configuration -ValhallaConfig $first -Confirm:$false
        Write-Configuration -ValhallaConfig $second -Confirm:$false

        $backupPath = Join-Path $TestDrive '.valhalla\config-bak.json'

        Test-Path $backupPath | Should -BeTrue
        (Get-Content $backupPath | ConvertFrom-Json).Nuget.Source | Should -Be 'a'
    }

    It 'returns an empty hashtable when no config.json exists yet' {
        Remove-Item (Join-Path $TestDrive '.valhalla\config.json') -ErrorAction SilentlyContinue
        Remove-Item (Join-Path $TestDrive '.valhalla\config-bak.json') -ErrorAction SilentlyContinue

        Read-Configuration | Should -BeOfType [hashtable]
        (Read-Configuration).Count | Should -Be 0
    }
}

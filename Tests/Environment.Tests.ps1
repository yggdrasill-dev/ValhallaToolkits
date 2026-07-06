BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\ValhallaToolkits')
    Import-Module (Join-Path $moduleRoot 'Environment.psm1') -Force
}

AfterAll {
    Remove-Module Environment -ErrorAction SilentlyContinue
}

Describe 'Update-ShellPath' {
    It 'rebuilds the current session PATH from the Machine and User PATH values' {
        $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

        $expectedEntries = @($machinePath, $userPath) `
        | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } `
        | ForEach-Object { $_ -split ';' } `
        | ForEach-Object { $_.Trim() } `
        | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } `
        | Select-Object -Unique

        $result = Update-ShellPath -PassThru -Confirm:$false

        @($result) | Should -Be @($expectedEntries)
        $env:Path | Should -Be ($expectedEntries -join ';')
    }

    It 'returns nothing when -PassThru is not specified' {
        Update-ShellPath -Confirm:$false | Should -BeNullOrEmpty
    }
}

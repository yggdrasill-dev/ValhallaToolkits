BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\ValhallaToolkits')
    Import-Module (Join-Path $moduleRoot 'git.psm1') -Force
}

AfterAll {
    Remove-Module git -ErrorAction SilentlyContinue
}

Describe 'Get-GitAttributeList' {
    It 'splits the API response into a list of types' {
        Mock -CommandName Invoke-WebRequest -ModuleName git -MockWith {
            [PSCustomObject]@{ Content = 'csharp,visualstudio,windows' }
        }

        Get-GitAttributeList | Should -Be @('csharp', 'visualstudio', 'windows')
    }
}

Describe 'Get-GitAttribute' {
    It 'requests the joined types and returns the raw response content' {
        Mock -CommandName Invoke-WebRequest -ModuleName git -MockWith {
            [PSCustomObject]@{ Content = '*.cs text' }
        } -ParameterFilter { $Uri -eq 'https://gitattributes.io/api/csharp,visualstudio' }

        Get-GitAttribute -Types csharp, visualstudio | Should -Be '*.cs text'
    }
}

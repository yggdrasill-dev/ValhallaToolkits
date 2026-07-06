BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\ValhallaToolkits')
    Import-Module (Join-Path $moduleRoot 'NugetTool.psm1') -Force
}

AfterAll {
    Remove-Module NugetTool -ErrorAction SilentlyContinue
    Remove-Module Configuration -ErrorAction SilentlyContinue
}

Describe 'Get-IncrementVersion' {
    It 'increments Revision when present' {
        Get-IncrementVersion -Version '1.2.3.4' | Should -Be ([version]'1.2.3.5')
    }

    It 'increments Build when only Major.Minor.Build is present' {
        Get-IncrementVersion -Version '1.2.3' | Should -Be ([version]'1.2.4')
    }

    It 'increments Minor when only Major.Minor is present' {
        Get-IncrementVersion -Version '1.2' | Should -Be ([version]'1.3')
    }
}

Describe 'Get-PackageId' {
    It 'reads the PackageId element when present' {
        $csproj = Join-Path $TestDrive 'WithId.csproj'
        Set-Content -Path $csproj -Value @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <PackageId>My.Custom.Package</PackageId>
  </PropertyGroup>
</Project>
'@

        Get-PackageId -ProjectPath $csproj | Should -Be 'My.Custom.Package'
    }

    It 'falls back to the file BaseName when PackageId is missing' {
        $csproj = Join-Path $TestDrive 'NoId.csproj'
        Set-Content -Path $csproj -Value @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
  </PropertyGroup>
</Project>
'@

        Get-PackageId -ProjectPath $csproj | Should -Be 'NoId'
    }
}

Describe 'Get-NugetSource' {
    It 'parses "dotnet nuget list source" output into a name/url hashtable' {
        Mock -CommandName dotnet -ModuleName NugetTool -MockWith {
            @(
                'Registered Sources:',
                '  1.  nuget.org [Enabled]',
                '      https://api.nuget.org/v3/index.json',
                '  2.  Valhalla-PS [Enabled]',
                '      https://www.myget.org/F/valhalla-ps/api/v3/index.json'
            )
        }

        $result = Get-NugetSource

        $result['nuget.org'] | Should -Be 'https://api.nuget.org/v3/index.json'
        $result['Valhalla-PS'] | Should -Be 'https://www.myget.org/F/valhalla-ps/api/v3/index.json'
    }
}

Describe 'Get-NugetMaxVersion' {
    It 'returns the highest non-prerelease version found' {
        Mock -CommandName Get-NugetSource -ModuleName NugetTool -MockWith { @{} }
        Mock -CommandName Find-Package -ModuleName NugetTool -MockWith {
            @(
                [PSCustomObject]@{ Name = 'My.Package'; Version = '1.0.0' },
                [PSCustomObject]@{ Name = 'My.Package'; Version = '1.2.0-alpha' },
                [PSCustomObject]@{ Name = 'My.Package'; Version = '1.1.0' }
            )
        }

        Get-NugetMaxVersion -PackageId 'My.Package' -Source 'nuget.org' | Should -Be ([version]'1.2.0')
    }

    It 'falls back to 0.0.0 when the lookup fails' {
        Mock -CommandName Get-NugetSource -ModuleName NugetTool -MockWith { @{} }
        Mock -CommandName Find-Package -ModuleName NugetTool -MockWith { throw 'boom' }

        Get-NugetMaxVersion -PackageId 'Missing.Package' -Source 'nuget.org' | Should -Be ([version]'0.0.0')
    }
}

function Push-Package {
    param (
        [parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [ValidateScript( { if ($_) { Test-Path $_ } })]
        [string] $Path,
        [string] $Source,
        [string] $ApiKey
    )

    process {
        $ErrorActionPreference = "Stop"

        if ([String]::IsNullOrEmpty($Path) -eq $false) {
            $nugetSources = Get-NugetSource

            $sourceUrl = $Source

            if ($nugetSources.ContainsKey($Source)) {
                $sourceUrl = $nugetSources[$Source]
            }

            $pkgFile = Get-Item $Path

            Find-Package -Source $pkgFile.DirectoryName
            $info = Find-Package -Source $pkgFile.DirectoryName -AllVersions `
            | ? { $_.PackageFilename -eq $pkgFile.Name } `
            | select -First 1

            $maxVersion = Get-NugetMaxVersion -Source $sourceUrl -PackageId $info.Name
            $currentVersion = [Version]($info.Version.Split('-') | Select-Object -First 1)

            if ($currentVersion -le $maxVersion) {
                Write-Error "The package version($currentVersion) lower feed's version($maxVersion)."
            }
            else {
                dotnet nuget push $Path --skip-duplicate -s $Source -k $ApiKey
            }
        }
    }
}

function Get-NugetMaxVersion {
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string] $PackageId,
        [string] $Source
    )

    process {
        $ErrorActionPreference = "Stop"

        Write-Verbose "PackageId: $PackageId"

        try {
            $nugetSources = Get-NugetSource

            $sourceUrl = $Source

            if ($nugetSources.ContainsKey($Source)) {
                $sourceUrl = $nugetSources[$Source]
            }

            if ($sourceUrl -eq '') {
                Remove-Variable sourceUrl
            }

            $measure = Find-Package $PackageId -AllVersions -Source $sourceUrl -AllowPrereleaseVersions `
            | ? { $_.Name -eq $PackageId } `
            | % { [Version]$_.Version.Split('-')[0] } `
            | measure -Maximum

            $maxVersion = $measure.Maximum
        }
        catch {
            $maxVersion = [version]'0.0.0'
        }

        return $maxVersion
    }
}

function Get-IncrementVersion {
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [version] $Version
    )

    process {
        $major = $Version.Major
        $minor = $Version.Minor
        $build = $Version.Build
        $revision = $Version.Revision

        if ($revision -ge 0) {
            return New-Object -TypeName System.Version -ArgumentList $major, $minor, $build, ($revision + 1)
        }
        elseif ($build -ge 0) {
            return New-Object -TypeName System.Version -ArgumentList $major, $minor, ($build + 1)
        }
        else {
            return New-Object -TypeName System.Version -ArgumentList $major, ($minor + 1)
        }
    }
}

function Get-PackageId {
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string] $ProjectPath
    )

    process {
        $projectFile = Get-Item $ProjectPath

        $packageId = Select-Xml -Path $ProjectPath -XPath '//PackageId' `
        | Select-Object -First 1 -ExpandProperty Node | % { $_.InnerXml }

        if ([string]::IsNullOrWhiteSpace($packageId)) {
            $packageId = $projectFile.BaseName
        }

        return $packageId
    }
}

function Push-AlphaPackage {
    param (
        [parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string] $ProjectPath,
        [string] $Configuration = 'Debug',
        [string] $Source,
        [string] $ApiKey
    )

    process {
        $ErrorActionPreference = 'Stop'

        $nugetSources = Get-NugetSource

        $sourceUrl = $Source

        if ($nugetSources.ContainsKey($Source)) {
            $sourceUrl = $nugetSources[$Source]
        }

        $projectFile = Get-Item $ProjectPath
        $projectFolder = $projectFile.Directory.FullName

        $packageId = Get-PackageId -ProjectPath $ProjectPath

        $pushVersion = Get-NugetMaxVersion $packageId -Source $sourceUrl | Get-IncrementVersion

        dotnet pack $ProjectPath -c $Configuration -p:Version="$pushVersion-alpha"

        Push-Package "$projectFolder\bin\$Configuration\$packageId.$pushVersion-alpha.nupkg" -Source $sourceUrl -ApiKey $ApiKey
    }
}

function Get-NugetSource {
    [OutputType([hashtable])]
    Param()

    process {
        $arr = dotnet nuget list source `
        | select -Skip 1 `
        | % { $_.Trim() } `
        | % { $_.Split('[') | select -First 1 } `
        | % { $_ -replace '\d+\.', '' } `
        | % { $_.Trim() }

        $dict = @{}
        for ($i = 0; $i -lt $arr.Count; $i += 2) {
            $dict[$arr[$i]] = $arr[$i + 1]
        }

        return $dict
    }
}
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
            $pkgFile = Get-Item $Path

            Find-Package -Source $pkgFile.DirectoryName
            $info = Find-Package -Source $pkgFile.DirectoryName -AllVersions `
            | ? { $_.PackageFilename -eq $pkgFile.Name } `
            | select -First 1

            $maxVersion = Get-NugetMaxVersion -Source $Source -PackageId $info.Name
            $currentVersion = [Version]($info.Version.Split('-') | Select-Object -First 1)

            if ($currentVersion -le $maxVersion) {
                Write-Error "The package version($currentVersion) lower feed's version($maxVersion)."
            }

            dotnet nuget push $Path --skip-duplicate -s $Source -k $ApiKey
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
        Write-Verbose "PackageId: $PackageId"

        try {
            $measure = Find-Package $PackageId -AllVersions -Source $Source -ProviderName NuGet `
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

        $sessionId = [Guid]::NewGuid()

        $projectFile = Get-Item $ProjectPath
        [xml]$projectDoc = Get-Content $ProjectPath
        $propGroup = $projectDoc.CreateElement('PropertyGroup')

        $packageId = Select-Xml -Path $ProjectPath -XPath '//PackageId' | 
        Select-Object -First 1 -ExpandProperty Node | % { $_.InnerXml }

        if ([string]::IsNullOrWhiteSpace($packageId)) {
            $packageId = $projectFile.BaseName

            $packageIdNode = $projectDoc.CreateElement('PackageId')
            $packageIdNode.InnerText = $packageId

            $propGroup.AppendChild($packageIdNode) | Out-Null
        }

        $assemblyName = Select-Xml -Path $ProjectPath -XPath '//AssemblyName' | 
        Select-Object -First 1 -ExpandProperty Node | % { $_.InnerXml }

        if ([string]::IsNullOrWhiteSpace($assemblyName)) {
            $assemblyNameNode = $projectDoc.CreateElement('AssemblyName')
            $assemblyNameNode.InnerText = $projectFile.BaseName
            $propGroup.AppendChild($assemblyNameNode) | Out-Null
        }

        $projectFolder = $projectFile.Directory.FullName
        $pushVersion = Get-NugetMaxVersion $packageId | Get-IncrementVersion

        $projectTempPath = "$projectFolder\$sessionId$($projectFile.Extension)"

        ($projectDoc | Select-Xml -XPath '//Version').Node.InnerText = "$pushVersion-alpha"

        $projectDoc.DocumentElement.AppendChild($propGroup) | Out-Null

        $projectDoc.Save($projectTempPath)
        Write-Verbose "產生暫存專案檔: $projectTempPath"

        dotnet pack $projectTempPath -c $Configuration

        Remove-Item $projectTempPath
        Push-Package "$projectFolder\bin\$Configuration\$packageId.$pushVersion-alpha.nupkg" -Source $Source -ApiKey $ApiKey
    }
}
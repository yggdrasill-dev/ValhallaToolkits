Import-Module $PSScriptRoot\Configuration.psm1

<#
.SYNOPSIS
設定預設 NuGet 套件來源與 API Key。

.DESCRIPTION
將預設的 NuGet source 與 API Key 寫入 ValhallaToolkits 設定檔，供其他套件推送命令重用。

.PARAMETER Source
要保存的預設 NuGet 來源名稱或 URL。

.PARAMETER ApiKey
對應來源使用的 API Key。

.EXAMPLE
Set-DefaultNugetSource -Source 'https://www.myget.org/F/valhalla-ps/api/v3/index.json' -ApiKey '***'
#>
function Set-DefaultNugetSource {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string] $Source,
        [Parameter(Mandatory)]
        [string] $ApiKey
    )

    process {
        $ErrorActionPreference = 'Stop'

        if (!$PSCmdlet.ShouldProcess('Target', 'Operation')) {
            return;
        }

        $ValhallaConfig.Nuget = @{
            'Source' = $Source
            'ApiKey' = $ApiKey
        }

        Write-Configuration $ValhallaConfig
    }
}

<#
.SYNOPSIS
推送既有的 NuGet 套件檔到指定來源。

.DESCRIPTION
先檢查套件版本是否高於目標來源上的現有最大版本，再使用 dotnet nuget push 上傳套件。

.PARAMETER Path
要推送的 .nupkg 檔案路徑。

.PARAMETER Source
NuGet 來源名稱或 URL；未提供時使用設定檔中的預設值。

.PARAMETER ApiKey
推送套件所需的 API Key；未提供時使用設定檔中的預設值。

.EXAMPLE
Push-Package -Path .\bin\Debug\My.Package.1.2.3.nupkg
#>
function Push-Package {
    param (
        [parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [ValidateScript( { if ($_) { Test-Path $_ } })]
        [string] $Path,
        [string] $Source = $ValhallaConfig.Nuget.Source,
        [string] $ApiKey = $ValhallaConfig.Nuget.ApiKey
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

<#
.SYNOPSIS
查詢指定套件在來源上的最大版本。

.DESCRIPTION
從指定的 NuGet 來源讀取所有版本，忽略 prerelease 後綴比較主版號，並回傳目前可找到的最大版本。

.PARAMETER PackageId
要查詢的套件識別名稱。

.PARAMETER Source
NuGet 來源名稱或 URL；未提供時使用設定檔中的預設值。

.EXAMPLE
Get-NugetMaxVersion -PackageId My.Package

.OUTPUTS
System.Version
#>
function Get-NugetMaxVersion {
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string] $PackageId,
        [string] $Source = $ValhallaConfig.Nuget.Source
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

<#
.SYNOPSIS
將版本號往下一個遞增值推進。

.DESCRIPTION
若有 Revision 就遞增 Revision，否則遞增 Build；若只有 Major.Minor，則遞增 Minor。

.PARAMETER Version
要計算下一個版本的原始版本號。

.EXAMPLE
Get-IncrementVersion -Version 1.2.3

.OUTPUTS
System.Version
#>
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

<#
.SYNOPSIS
從專案檔讀取套件識別名稱。

.DESCRIPTION
優先讀取專案檔中的 PackageId 節點；若未設定，則退回使用專案檔檔名作為套件名稱。

.PARAMETER ProjectPath
要讀取的專案檔路徑。

.EXAMPLE
Get-PackageId -ProjectPath .\src\MyLibrary\MyLibrary.csproj

.OUTPUTS
System.String
#>
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

<#
.SYNOPSIS
建立並推送下一個 alpha 版本的 NuGet 套件。

.DESCRIPTION
自動取得套件識別名稱與目前來源上的最大版本，計算下一個版本號後使用 dotnet pack 建立 alpha 套件並推送。

.PARAMETER ProjectPath
要打包的 .csproj 專案檔路徑。

.PARAMETER Configuration
dotnet pack 使用的組態，預設為 Debug。

.PARAMETER Source
NuGet 來源名稱或 URL；未提供時使用設定檔中的預設值。

.PARAMETER ApiKey
推送套件所需的 API Key；未提供時使用設定檔中的預設值。

.EXAMPLE
Push-AlphaPackage -ProjectPath .\src\MyLibrary\MyLibrary.csproj
#>
function Push-AlphaPackage {
    param (
        [parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string] $ProjectPath,
        [string] $Configuration = 'Debug',
        [string] $Source = $ValhallaConfig.Nuget.Source,
        [string] $ApiKey = $ValhallaConfig.Nuget.ApiKey
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
        $packageVersion = "$pushVersion-alpha"

        dotnet pack $ProjectPath -c $Configuration --version $packageVersion

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

<#
.SYNOPSIS
取得 gitattributes.io 支援的 attribute 類型清單。

.DESCRIPTION
呼叫 gitattributes.io API，回傳可用的 attribute 類型名稱，供後續查詢 .gitattributes 範本使用。

.EXAMPLE
Get-GitAttributeList

.OUTPUTS
System.String[]
#>
function Get-GitAttributeList {
    $response = iwr https://gitattributes.io/api/list

    return $response.Content.Split(',')
}

<#
.SYNOPSIS
下載指定類型對應的 .gitattributes 內容。

.DESCRIPTION
依據提供的類型清單呼叫 gitattributes.io API，回傳可直接寫入 .gitattributes 的文字內容。

.PARAMETER Types
要查詢的 attribute 類型名稱，可一次提供多個。

.EXAMPLE
Get-GitAttribute -Types csharp,visualstudio

.OUTPUTS
System.String
#>
function Get-GitAttribute {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $Types
    )

    $response = iwr https://gitattributes.io/api/$([String]::Join(',', $Types))

    return $response.Content
}
function Get-GitAttributeList {
    $response = iwr https://gitattributes.io/api/list

    return $response.Content.Split(',')
}

function Get-GitAttribute {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string[]] $Types
    )

    $response = iwr https://gitattributes.io/api/$([String]::Join(',', $Types))

    return $response.Content
}
$ConfigPath = "$env:USERPROFILE\.valhalla"

if (!(Test-Path $ConfigPath)) {
    mkdir "$ConfigPath"
}

function Read-Configuration {
    param()

    process {
        $result = @{}

        if (Test-Path "$ConfigPath\config.json") {
            $obj =  gc "$ConfigPath\config.json" | ConvertFrom-Json
            $obj.psobject.properties | % { $result[$_.Name] = $_.Value }
        }

        return $result
    }
}

function Write-Configuration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $ValhallaConfig
    )

    process {
        if (!$PSCmdlet.ShouldProcess('Target', 'Operation')) {
            return;
        }

        if (Test-Path "$ConfigPath\config.json") {
            gc "$ConfigPath\config.json" | Set-Content $ConfigPath\config-bak.json
        }

        ConvertTo-Json $ValhallaConfig | Set-Content "$ConfigPath\config.json"
    }
}

$ValhallaConfig = Read-Configuration

Export-ModuleMember -Function 'Read-Configuration', 'Write-Configuration' -Variable 'ValhallaConfig'

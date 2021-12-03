$local:ConfigPath = "$env:USERPROFILE\.valhalla"

if (!(Test-Path $ConfigPath)) {
    mkdir "$ConfigPath"
}

function Read-Configuration {
    param()

    process {
        if (Test-Path "$ConfigPath\config.json") {
            return gc "$ConfigPath\config.json" | ConvertFrom-Json
        }
        else {
            return @{}
        }
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

$local:ValhallaConfig = @{};

if (Test-Path "$ConfigPath\config.json") {
    $local:ValhallaConfig = Read-Configuration
}

Export-ModuleMember -Function 'Read-Configuration', 'Write-Configuration'

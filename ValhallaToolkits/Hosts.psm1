function Set-DockerHost {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!$PSCmdlet.ShouldProcess('Target', 'Operation')) {
        return;
    }

    $ips = Get-AllContainerIP

    Set-Host -IPArray $ips
}

function Get-HyperVHost {
    $vms = Get-VM | select -ExpandProperty NetworkAdapters `
    | % {
        $vmName = $_.VMName

        $_.IPAddresses `
        | ? {
            [IPAddress]$ip = $_ -as [IPAddress]

            if (($ip -as [bool]) -and $ip.AddressFamily -eq 'InterNetwork') {
                return $true
            }
            else {
                return $false
            }
        } `
        | % {
            [PSCustomObject]@{
                Name = $vmName
                Ip   = $_
            }
        }
    }

    if ($null -eq $vms) {
        $vms = @();
    }

    return $vms
}

function Set-HyperVHost {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!$PSCmdlet.ShouldProcess('Target', 'Operation')) {
        return;
    }

    $vms = Get-HyperVHost

    Set-Host -IPArray $vms
}

function Set-AllHost {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!$PSCmdlet.ShouldProcess('Target', 'Operation')) {
        return;
    }

    $ips = Get-AllContainerIP
    if ($null -eq $ips) {
        $ips = @();
    }

    $vms = Get-HyperVHost
    if ($null -eq $vms) {
        $vms = @();
    }

    Set-Host -IPArray ($ips + $vms)
}

function Set-Host {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject[]]
        $IPArray
    )

    if (!$PSCmdlet.ShouldProcess('Target', 'Operation')) {
        return;
    }

    $null = $IPArray.Count

    $hostFilePath = "$Env:windir\System32\drivers\etc\hosts"
    $replaceDict = @{ }
    $configFilePath = "$($env:USERPROFILE)\HostAlias.psd1"

    if (Test-Path $configFilePath) {
        $replaceDict = Import-PowerShellDataFile $configFilePath
    }

    $startIgnore = $false
    $findTag = $false

    $hostEntries = foreach ($item in $IPArray) {
        if ($null -eq $item.Name) {
            continue
        }

        if ($replaceDict.ContainsKey($item.Name)) {
            "$($item.Ip)`t$($replaceDict[$item.Name])"
        }
        else {
            "$($item.Ip)`t$($item.Name)"
        }
    }

    Get-Content $hostFilePath | Set-Content "$($env:USERPROFILE)\hostBackup"

    $hostContent = Get-Content $hostFilePath | % {
        if (!$startIgnore) {
            $_
        }

        if ($_ -match "# Docker Hosts") {
            $startIgnore = $true
        }

        if ($_ -match "# End Hosts" -and $startIgnore -eq $true) {
            $startIgnore = $false
        }

        if ($_ -match "# Host IPs") {
            $startIgnore = $true
            $findTag = $true
            $hostEntries
        }

        if ($_ -match "# End IPs" -and $startIgnore -eq $true) {
            $_

            $startIgnore = $false
        }

    }

    if ($findTag -eq $false) {
        $hostContent += "# Host IPs"
        $hostContent += $hostEntries
        $hostContent += "# End IPs"
    }

    Clear-Content -Path $hostFilePath

    $hostContent | ac -Encoding:utf8 $hostFilePath
}

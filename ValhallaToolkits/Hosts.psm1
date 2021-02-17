function Set-DockerHosts
{
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!$PSCmdlet.ShouldProcess('Target', 'Operation'))
    {
        return;
    }

    $ips = Get-AllContainerIPs

    Set-Hosts -IPArray $ips
}

function Get-HyperVHosts
{
    $vms = Get-VM | select -ExpandProperty NetworkAdapters `
    | % {
        $vmName = $_.VMName

        $_.IPAddresses `
        | ? {
            [IPAddress]$ip = $_ -as [IPAddress]

            if (($ip -as [bool]) -and $ip.AddressFamily -eq 'InterNetwork')
            {
                return $true
            }
            else
            {
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

    if ($null -eq $vms)
    {
        $vms = @();
    }

    return $vms
}

function Set-HyperVHosts
{
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!$PSCmdlet.ShouldProcess('Target', 'Operation'))
    {
        return;
    }

    $vms = Get-HyperVHosts

    Set-Hosts -IPArray $vms
}

function Set-AllHosts
{
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!$PSCmdlet.ShouldProcess('Target', 'Operation'))
    {
        return;
    }

    $ips = Get-AllContainerIPs
    if ($null -eq $ips)
    {
        $ips = @();
    }

    $vms = Get-HyperVHosts
    if ($null -eq $vms)
    {
        $vms = @();
    }
    
    Set-Hosts -IPArray ($ips + $vms)
}

function Set-Hosts
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject[]]$IPArray
    )

    if (!$PSCmdlet.ShouldProcess('Target', 'Operation'))
    {
        return;
    }

    $hostFilePath = "$Env:windir\System32\drivers\etc\hosts"
    $replaceDict = @{ }
    $configFilePath = "$($env:USERPROFILE)\HostAlias.psd1"

    if (Test-Path $configFilePath)
    {
        $replaceDict = Import-PowerShellDataFile $configFilePath
    }

    $startIgnore = $false

    Get-Content $hostFilePath | Set-Content "$($env:USERPROFILE)\hostBackup"

    $hostContent = Get-Content $hostFilePath | % {
        if (!$startIgnore)
        {
            $_
        }

        if ($_ -match "# Docker Hosts")
        {
            $startIgnore = $true
            $IPArray `
            | ? { $null -ne $_.Name } `
            | % {
                if ($replaceDict.ContainsKey($_.Name))
                {
                    "$($_.Ip)`t$($replaceDict[$_.Name])"
                }
                else
                {
                    "$($_.Ip)`t$($_.Name)"
                }
            }
        }

        if ($_ -match "# End Hosts" -and $startIgnore -eq $true)
        {
            $_

            $startIgnore = $false
        }
    }

    Clear-Content -Path $hostFilePath

    $hostContent | ac -Encoding:utf8 $hostFilePath
}
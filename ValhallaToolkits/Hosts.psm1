<#
.SYNOPSIS
將 Docker 容器名稱與 IP 同步到 Windows hosts 檔。

.DESCRIPTION
先讀取目前 Docker 容器 IP，再交由內部的 Set-Host 邏輯更新 hosts 檔中的管理區段。

.EXAMPLE
Set-DockerHost
#>
function Set-DockerHost {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!$PSCmdlet.ShouldProcess('Target', 'Operation')) {
        return;
    }

    $ips = Get-AllContainerIP

    Set-Host -IPArray $ips
}

<#
.SYNOPSIS
列出 Hyper-V 虛擬機器的 IPv4 位址。

.DESCRIPTION
讀取 Hyper-V VM 的網路介面，篩出 IPv4 位址後，回傳包含 Name 與 Ip 欄位的物件集合。

.EXAMPLE
Get-HyperVHost

.OUTPUTS
System.Management.Automation.PSCustomObject[]
#>
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

<#
.SYNOPSIS
將 Hyper-V 虛擬機器名稱與 IP 同步到 Windows hosts 檔。

.DESCRIPTION
先讀取目前 Hyper-V VM 的 IPv4 位址，再交由內部的 Set-Host 邏輯更新 hosts 檔中的管理區段。

.EXAMPLE
Set-HyperVHost
#>
function Set-HyperVHost {
    [CmdletBinding(SupportsShouldProcess)]
    Param()

    if (!$PSCmdlet.ShouldProcess('Target', 'Operation')) {
        return;
    }

    $vms = Get-HyperVHost

    Set-Host -IPArray $vms
}

<#
.SYNOPSIS
同時將 Docker 與 Hyper-V 的名稱與 IP 同步到 Windows hosts 檔。

.DESCRIPTION
整合 Docker 容器與 Hyper-V 虛擬機器的位址資訊，並用同一段 hosts 管理邏輯寫入 Windows hosts 檔。

.EXAMPLE
Set-AllHost
#>
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

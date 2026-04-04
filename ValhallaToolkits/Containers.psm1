<#
.SYNOPSIS
列出目前 Docker 容器的名稱與 IP 位址。

.DESCRIPTION
讀取 Docker 執行中的容器，並回傳包含 Name 與 Ip 欄位的物件集合，方便後續同步 hosts 或做其他處理。

.EXAMPLE
Get-AllContainerIP

.OUTPUTS
System.Management.Automation.PSCustomObject[]
#>
function Get-AllContainerIP
{
    $format = '{{.Name}},{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

    $containers = docker ps -q `
    | % { docker inspect -f $format $_ } `
    | % {
        $a = $_.Trim('/').Split(',');
        $ret = [PSCustomObject]@{
            Name = $a[0]
            Ip   = $a[1]
        };

        return $ret;
    }

    if ($null -eq $containers)
    {
        $containers = @();
    }

    return $containers;
}

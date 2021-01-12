function Get-AllContainerIPs
{
    $format = '{{.Name}},{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

    $containers = docker inspect -f $format $(docker ps -q) `
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

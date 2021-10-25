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

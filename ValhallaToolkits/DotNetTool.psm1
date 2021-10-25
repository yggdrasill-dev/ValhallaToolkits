function Update-AllDotNetTool {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (!$PSCmdlet.ShouldProcess('Target', 'Operation')) {
        return;
    }

    foreach ($package in $(dotnet tool list --global | Select-Object -Skip 2)) {
        Write-Output "dotnet tool update --global $($package.Split(" ", 2)[0])"
        dotnet tool update --global $($package.Split(" ", 2)[0])
    }
}
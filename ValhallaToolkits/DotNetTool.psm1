function Update-AllDotNetTool {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch] $Local
    )

    process {
        if (!$PSCmdlet.ShouldProcess('Target', 'Operation')) {
            return;
        }

        if($Local -eq $true) {
            foreach ($package in $(dotnet tool list | Select-Object -Skip 2)) {
                Write-Output "dotnet tool update $($package.Split(" ", 2)[0])"
                dotnet tool update --global $($package.Split(" ", 2)[0])
            }
        }
        else {
            foreach ($package in $(dotnet tool list --global | Select-Object -Skip 2)) {
                Write-Output "dotnet tool update --global $($package.Split(" ", 2)[0])"
                dotnet tool update --global $($package.Split(" ", 2)[0])
            }
        }
    }
}

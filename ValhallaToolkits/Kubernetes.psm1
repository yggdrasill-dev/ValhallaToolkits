function Set-MergeKubeconfig {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        # 新的Kubeconfig yaml
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $NewKubeConfig
    )

    process {
        Copy-Item -Path "$env:UserProfile\.kube\config" -Destination "$env:UserProfile\.kube\config.bak" -Force

        $env:KUBECONFIG = "$env:UserProfile\.kube\config;$NewKubeConfig"

        kubectl config view --flatten > "$env:UserProfile\.kube\config.tmp"

        Remove-Item "$env:UserProfile\.kube\config"
        Rename-Item "$env:UserProfile\.kube\config.tmp" "$env:UserProfile\.kube\config"
    }
}

New-Alias -Name Merge-Kubeconfig -Value Set-MergeKubeconfig

Export-ModuleMember -Alias * -Function *

function Set-MergeKubeconfig {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        # 新的Kubeconfig yaml
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $NewKubeConfig
    )

    process {
        $ErrorActionPreference = 'Stop'

        Copy-Item -Path "$env:UserProfile\.kube\config" -Destination "$env:UserProfile\.kube\config.bak" -Force

        $env:KUBECONFIG = "$env:UserProfile\.kube\config;$NewKubeConfig"

        kubectl config view --flatten > "$env:UserProfile\.kube\config.tmp"

        Remove-Item "$env:UserProfile\.kube\config"
        Rename-Item "$env:UserProfile\.kube\config.tmp" "$env:UserProfile\.kube\config"
    }
}

function Export-Kubeconfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Namespace,
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $AccountName
    )

    process {
        $ErrorActionPreference = 'Stop'

        $userTokenName = kubectl -n $Namespace get sa $AccountName -o=jsonpath='{.secrets[0].name}'
        $userTokenValue = [System.Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String(
                $(kubectl -n $Namespace get secret/$userTokenName -o=go-template='{{.data.token}}')))

        $currentConfig = kubectl config view --raw --minify | ConvertFrom-Yaml
        $generateConfig = @"
        {
            "apiVersion": "v1",
            "kind": "Config",
            "current-context": "$($currentConfig["current-context"])",
            "contexts":[
                {
                    "name": "$($currentConfig['current-context'])",
                    "context": {
                        "cluster": "$($currentConfig["current-context"])",
                        "user": "$AccountName",
                        "namespace": "$Namespace"
                    }
                }
            ],
            "clusters":[
                {
                    "name": "$($currentConfig['current-context'])",
                    "cluster": {
                        "certificate-authority-data": "$($currentConfig.clusters[0].cluster['certificate-authority-data'])",
                        "server": "$($currentConfig.clusters[0].cluster['server'])"
                    }
                }
            ],
            "users": [
                {
                    "name": "$AccountName",
                    "user": {
                        "token": "$userTokenValue"
                    }
                }
            ]
        }
"@ `
        | ConvertFrom-Json

        return ConvertTo-Yaml $generateConfig
    }
}

function Export-CurrentKubeconfig {
    process {
        return $(kubectl config view --raw --minify)
    }
}

function Switch-KubeContext {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Context
    )

    process {
        kubectl config use-context $Context
    }
}

function Switch-KubeNamespace {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Namespace
    )

    process {
        kubectl config set-context --current --namespace=$Namespace
    }
}

New-Alias -Name Merge-Kubeconfig -Value Set-MergeKubeconfig

Export-ModuleMember -Alias * -Function *

<#
.SYNOPSIS
將新的 kubeconfig 合併到目前使用者的 kubeconfig。

.DESCRIPTION
備份目前的 kubeconfig，暫時設定 KUBECONFIG 環境變數後執行 kubectl config view --flatten，最後將合併結果寫回使用者設定檔。

.PARAMETER NewKubeConfig
要合併進目前設定的 kubeconfig 檔案路徑。

.EXAMPLE
Set-MergeKubeconfig -NewKubeConfig .\other-kubeconfig.yaml
#>
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

        $hasKubeConfig = Test-Path -Path ENV:\KUBECONFIG
        if($hasKubeConfig) {
            $originConfig = $env:KUBECONFIG
        }

        $env:KUBECONFIG = "$env:UserProfile\.kube\config;$NewKubeConfig"

        kubectl config view --flatten > "$env:UserProfile\.kube\config.tmp"

        Remove-Item "$env:UserProfile\.kube\config"
        Rename-Item "$env:UserProfile\.kube\config.tmp" "$env:UserProfile\.kube\config"

        if($hasKubeConfig) {
            $env:KUBECONFIG = $originConfig
        }
        else {
            ri ENV:\KUBECONFIG
        }
    }
}

<#
.SYNOPSIS
使用 service account secret 匯出 kubeconfig。

.DESCRIPTION
從指定 namespace 的 service account 讀取 token，搭配目前 kubectl context 的叢集資訊，產生可直接使用的 kubeconfig YAML。

.PARAMETER Namespace
service account 所在的 Kubernetes namespace。

.PARAMETER AccountName
要匯出憑證的 service account 名稱。

.PARAMETER ContextName
輸出的 context 名稱；未提供時沿用目前 kubectl context。

.EXAMPLE
Export-KubeconfigFromSecret -Namespace dev -AccountName deploy-bot

.OUTPUTS
System.String
#>
function Export-KubeconfigFromSecret {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Namespace,
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $AccountName,
        [Parameter(ValueFromPipeline)]
        [string] $ContextName = ''
    )

    process {
        $ErrorActionPreference = 'Stop'

        $userTokenName = kubectl -n $Namespace get sa $AccountName -o=jsonpath='{.secrets[0].name}'
        $userTokenValue = [System.Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String(
                $(kubectl -n $Namespace get secret/$userTokenName -o=go-template='{{.data.token}}')))

        $currentConfig = kubectl config view --raw --minify | ConvertFrom-Yaml
        $configContextName = $currentConfig['current-context']
        if ($ContextName -ne '') {
            $configContextName = $ContextName
        }

        $generateConfig = @"
        {
            "apiVersion": "v1",
            "kind": "Config",
            "current-context": "$configContextName",
            "contexts":[
                {
                    "name": "$configContextName",
                    "context": {
                        "cluster": "$configContextName",
                        "user": "$AccountName",
                        "namespace": "$Namespace"
                    }
                }
            ],
            "clusters":[
                {
                    "name": "$configContextName",
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

<#
.SYNOPSIS
使用 kubectl create token 匯出 kubeconfig。

.DESCRIPTION
直接為指定的 service account 建立一個帶有效期的 token，並搭配目前 kubectl context 的叢集資訊產生 kubeconfig YAML。

.PARAMETER Namespace
service account 所在的 Kubernetes namespace。

.PARAMETER AccountName
要匯出憑證的 service account 名稱。

.PARAMETER ContextName
輸出的 context 名稱；未提供時沿用目前 kubectl context。

.PARAMETER Duration
kubectl create token 使用的 token 有效期限，預設為 87600h。

.EXAMPLE
Export-KubeconfigFromToken -Namespace dev -AccountName deploy-bot -Duration 24h

.OUTPUTS
System.String
#>
function Export-KubeconfigFromToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Namespace,
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $AccountName,
        [Parameter(ValueFromPipeline)]
        [string] $ContextName = '',
        [Parameter(ValueFromPipeline)]
        [string] $Duration = '87600h'
    )

    process {
        $ErrorActionPreference = 'Stop'

        $userTokenValue = kubectl -n $Namespace create token $AccountName --duration $Duration

        $currentConfig = kubectl config view --raw --minify | ConvertFrom-Yaml
        $configContextName = $currentConfig['current-context']
        if ($ContextName -ne '') {
            $configContextName = $ContextName
        }

        $generateConfig = @"
        {
            "apiVersion": "v1",
            "kind": "Config",
            "current-context": "$configContextName",
            "contexts":[
                {
                    "name": "$configContextName",
                    "context": {
                        "cluster": "$configContextName",
                        "user": "$AccountName",
                        "namespace": "$Namespace"
                    }
                }
            ],
            "clusters":[
                {
                    "name": "$configContextName",
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

<#
.SYNOPSIS
匯出目前 kubectl context 的 kubeconfig。

.DESCRIPTION
讀取目前 shell 所使用的 kubectl context，並回傳經過 --raw --minify 處理後的 kubeconfig 內容。

.EXAMPLE
Export-CurrentKubeconfig

.OUTPUTS
System.String
#>
function Export-CurrentKubeconfig {
    process {
        return $(kubectl config view --raw --minify)
    }
}

<#
.SYNOPSIS
切換目前 kubectl context。

.DESCRIPTION
呼叫 kubectl config use-context，將目前 shell 使用的 Kubernetes context 切換到指定名稱。

.PARAMETER Context
要切換到的 context 名稱。

.EXAMPLE
Switch-KubeContext -Context dev-cluster
#>
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

<#
.SYNOPSIS
切換目前 kubectl context 的預設 namespace。

.DESCRIPTION
呼叫 kubectl config set-context --current，更新目前 context 的預設 namespace。

.PARAMETER Namespace
要設定為預設值的 namespace 名稱。

.EXAMPLE
Switch-KubeNamespace -Namespace backend
#>
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

BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..\ValhallaToolkits')
    Import-Module (Join-Path $moduleRoot 'Kubernetes.psm1') -Force
}

AfterAll {
    Remove-Module Kubernetes -ErrorAction SilentlyContinue
}

Describe 'Switch-KubeContext' {
    It 'calls kubectl config use-context with the given context' {
        Mock -CommandName kubectl -ModuleName Kubernetes -MockWith { }

        Switch-KubeContext -Context 'dev-cluster'

        Should -Invoke kubectl -ModuleName Kubernetes -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -eq 'config use-context dev-cluster'
        }
    }
}

Describe 'Switch-KubeNamespace' {
    It 'calls kubectl config set-context --current with the given namespace' {
        Mock -CommandName kubectl -ModuleName Kubernetes -MockWith { }

        Switch-KubeNamespace -Namespace 'backend'

        Should -Invoke kubectl -ModuleName Kubernetes -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -eq 'config set-context --current --namespace=backend'
        }
    }
}

Describe 'Export-CurrentKubeconfig' {
    It 'returns the raw minified kubeconfig from kubectl' {
        Mock -CommandName kubectl -ModuleName Kubernetes -MockWith { 'raw-config-yaml' }

        Export-CurrentKubeconfig | Should -Be 'raw-config-yaml'

        Should -Invoke kubectl -ModuleName Kubernetes -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -eq 'config view --raw --minify'
        }
    }
}

Describe 'Export-Kubeconfig2' {
    It 'builds a kubeconfig using a kubectl-created token' {
        Mock -CommandName kubectl -ModuleName Kubernetes -MockWith {
            $joined = $args -join ' '

            if ($joined -like '*create token*') {
                return 'fake-token-value'
            }

            if ($joined -like '*config view*') {
                return @'
current-context: dev-cluster
clusters:
- name: dev-cluster
  cluster:
    certificate-authority-data: ZmFrZS1jYQ==
    server: https://dev.example.com
'@
            }
        }

        $result = Export-Kubeconfig2 -Namespace dev -AccountName deploy-bot -Duration 1h
        $parsed = $result | ConvertFrom-Yaml

        $parsed.'current-context' | Should -Be 'dev-cluster'
        $parsed.users[0].user.token | Should -Be 'fake-token-value'
        $parsed.clusters[0].cluster.server | Should -Be 'https://dev.example.com'
        $parsed.contexts[0].context.namespace | Should -Be 'dev'

        Should -Invoke kubectl -ModuleName Kubernetes -Times 1 -Exactly -ParameterFilter {
            ($args -join ' ') -eq "-n dev create token deploy-bot --duration 1h"
        }
    }

    It 'uses the given ContextName instead of the current context when provided' {
        Mock -CommandName kubectl -ModuleName Kubernetes -MockWith {
            $joined = $args -join ' '

            if ($joined -like '*create token*') {
                return 'fake-token-value'
            }

            if ($joined -like '*config view*') {
                return @'
current-context: dev-cluster
clusters:
- name: dev-cluster
  cluster:
    certificate-authority-data: ZmFrZS1jYQ==
    server: https://dev.example.com
'@
            }
        }

        $result = Export-Kubeconfig2 -Namespace dev -AccountName deploy-bot -ContextName custom-context
        $parsed = $result | ConvertFrom-Yaml

        $parsed.'current-context' | Should -Be 'custom-context'
    }
}

Describe 'Export-Kubeconfig' {
    It 'builds a kubeconfig using the service account secret token' {
        Mock -CommandName kubectl -ModuleName Kubernetes -MockWith {
            $joined = $args -join ' '

            if ($joined -like '*get sa*') {
                return 'deploy-bot-token-abc123'
            }

            if ($joined -like '*get secret*') {
                return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('fake-token-value'))
            }

            if ($joined -like '*config view*') {
                return @'
current-context: dev-cluster
clusters:
- name: dev-cluster
  cluster:
    certificate-authority-data: ZmFrZS1jYQ==
    server: https://dev.example.com
'@
            }
        }

        $result = Export-Kubeconfig -Namespace dev -AccountName deploy-bot
        $parsed = $result | ConvertFrom-Yaml

        $parsed.'current-context' | Should -Be 'dev-cluster'
        $parsed.users[0].user.token | Should -Be 'fake-token-value'
    }
}

Describe 'Set-MergeKubeconfig' {
    BeforeEach {
        $script:originalUserProfile = $env:UserProfile
        $env:UserProfile = $TestDrive

        New-Item -ItemType Directory -Path (Join-Path $TestDrive '.kube') -Force | Out-Null
        Set-Content -Path (Join-Path $TestDrive '.kube\config') -Value 'existing-config'

        Mock -CommandName kubectl -ModuleName Kubernetes -MockWith { 'merged-config-yaml' }
    }

    AfterEach {
        $env:UserProfile = $script:originalUserProfile
        Remove-Item Env:\KUBECONFIG -ErrorAction SilentlyContinue
    }

    It 'merges the new kubeconfig and leaves KUBECONFIG unset if it was unset before' {
        Remove-Item Env:\KUBECONFIG -ErrorAction SilentlyContinue

        Set-MergeKubeconfig -NewKubeConfig 'C:\fake\other-kubeconfig.yaml' -Confirm:$false

        (Test-Path Env:\KUBECONFIG) | Should -BeFalse
        Get-Content (Join-Path $TestDrive '.kube\config') | Should -Be 'merged-config-yaml'
        Get-Content (Join-Path $TestDrive '.kube\config.bak') | Should -Be 'existing-config'
    }

    It 'restores a previously-set KUBECONFIG afterwards' {
        $env:KUBECONFIG = 'C:\previous\kubeconfig.yaml'

        Set-MergeKubeconfig -NewKubeConfig 'C:\fake\other-kubeconfig.yaml' -Confirm:$false

        $env:KUBECONFIG | Should -Be 'C:\previous\kubeconfig.yaml'
    }
}

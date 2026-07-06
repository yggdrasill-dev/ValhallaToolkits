BeforeAll {
    $script:manifestPath = Resolve-Path (Join-Path $PSScriptRoot '..\ValhallaToolkits\ValhallaToolkits.psd1')
}

Describe 'ValhallaToolkits module manifest' {
    It 'is a valid module manifest' {
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
    }

    It 'declares every command referenced in the README command overview' {
        $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        $exported = $manifest.ExportedFunctions.Keys + $manifest.ExportedAliases.Keys

        $expected = @(
            'Get-AllContainerIP', 'Get-HyperVHost', 'Set-DockerHost', 'Set-HyperVHost', 'Set-AllHost',
            'Update-ShellPath', 'Get-GitAttributeList', 'Get-GitAttribute', 'Push-Package',
            'Get-NugetMaxVersion', 'Get-IncrementVersion', 'Push-AlphaPackage', 'Get-PackageId',
            'Set-DefaultNugetSource', 'Set-MergeKubeconfig', 'Export-Kubeconfig', 'Export-Kubeconfig2',
            'Export-CurrentKubeconfig', 'Switch-KubeContext', 'Switch-KubeNamespace', 'Merge-Kubeconfig'
        )

        foreach ($command in $expected) {
            $exported | Should -Contain $command
        }
    }
}

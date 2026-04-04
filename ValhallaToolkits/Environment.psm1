<#
.SYNOPSIS
重新載入目前 shell 的 PATH 環境變數。

.DESCRIPTION
從 Windows 的 Machine 與 User 環境變數重新組合 PATH，更新目前 PowerShell session 的 PATH，讓新安裝且已寫入系統環境變數的工具可在目前 shell 中被找到。

.EXAMPLE
Update-ShellPath

.EXAMPLE
Update-ShellPath -PassThru

.OUTPUTS
System.String[]
#>
function Update-ShellPath {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch] $PassThru
    )

    process {
        $ErrorActionPreference = 'Stop'

        if (!$PSCmdlet.ShouldProcess('Current shell PATH', 'Reload from machine and user environment variables')) {
            return
        }

        $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

        $pathEntries = @($machinePath, $userPath) `
        | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } `
        | ForEach-Object { $_ -split ';' } `
        | ForEach-Object { $_.Trim() } `
        | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } `
        | Select-Object -Unique

        $env:Path = $pathEntries -join ';'

        if ($PassThru) {
            return $pathEntries
        }
    }
}
# ValhallaToolkits

ValhallaToolkits 是一組以 PowerShell 撰寫的開發輔助命令，包含 Docker 與 Hyper-V hosts 管理、目前 shell PATH 更新、NuGet 套件推送、Git attributes 查詢，以及 Kubernetes kubeconfig 操作。

## 快速開始

先註冊 Valhalla-PS repository（若已存在可略過）：

```powershell
if (-not (Get-PSResourceRepository -Name 'Valhalla-PS' -ErrorAction SilentlyContinue)) {
    Register-PSResourceRepository -Name 'Valhalla-PS' -Uri 'https://www.myget.org/F/valhalla-ps/api/v3/index.json' -Trusted
}
```

註冊完成後即可安裝：

```powershell
Install-PSResource -Name ValhallaToolkits -Repository Valhalla-PS
```

要更新到新版本時，直接重新執行 `Install-PSResource` 即可（新版本會安裝到獨立的版本資料夾，不會覆蓋舊版）：

```powershell
Install-PSResource -Name ValhallaToolkits -Repository Valhalla-PS
Import-Module ValhallaToolkits -Force
```

想清掉舊版本可以用：

```powershell
Uninstall-PSResource -Name ValhallaToolkits -Version '<舊版號，例如 0.0.28>'
```

> 上述指令使用 `Microsoft.PowerShell.PSResourceGet`（PowerShellGet v3），取代已過時的 `PowerShellGet` v2（`Register-PSRepository`/`Install-Module`）。如果你的環境還沒裝這個模組：`Install-Module Microsoft.PowerShell.PSResourceGet -Force -Scope CurrentUser`。

Valhalla-PS 套件來源：

- https://www.myget.org/F/valhalla-ps/api/v3/index.json

安裝後載入並查看可用命令：

```powershell
Import-Module ValhallaToolkits
Get-Command -Module ValhallaToolkits
```

如果你是從原始碼開發，也可以直接從本機路徑載入：

```powershell
Import-Module .\ValhallaToolkits\ValhallaToolkits.psd1
```

## 前置需求

- PowerShell
- dotnet CLI：NuGet 與 .NET tool 相關命令需要
- Docker CLI：容器 IP 與 hosts 同步命令需要
- Hyper-V PowerShell 模組：Hyper-V 主機 IP 查詢需要
- kubectl：Kubernetes 命令需要
- 可寫入 hosts 檔案的權限：hosts 同步命令通常需要系統管理員權限

## 設定檔

模組設定會寫入使用者目錄下的 `.valhalla\config.json`，路徑邏輯可見 [ValhallaToolkits/Configuration.psm1](ValhallaToolkits/Configuration.psm1#L1)。目前主要用來保存 NuGet 預設來源與 API Key。

設定 NuGet 預設來源：

```powershell
Set-DefaultNugetSource -Source 'https://www.myget.org/F/valhalla-ps/api/v3/index.json' -ApiKey '<your-api-key>'
```

如果你想自訂 hosts 顯示名稱，可在使用者目錄建立 `HostAlias.psd1`：

```powershell
@{
    'container-name' = 'local.api'
    'vm-name' = 'local.vm'
}
```

## 命令總覽

### Containers / Hosts

#### Get-AllContainerIP

用途：列出目前 Docker 容器名稱與 IP。

```powershell
Get-AllContainerIP
```

輸出是含有 `Name` 與 `Ip` 欄位的物件集合，實作在 [ValhallaToolkits/Containers.psm1](ValhallaToolkits/Containers.psm1#L1)。

#### Get-HyperVHost

用途：列出 Hyper-V VM 的 IPv4 位址。

```powershell
Get-HyperVHost
```

輸出是含有 `Name` 與 `Ip` 欄位的物件集合，實作在 [ValhallaToolkits/Hosts.psm1](ValhallaToolkits/Hosts.psm1#L14)。

#### Set-DockerHost

用途：將 Docker 容器名稱與 IP 寫入 Windows hosts 檔。

```powershell
Set-DockerHost
```

#### Set-HyperVHost

用途：將 Hyper-V VM 名稱與 IP 寫入 Windows hosts 檔。

```powershell
Set-HyperVHost
```

#### Set-AllHost

用途：同時將 Docker 與 Hyper-V 的名稱/IP 同步到 Windows hosts 檔。

```powershell
Set-AllHost
```

#### hosts 同步行為

- hosts 更新實作在 [ValhallaToolkits/Hosts.psm1](ValhallaToolkits/Hosts.psm1#L79)
- 會先備份原始 hosts 到使用者目錄下的 `hostBackup`
- 會在 hosts 中使用 `# Host IPs` 與 `# End IPs` 區段管理內容
- 若有 `HostAlias.psd1`，會以對應名稱寫入，而不是直接使用容器或 VM 名稱

### Git

#### Get-GitAttributeList

用途：取得 gitattributes.io 支援的 attribute 類型清單。

```powershell
Get-GitAttributeList
```

#### Get-GitAttribute

用途：依類型下載對應的 `.gitattributes` 內容。

```powershell
Get-GitAttribute -Types csharp,visualstudio
```

實作在 [ValhallaToolkits/git.psm1](ValhallaToolkits/git.psm1#L1)。

### Environment

#### Update-ShellPath

用途：重新載入目前 shell 的 PATH，讓已寫入 Windows User 或 Machine PATH 的新工具可立即在目前 PowerShell session 中使用。

```powershell
Update-ShellPath
Update-ShellPath -PassThru
```

使用前請注意：

- 這個命令只會更新目前 shell 的 PATH，不會回寫系統環境變數
- 只有安裝程式已經把路徑寫進 Windows 的 User 或 Machine PATH 時，重新載入後才會生效
- 若工具需要額外 shell 初始化步驟，單純更新 PATH 不足以讓命令可用

實作在 [ValhallaToolkits/Environment.psm1](ValhallaToolkits/Environment.psm1#L1)。

### NuGet

#### Set-DefaultNugetSource

用途：保存預設 NuGet source 與 API Key。

```powershell
Set-DefaultNugetSource -Source nuget.org -ApiKey '<your-api-key>'
Set-DefaultNugetSource -Source 'https://www.myget.org/F/valhalla-ps/api/v3/index.json' -ApiKey '<your-api-key>'
```

#### Get-NugetSource

用途：讀取目前 `dotnet nuget list source` 的結果，並轉成 hashtable。

```powershell
Get-NugetSource
```

#### Get-NugetMaxVersion

用途：查詢指定套件在指定來源上的最高版本。

```powershell
Get-NugetMaxVersion -PackageId My.Package
Get-NugetMaxVersion -PackageId My.Package -Source nuget.org
```

#### Get-IncrementVersion

用途：將版本號自動加一。

```powershell
Get-IncrementVersion -Version 1.2.3
```

行為如下：

- `1.2` 會變成 `1.3`
- `1.2.3` 會變成 `1.2.4`
- `1.2.3.4` 會變成 `1.2.3.5`

#### Get-PackageId

用途：從專案檔讀取 `PackageId`；若沒有設定則回傳專案檔檔名。

```powershell
Get-PackageId -ProjectPath .\src\MyLibrary\MyLibrary.csproj
```

#### Push-Package

用途：將既有 `.nupkg` 套件推送到目標來源，並先檢查版本是否高於 feed 內版本。

```powershell
Push-Package -Path .\bin\Debug\My.Package.1.2.3.nupkg
Push-Package -Path .\bin\Debug\My.Package.1.2.3.nupkg -Source nuget.org -ApiKey '<your-api-key>'
```

#### Push-AlphaPackage

用途：從 `.csproj` 自動產生下一個 alpha 版本，執行 pack 後推送。

```powershell
Push-AlphaPackage -ProjectPath .\src\MyLibrary\MyLibrary.csproj
Push-AlphaPackage -ProjectPath .\src\MyLibrary\MyLibrary.csproj -Configuration Release
Push-AlphaPackage -ProjectPath .\src\MyLibrary\MyLibrary.csproj -Source nuget.org -ApiKey '<your-api-key>'
```

執行流程可見 [ValhallaToolkits/NugetTool.psm1](ValhallaToolkits/NugetTool.psm1#L152)：

- 讀取 `PackageId`
- 取得目前 feed 上最大版本後自動加一
- 使用 `dotnet pack --version` 直接指定 `新版號-alpha`
- 使用 `dotnet pack` 的預設輸出路徑產生套件後再推送

使用前請注意：

- 若未提供 `-Source` 與 `-ApiKey`，會改用設定檔中的預設值
- 專案檔需要可正常被 `Select-Xml` 與 `dotnet pack` 處理
- 不再需要建立暫存 `.csproj` 或依賴專案檔內既有 `Version` 節點

### Kubernetes

#### Set-MergeKubeconfig

用途：把新的 kubeconfig 與目前使用者的 kubeconfig 合併後寫回 `%USERPROFILE%\.kube\config`。

```powershell
Set-MergeKubeconfig -NewKubeConfig .\other-kubeconfig.yaml
Merge-Kubeconfig -NewKubeConfig .\other-kubeconfig.yaml
```

#### Export-KubeconfigFromSecret

用途：使用 service account 綁定的 Secret 內容匯出 kubeconfig（適用會自動幫 service account 建立長期 token Secret 的舊版 Kubernetes）。

> 前身為 `Export-Kubeconfig`，v0.0.29 改名。

```powershell
Export-KubeconfigFromSecret -Namespace dev -AccountName deploy-bot
Export-KubeconfigFromSecret -Namespace dev -AccountName deploy-bot -ContextName dev-cluster | Set-Content .\kubeconfig.yaml
```

#### Export-KubeconfigFromToken

用途：使用 `kubectl create token`（Kubernetes 1.24+ TokenRequest API）產生短期 token 並匯出 kubeconfig。

> 前身為 `Export-Kubeconfig2`，v0.0.29 改名。

```powershell
Export-KubeconfigFromToken -Namespace dev -AccountName deploy-bot
Export-KubeconfigFromToken -Namespace dev -AccountName deploy-bot -Duration 24h | Set-Content .\kubeconfig.yaml
```

#### Export-CurrentKubeconfig

用途：匯出目前 context 的 kubeconfig。

```powershell
Export-CurrentKubeconfig | Set-Content .\current-kubeconfig.yaml
```

#### Switch-KubeContext

用途：切換目前 kubectl context。

```powershell
Switch-KubeContext -Context dev-cluster
```

#### Switch-KubeNamespace

用途：切換目前 context 的預設 namespace。

```powershell
Switch-KubeNamespace -Namespace backend
```

Kubernetes 相關命令實作在 [ValhallaToolkits/Kubernetes.psm1](ValhallaToolkits/Kubernetes.psm1#L1)。

## 測試

測試使用 [Pester](https://pester.dev/)（v5）。純邏輯命令直接測試，會呼叫 `docker`/`kubectl`/`Get-VM`/檔案系統的命令則用 `Mock` 隔離外部依賴，涵蓋所有模組：

- `NugetTool`：`Get-IncrementVersion`、`Get-PackageId`、`Get-NugetSource`、`Get-NugetMaxVersion`
- `Environment`：`Update-ShellPath`
- `git`：`Get-GitAttribute(List)`
- `Configuration`：`Read-Configuration`/`Write-Configuration`
- `Containers`：`Get-AllContainerIP`（Mock `docker`）
- `Hosts`：`Get-HyperVHost`（Mock `Get-VM`）、`Set-Host`、`Set-DockerHost`/`Set-HyperVHost`/`Set-AllHost`（Mock 檔案 I/O 與內部函式，不會真的寫入 hosts 檔）
- `Kubernetes`：`Switch-KubeContext`/`Switch-KubeNamespace`/`Export-CurrentKubeconfig`/`Export-KubeconfigFromSecret`/`Export-KubeconfigFromToken`/`Set-MergeKubeconfig`（Mock `kubectl`，`Set-MergeKubeconfig` 另外把 `$env:UserProfile` 導向 `$TestDrive`，不會動到真實 kubeconfig）
- 模組清單驗證

```powershell
Invoke-Pester -Path .\Tests
```

若要產生測試報告（CI 也是用同樣方式）：

```powershell
$config = New-PesterConfiguration
$config.Run.Path = '.\Tests'
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'JUnitXml'
$config.TestResult.OutputPath = 'testResults.xml'
Invoke-Pester -Configuration $config
```

GitHub Actions（`.github/workflows/powershell.yml`）會在 `test` job 執行完整測試，並用 [`dorny/test-reporter`](https://github.com/dorny/test-reporter) 解析 `testResults.xml`（JUnitXml 格式）產生可展開的完整測試報告，掛在該次 workflow run 的 Checks／Summary 頁籤，列出每一項測試（含通過的），不用下載檔案就能看；原始 XML 仍會另外上傳成 artifact 供需要時下載。`publish` job 只有在 `push` 事件（非 PR）且 `test` 通過後才會執行，發行套件改用 `Publish-PSResource`（`Microsoft.PowerShell.PSResourceGet`）取代已過時的 `Publish-Module`（`PowerShellGet` v2）；發行前會先用 `Find-PSResource` 檢查同版號是否已存在於來源上，存在就直接跳過（不會像 `Publish-PSResource` 本身那樣因為版號重複而讓整個 job 失敗），需要重新發行請先在 `ValhallaToolkits.psd1` 調整 `ModuleVersion`。

撰寫測試過程中發現並修正了幾個 PowerShell「管線單一/空結果會被攤平成純量」造成的既有問題（`Get-AllContainerIP`、`Get-HyperVHost` 內部組陣列與回傳時都補上 `@(...)` 搭配 `return ,`，確保 0 筆、1 筆、多筆的情況都能正確保留為陣列；`Set-Host` 組合 hosts 內容時同樣補上 `@(...)`，避免內容剛好剩一行時 `+=` 變成字串串接把整份內容擠成一行）。對應的回歸測試已保留在 `Containers.Tests.ps1`、`Hosts.Tests.ps1` 中，涵蓋 0 筆／1 筆／多筆等邊界情況。

## 已知限制

- `Set-AllHost`、`Set-DockerHost`、`Set-HyperVHost` 與 `Set-MergeKubeconfig` 都會修改本機狀態，執行前請確認目前 shell 有足夠權限。
- `Push-AlphaPackage` 仍依賴 `dotnet pack` 以預設路徑輸出 `<PackageId>.<Version>.nupkg`；如果專案有自訂 pack 行為，可能需要調整實作。

## 建議使用方式

- 第一次使用先執行 `Import-Module` 與 `Get-Command -Module ValhallaToolkits`
- NuGet 相關命令先設定 `Set-DefaultNugetSource`
- 修改 hosts 前先以系統管理員權限啟動 PowerShell
- 匯出 kubeconfig 時先確認目前 kubectl context 是你要操作的叢集

如果之後你想把說明直接整合進 `Get-Help`，可以再補 comment-based help，讓每個命令都能透過 `Get-Help <CommandName> -Detailed` 查詢。
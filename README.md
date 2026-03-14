# ValhallaToolkits

ValhallaToolkits 是一組以 PowerShell 撰寫的開發輔助命令，包含 Docker 與 Hyper-V hosts 管理、.NET tool 更新、NuGet 套件推送、Git attributes 查詢，以及 Kubernetes kubeconfig 操作。

## 快速開始

先建立 Valhalla-PS repository（若已存在可略過）：

```powershell
if (-not (Get-PSRepository -Name 'Valhalla-PS' -ErrorAction SilentlyContinue)) {
    Register-PSRepository -Name 'Valhalla-PS' -SourceLocation 'https://www.myget.org/F/valhalla-ps/api/v3/index.json' -InstallationPolicy Trusted
}
```

建立完成後即可安裝：

```powershell
Install-Module -Name ValhallaToolkits -Repository Valhalla-PS
```

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

### .NET Tool

#### Update-AllDotNetTool

用途：更新已安裝的 .NET tools。

更新全域 tools：

```powershell
Update-AllDotNetTool
```

更新本機 manifest tools：

```powershell
Update-AllDotNetTool -Local
```

實作在 [ValhallaToolkits/DotNetTool.psm1](ValhallaToolkits/DotNetTool.psm1#L1)。

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
- 將暫存專案檔的 `Version` 改成 `新版號-alpha`
- 執行 `dotnet pack`
- 推送 `bin\<Configuration>\<PackageId>.<Version>-alpha.nupkg`

使用前請注意：

- 若未提供 `-Source` 與 `-ApiKey`，會改用設定檔中的預設值
- 專案檔需要可正常被 `Select-Xml` 與 `dotnet pack` 處理
- 目前實作會直接修改暫存專案檔中的 `Version` 節點，因此專案檔中應存在 `Version` 節點

### Kubernetes

#### Set-MergeKubeconfig

用途：把新的 kubeconfig 與目前使用者的 kubeconfig 合併後寫回 `%USERPROFILE%\.kube\config`。

```powershell
Set-MergeKubeconfig -NewKubeConfig .\other-kubeconfig.yaml
Merge-Kubeconfig -NewKubeConfig .\other-kubeconfig.yaml
```

#### Export-Kubeconfig

用途：使用 service account secret 內容匯出 kubeconfig。

```powershell
Export-Kubeconfig -Namespace dev -AccountName deploy-bot
Export-Kubeconfig -Namespace dev -AccountName deploy-bot -ContextName dev-cluster | Set-Content .\kubeconfig.yaml
```

#### Export-Kubeconfig2

用途：使用 `kubectl create token` 產生 token 並匯出 kubeconfig。

```powershell
Export-Kubeconfig2 -Namespace dev -AccountName deploy-bot
Export-Kubeconfig2 -Namespace dev -AccountName deploy-bot -Duration 24h | Set-Content .\kubeconfig.yaml
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

## 已知限制

- [ValhallaToolkits/Hosts.psm1](ValhallaToolkits/Hosts.psm1#L11) 與 [ValhallaToolkits/Hosts.psm1](ValhallaToolkits/Hosts.psm1#L55) 目前呼叫的是 `Set-Hosts`，但實作檔內定義的是 `Set-Host`。如果你在使用 `Set-DockerHost` 或 `Set-HyperVHost` 時遇到錯誤，先檢查這裡。
- `Set-AllHost`、`Set-DockerHost`、`Set-HyperVHost` 與 `Set-MergeKubeconfig` 都會修改本機狀態，執行前請確認目前 shell 有足夠權限。
- `Push-AlphaPackage` 依賴專案檔版本結構與預設輸出路徑；如果專案有自訂 pack 行為，可能需要手動指定或調整實作。

## 建議使用方式

- 第一次使用先執行 `Import-Module` 與 `Get-Command -Module ValhallaToolkits`
- NuGet 相關命令先設定 `Set-DefaultNugetSource`
- 修改 hosts 前先以系統管理員權限啟動 PowerShell
- 匯出 kubeconfig 時先確認目前 kubectl context 是你要操作的叢集

如果之後你想把說明直接整合進 `Get-Help`，可以再補 comment-based help，讓每個命令都能透過 `Get-Help <CommandName> -Detailed` 查詢。
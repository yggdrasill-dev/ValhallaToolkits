---
description: "在編輯 ValhallaToolkits 的 PowerShell 模組、匯出命令、模組 manifest、設定輔助程式，或新增會修改狀態的 PowerShell 命令時使用。涵蓋函式命名、ShouldProcess 使用、manifest 同步與設定持久化模式。"
name: "ValhallaToolkits PowerShell 模組慣例"
applyTo: "ValhallaToolkits/**/*.psm1, ValhallaToolkits/**/*.psd1, PSScriptAnalyzerSettings.psd1"
---
# ValhallaToolkits PowerShell 模組慣例

- 公開命令請使用 PowerShell 的 Verb-Noun 命名，新增匯出函式時要與既有模組介面保持一致。
- 當命令會修改檔案、環境變數、設定、外部工具狀態或遠端狀態時，請加入 [CmdletBinding(SupportsShouldProcess)]，並以 $PSCmdlet.ShouldProcess(...) 包住實際變更。
- 只要命令會呼叫外部工具或寫入持久化狀態，請在命令內設定 $ErrorActionPreference = 'Stop'，避免失敗被靜默忽略。
- 匯出函式與別名要與模組入口保持同步：更新 ValhallaToolkits.psd1 內的 FunctionsToExport 或 AliasesToExport，或在既有模組已採用明確 Export-ModuleMember 時維持該模式。
- 需要持久化模組設定時，優先重用 Read-Configuration、Write-Configuration 與 $ValhallaConfig，不要另外新增臨時設定檔或重複的設定載入邏輯。
- 不要只因風格理由就移除既有的內建 alias；此專案已透過 PSScriptAnalyzerSettings.psd1 明確允許這種用法。
- 變更應盡量小且符合所在檔案既有的排版與大括號風格，不要為了整理格式而重排整個模組。

## 範例

### 會修改狀態的命令

```powershell
function Set-ExampleValue {
	[CmdletBinding(SupportsShouldProcess)]
	param(
		[Parameter(Mandatory)]
		[string] $Value
	)

	process {
		$ErrorActionPreference = 'Stop'

		if (!$PSCmdlet.ShouldProcess('example target', 'Set value')) {
			return
		}

		$ValhallaConfig.Example = $Value
		Write-Configuration $ValhallaConfig
	}
}
```

### 新增公開函式時

```text
- 在模組檔中新增函式。
- 若該模組由 ValhallaToolkits.psd1 控制匯出，記得同步更新 FunctionsToExport 或 AliasesToExport。
- 若該模組已使用明確 Export-ModuleMember，則延續既有模式，不要混用另一套匯出方式。
```
---
description: "在撰寫或建議 git commit 訊息時使用。要求遵循 Conventional Commits 格式，並以 zh-TW 撰寫標題與內文。"
name: "Commit Message Conventions"
---
# Commit Message Conventions

- 當使用者要求產生 commit message、整理變更摘要、或準備提交內容時，使用 Conventional Commits。
- 標題格式：`type(scope): subject`。
- 允許的常見 type：`feat`、`fix`、`docs`、`style`、`refactor`、`test`、`chore`、`ci`、`build`、`perf`、`revert`。
- 內容語言使用繁體中文（zh-TW）。
- 主旨行保持精簡，聚焦單一變更主題。
- 內文使用條列說明主要修改點，避免與實際變更不一致。
- 若一次包含多種類型變更，優先選擇最主要影響的 type；必要時建議拆成多個 commit。

## 範例

```text
fix(hosts): 修正 Host IP 區塊重複插入問題

- 修正缺少標記時 # Host IPs 區塊重複追加
- 調整 Host entries 產生邏輯，避免重複管線程式碼
```

```text
docs(readme): 補充 Valhalla-PS 來源建立與安裝流程

- 加入 Register-PSRepository 指引
- 更新模組安裝步驟與 MyGet 來源說明
```
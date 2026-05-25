# i 記帳 PWA

這是 `SmartExpenseTracker` 的靜態 PWA 版本，可以用 iPhone Safari 開啟後加入主畫面，不需要每 7 天透過 Xcode 重新安裝。

## 本機預覽

```sh
cd /Users/yanghaohsiang/Desktop/SmartExpenseTracker/SmartExpenseTracker/pwa
python3 -m http.server 4174
```

開啟 `http://localhost:4174`。

## 部署

此 repo 已包含 GitHub Pages workflow：`.github/workflows/deploy-pwa.yml`。

推送到 `dev` 分支後，GitHub Actions 會把 `pwa/` 目錄部署到 GitHub Pages。
預期網址通常是 `https://mmyangmm.github.io/SmartExpenseTracker/`。

## 資料

資料目前儲存在瀏覽器 `localStorage`。設定頁提供 JSON 備份、JSON 匯入和 CSV 匯出。

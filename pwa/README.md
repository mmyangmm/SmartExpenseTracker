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

## Firebase 同步

PWA 會讀取 `firebase-config.js` 的 `window.I_EXPENSE_FIREBASE_CONFIG`，使用 Firebase Authentication 的 Google 登入與 Cloud Firestore 同步資料。

GitHub Pages 部署時可在 repo secrets 放 `PWA_FIREBASE_CONFIG`，內容為 Firebase Web App config JSON；或分別設定 `PWA_FIREBASE_API_KEY`、`PWA_FIREBASE_AUTH_DOMAIN`、`PWA_FIREBASE_PROJECT_ID`、`PWA_FIREBASE_APP_ID`、`PWA_FIREBASE_MESSAGING_SENDER_ID`、`PWA_FIREBASE_STORAGE_BUCKET`。

Firestore 預設寫入路徑：`users/{uid}/backups/smart-expense-tracker`。

建議 Firestore rules：

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 資料

資料會先儲存在瀏覽器 `localStorage`。Google 登入後，設定、記帳和旅行資料會自動合併並同步到 Firestore。設定頁也提供 JSON 備份、JSON 匯入和 CSV 匯出。

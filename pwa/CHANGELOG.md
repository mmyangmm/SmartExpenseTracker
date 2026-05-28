# i 記帳 PWA 重要更改記錄

> 之後 PWA 的重要 UI/UX、資料格式、快取版本、部署或功能行為改動，都要在這裡追加記錄，避免忘記改動原因或重複踩同一個錯誤。

## 2026-05-27

- 新增此重要更改記錄檔，作為後續 PWA 變更的固定紀錄位置。
- 拆分主題色彩與 App 圖示設定，避免混在同一張外觀卡片中。
- 移除右上角無作用的 PWA 安裝箭頭按鈕。
- 換匯改成每個幣別列內可直接輸入金額，輸入的幣別自動成為換算基準。
- 換匯新增幣別管理：可新增、刪除與手動排序顯示幣別。
- 修正新台幣圖示，避免依賴可能無法正常顯示的旗幟 emoji。
- 通知已允許時，允許通知按鈕改為綠色勾勾狀態並停用。
- 修正底部「統計」圓餅圖圖示比例。
- 新增原生 App 使用的貓咪 App icon 到 PWA 圖示選項。
- 將 PWA 資源快取版本升為 v6，避免舊版 JS/CSS 被 service worker 留住。
- 快速記帳移除鍵盤上方的可見備註/日期欄位，改成隱藏資料欄，避免遮擋畫面。
- 強化語音分類辨識：語音會比對分類名稱、分類 id 與關鍵字，解析訊息會顯示選到的分類。
- 修正設定頁開關偏移，避免通用文字樣式影響 switch 軌道位置。
- 補強版面水平鎖定：保留瀏覽器縮放能力，但避免橫向捲動與手勢造成版面偏移。
- 將 PWA 資源快取版本升為 v7。

## 2026-05-28

- 修正快速記帳鍵盤上方空白橫條：補上 `[hidden]` 強制隱藏規則，避免語音/掃描狀態列被通用 flex 樣式撐開。
- 新增雲端同步設定卡：可設定同步端點與存取權杖，設定、記帳與旅行資料變更後會自動送出備份。
- 雲端備份內容不輸出存取權杖，避免把私密 token 寫進 JSON 或同步 body。
- 移除 App 圖示選項中的「夜間」，將「貓咪」改為預設 App 圖示。
- 將 manifest、Apple touch icon 與 PWA 安裝圖示改用貓咪 icon。
- 修正通知提醒時間欄位對齊，避免 time input 在設定卡內偏移。
- 更新快速記帳底部操作列：掃描改為相機圖示、語音改為麥克風圖示，三個操作鍵重新對齊。
- 將 PWA 資源快取版本升為 v9。
- 將泛用 HTTP 端點同步改為 Firebase Authentication + Google 登入 + Cloud Firestore 同步。
- 新增 `firebase-config.js`，並在 GitHub Pages workflow 支援從 `PWA_FIREBASE_CONFIG` 或分離的 Firebase secrets 注入設定。
- Google 登入後會讀取 `users/{uid}/backups/smart-expense-tracker`，與本機 `localStorage` 資料合併，再自動回寫 Firestore。
- 將 PWA 資源快取版本升為 v10。
- 修正 Google 雲端同步無反應：補入先前 `i-expense-pwa` Firebase web config，並讓缺少設定時登入按鈕仍能顯示明確狀態。
- 修正提醒時間欄位在窄版設定頁偏移，改成固定雙欄 grid 對齊。
- 將 PWA 資源快取版本升為 v11。
- 修正 iOS/PWA Google 登入跳回 app 但未完成：改用 Firebase `signInWithPopup()`，不再自動 fallback 到 redirect。
- Google 登入失敗時顯示 Firebase 錯誤原因，例如未允許網域、彈窗被阻擋或登入視窗被關閉。
- 將 PWA 資源快取版本升為 v12。

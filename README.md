# Grant 💝

[![Version](https://img.shields.io/badge/version-v1.1.0-pink)](https://github.com/frankkn/Grant/releases/tag/v1.1.0)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Web-blue)](https://grant-45f5c.web.app)

一款專為情侶設計的許願 App，讓你用心動指數和理由說服另一半實現你的願望。

---

## 如何使用

### Android 安裝
1. 下載 [app-grant.apk（最新版）](https://github.com/frankkn/Grant/releases/latest/download/app-grant.apk)
2. 在手機「設定」→「安全性」→ 開啟「**允許安裝不明來源的應用程式**」
3. 點開下載的 APK 並安裝
4. 開啟 Grant，註冊帳號或用 Google 登入

### iOS（加入主畫面）
1. 用 **Safari** 開啟 [Grant 網頁版](https://grant-45f5c.web.app)
2. 點下方中間的「**分享**」按鈕 ↑
3. 滑動選單，選「**加入主畫面**」
4. 點右上角「**新增**」→ 桌面出現 Grant 圖示，用法與 App 相同

### Web 版
直接用瀏覽器開啟：[https://grant-45f5c.web.app](https://grant-45f5c.web.app)

---

## 功能

### 帳號
- Email 註冊 / 登入
- Google 帳號登入
- 首次登入設定暱稱
- 登入狀態自動保留

### 情侶配對
- 生成 6 碼配對碼（10 分鐘有效）
- 輸入另一半的配對碼完成配對
- 設定頁面可解除配對

### 許願系統（配對後）
- 送出許願：填寫願望、費用參考、心動指數（❤️ x5）、商品網址、商品描述、說服理由、希望日期
- 查看自己的許願清單，可編輯（審核中）或刪除
- 點入任一許願查看完整詳情與審核結果
- 審核另一半的許願：通過或駁回，可附上回覆
- 查看已審核的許願記錄

### 通知
- 送出許願時，另一半立即收到推播通知

### 其他
- 背景音樂（設定頁可調整音量）
- 新版本自動提示更新（Web 版）

---

## 技術架構

- **框架**：Flutter（支援 Android、Web）
- **後端**：Firebase（Authentication、Cloud Firestore）
- **推播通知**：Firebase Cloud Messaging + Railway 後端
- **登入**：Firebase Auth Email/Password + Google Sign-In

## 開發環境

- Flutter 3.32+
- Dart 3.8+
- Android SDK 35
- Firebase project: `grant-45f5c`

## 本地執行

```bash
# 安裝依賴
flutter pub get

# 執行 Android 模擬器
flutter run -d emulator-5554

# 執行 Web（Chrome）
flutter run -d chrome --web-port 5000

# Build Android APK
flutter build apk --debug
```

---

## 版本資訊

| 版本 | 日期 | 更新內容 |
|------|------|---------|
| v1.1.0 | 2026-05-30 | 修復送出願望按鈕被鍵盤遮住的問題、新增送出成功彈窗、iOS 非 Safari 瀏覽器提示、APK 改名為 app-grant.apk、GitHub Actions 自動發布 |
| v1.0.0 | 2026-05-30 | 首次發布：情侶配對、許願系統、推播通知、背景音樂、Web 版上線 |

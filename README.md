# Grant 💝

一款專為情侶設計的許願 App，讓你用心動指數和理由說服另一半實現你的願望。

## 功能

### 帳號
- Email 註冊 / 登入
- Google 帳號登入
- 首次登入設定暱稱
- 記住登入狀態（自動登入）

### 情侶配對
- 生成 6 碼配對碼（10 分鐘有效）
- 輸入另一半的配對碼完成配對

### 許願系統（配對後）
- 送出許願：填寫願望、費用參考、心動指數（❤️ x5）、說服理由、希望日期
- 查看自己的許願清單與狀態（審核中 / 通過 / 駁回）
- 審核另一半的許願：通過或駁回，可附上審核理由

## 技術架構

- **框架**：Flutter（支援 Android、Web）
- **後端**：Firebase（Authentication、Cloud Firestore）
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
```

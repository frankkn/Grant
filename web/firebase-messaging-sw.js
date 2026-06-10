// Grant — FCM Web 背景推播 service worker。
//
// 此檔必須位於 web 根目錄、且檔名固定為 firebase-messaging-sw.js：
// firebase_messaging_web 會自動以這支 SW 註冊背景推播。沒有它，
// 網頁／PWA（含 iOS 加入主畫面後）收不到任何背景推播。
//
// 設定值與 lib/firebase_options.dart 的 web 區塊一致。

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAGhLzHE-xwOn9SdKue2fAiX1Lc3m1hpkA',
  appId: '1:593151530958:web:90dfd6843e44b8fb873d9f',
  messagingSenderId: '593151530958',
  projectId: 'grant-45f5c',
  authDomain: 'grant-45f5c.firebaseapp.com',
  storageBucket: 'grant-45f5c.firebasestorage.app',
});

const messaging = firebase.messaging();

// 背景訊息：以 payload 內容顯示系統通知。
// 注意：若後端送的是含 notification 欄位的 payload，瀏覽器可能會「自動」
// 再顯示一則 → 出現重複通知。如遇此情況，請將後端 /notify 改送 data-only
// payload（只放 title/body 在 data 裡），由這裡單一來源負責顯示。
messaging.onBackgroundMessage(function (payload) {
  const n = payload.notification || payload.data || {};
  self.registration.showNotification(n.title || 'Grant', {
    body: n.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  });
});

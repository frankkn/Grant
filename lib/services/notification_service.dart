import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'backend.dart';

const _channel = AndroidNotificationChannel(
  'grant_wishes',
  '許願通知',
  description: '收到新許願時的通知',
  importance: Importance.high,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

// 背景訊息處理（必須是 top-level function）
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Web Push 用的 VAPID 公鑰（可公開，非機密；會隨網頁一起送到瀏覽器）。
  /// 取得方式：Firebase Console → ⚙ 專案設定 → Cloud Messaging →
  /// 「網路推送憑證 (Web Push certificates)」→ 產生金鑰組 → 複製貼到這裡。
  /// 留著預設值時，web 取不到推播 token（網頁/PWA 將收不到通知）。
  static const String _webVapidKey =
      'BPMqQD6T5PtTvw1NTGFEI0VvSN2LiorElJySBMxuu8CV-549eE3dB1TfQHWOwEfodd0ouZsLFXKhWoFwiMnt-hs';

  Future<void> initialize() async {
    // Web 不支援本地通知，跳過初始化
    if (!kIsWeb) {
      await _localNotifications.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification == null) return;
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      });
    }

    // 啟動時嘗試請求權限並註冊 token。iOS PWA 上瀏覽器會忽略「非使用者手勢」
    // 觸發的權限請求，故另提供 [requestPermissionAndRegister] 供 UI 按鈕呼叫。
    await requestPermissionAndRegister();

    _messaging.onTokenRefresh.listen(_saveTokenString);
  }

  /// 請求通知權限，取得授權後註冊推播 token；回傳是否取得授權。
  /// 可由 UI 的使用者手勢（例如設定頁的「開啟通知」）直接呼叫——
  /// iOS PWA 僅在手勢觸發時才會跳出系統權限要求。
  Future<bool> requestPermissionAndRegister() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final status = settings.authorizationStatus;
      final granted = status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;
      if (granted) await _saveToken();
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveToken() async {
    // Web 需帶 VAPID 公鑰才取得得到推播 token；原生平台不需要。
    final token = kIsWeb
        ? await _messaging.getToken(vapidKey: _webVapidKey)
        : await _messaging.getToken();
    if (token != null) await _saveTokenString(token);
  }

  Future<void> _saveTokenString(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    // set+merge 而非 update：token 重整可能早於使用者文件建立（首次登入競態），
    // update 會丟 NOT_FOUND；merge 則安全地建立／更新單一欄位。
    await _db
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  Future<void> sendWishNotification({
    required String toUid,
    required String wishTitle,
  }) async {
    await sendNotification(
      toUid: toUid,
      title: '💝 新的許願！',
      body: wishTitle,
    );
  }

  /// 通用推播：在動作發生當下從 App 端送出（事件型推播）。
  /// 失敗時靜默忽略，不影響主要操作流程。
  Future<void> sendNotification({
    required String toUid,
    required String title,
    String? body,
  }) async {
    try {
      final idToken = await _auth.currentUser?.getIdToken();
      if (idToken == null) return;
      await http.post(
        Uri.parse('$backendBaseUrl/notify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'toUid': toUid,
          'title': title,
          if (body != null) 'body': body,
        }),
      );
    } catch (e) {
      // 通知失敗不影響主要操作
    }
  }
}

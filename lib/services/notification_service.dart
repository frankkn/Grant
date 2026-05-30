import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

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
  static const _railwayUrl = 'https://grant-backend-production.up.railway.app';
  static const _apiKey = 'REDACTED-ROTATED-KEY';

  final _messaging = FirebaseMessaging.instance;
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> initialize() async {
    // 初始化本地通知
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // 建立 Android 通知頻道
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 請求推播權限
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _saveToken();
    }

    // Token 更新時重新儲存
    _messaging.onTokenRefresh.listen(_saveTokenString);

    // 背景訊息處理
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 前景訊息處理 → 顯示本地通知
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

  Future<void> _saveToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _saveTokenString(token);
  }

  Future<void> _saveTokenString(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  Future<void> sendWishNotification({
    required String toUid,
    required String wishTitle,
  }) async {
    try {
      await http.post(
        Uri.parse('$_railwayUrl/notify'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
        },
        body: jsonEncode({
          'toUid': toUid,
          'title': '💝 新的許願！',
          'body': wishTitle,
        }),
      );
    } catch (e) {
      // 通知失敗不影響許願送出
    }
  }
}

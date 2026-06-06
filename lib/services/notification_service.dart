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

    // 請求推播權限
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _saveToken();
    }

    _messaging.onTokenRefresh.listen(_saveTokenString);
  }

  Future<void> _saveToken() async {
    final token = await _messaging.getToken();
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

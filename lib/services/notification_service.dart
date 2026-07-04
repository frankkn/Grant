import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'backend.dart';

/// 設定頁顯示用的推播狀態。
/// - enabled：權限已授權且使用者未主動關閉 → 正常接收
/// - disabled：使用者自己關了（已移除 token），可隨時再開
/// - blocked：被系統／瀏覽器封鎖（曾點「不允許」）→ App 無法開，須到系統設定改
enum NotificationStatus { enabled, disabled, blocked }

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
  NotificationService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // 用 getter 延遲取得：避免單元測試一建構本類別就觸碰
  // FirebaseMessaging.instance（需要 Firebase.initializeApp）。
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  StreamSubscription<User?>? _authSub;

  /// Web Push 用的 VAPID 公鑰（可公開，非機密；會隨網頁一起送到瀏覽器）。
  /// 取得方式：Firebase Console → ⚙ 專案設定 → Cloud Messaging →
  /// 「網路推送憑證 (Web Push certificates)」→ 產生金鑰組 → 複製貼到這裡。
  /// 留著預設值時，web 取不到推播 token（網頁/PWA 將收不到通知）。
  static const String _webVapidKey =
      'BPMqQD6T5PtTvw1NTGFEI0VvSN2LiorElJySBMxuu8CV-549eE3dB1TfQHWOwEfodd0ouZsLFXKhWoFwiMnt-hs';

  /// 使用者的「接收推播」偏好（裝置層級；token 本就是每裝置一份）。
  /// 預設視為開啟，沿用既有行為——只有使用者主動關閉時才寫入 false。
  static const String _enabledKey = 'notifications_enabled';

  Future<bool> _enabledPref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> _setEnabledPref(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

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

    // 跟著登入狀態同步 token（使用者未主動關閉才做），而不是只在啟動時做一次：
    // initialize() 只在 main() 執行，啟動當下若尚未登入（新安裝必然如此），
    // token 會因為沒有 uid 存不進 Firestore，該裝置要等重啟才收得到推播。
    // iOS PWA 上瀏覽器會忽略「非使用者手勢」觸發的權限請求，
    // 故另提供 [enable] 供 UI 按鈕呼叫。
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((user) async {
      if (user == null) return;
      try {
        if (await _enabledPref()) await requestPermissionAndRegister();
      } catch (_) {
        // 同步失敗不影響 app 運作（token refresh 時會再試）
      }
    });

    _messaging.onTokenRefresh.listen(_saveTokenString);
  }

  /// 目前的推播狀態，供設定頁顯示開／關／被封鎖。
  Future<NotificationStatus> currentStatus() async {
    final status = (await _messaging.getNotificationSettings()).authorizationStatus;
    if (status == AuthorizationStatus.denied) return NotificationStatus.blocked;
    final granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    if (granted && await _enabledPref()) return NotificationStatus.enabled;
    return NotificationStatus.disabled;
  }

  /// 使用者主動開啟接收：記住偏好、請求權限並註冊 token。回傳是否取得授權。
  Future<bool> enable() async {
    await _setEnabledPref(true);
    return requestPermissionAndRegister();
  }

  /// 使用者主動關閉接收：記住偏好並移除 token，後端便無從推播給此裝置。
  /// 不動系統權限（網頁／iOS 無法以程式收回授權，那須由使用者到系統設定處理）。
  Future<void> disable() async {
    await _setEnabledPref(false);
    try {
      await _messaging.deleteToken();
    } catch (_) {}
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .set({'fcmToken': FieldValue.delete()}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// 登出「前」呼叫：移除 Firestore 上這台裝置的 token 映射
  /// （登出後就沒有寫自己文件的權限了），已登出的裝置才不會
  /// 繼續收到另一半的推播。不影響「接收推播」偏好設定。
  Future<void> clearTokenForCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .set({'fcmToken': FieldValue.delete()}, SetOptions(merge: true));
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
    // 使用者已關閉接收：不再保存（含 onTokenRefresh 自動觸發的）token。
    if (!await _enabledPref()) return;
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

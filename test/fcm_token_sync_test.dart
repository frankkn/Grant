import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grant/services/notification_service.dart';

/// Bug 修復：FCM token 只在 app 啟動時儲存一次，啟動後才登入的裝置
/// 在重啟前收不到推播。initialize() 改為監聽 authStateChanges 同步 token，
/// 並新增 clearTokenForCurrentUser 供登出前清除 token 使用。
void main() {
  test('clearTokenForCurrentUser 移除 fcmToken、保留其他欄位', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('me').set({
      'displayName': 'Frank',
      'partnerId': 'P1',
      'fcmToken': 'device-token-123',
    });
    final service = NotificationService(
      db: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
    );

    await service.clearTokenForCurrentUser();

    final data = (await db.collection('users').doc('me').get()).data()!;
    expect(data.containsKey('fcmToken'), isFalse,
        reason: '登出前應清掉這台裝置的 token，登出後裝置才不會繼續收到推播');
    expect(data['displayName'], 'Frank');
    expect(data['partnerId'], 'P1');
  });

  test('未登入時呼叫 → no-op、不丟錯', () async {
    final service = NotificationService(
      db: FakeFirebaseFirestore(),
      auth: MockFirebaseAuth(signedIn: false),
    );
    await service.clearTokenForCurrentUser(); // 不應丟出任何例外
  });
}

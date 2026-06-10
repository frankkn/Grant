import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grant/screens/wish_screen.dart';
import 'package:grant/services/wish_service.dart';

/// 一筆符合 WishModel.fromDoc 必填欄位的 pending 願望
Map<String, dynamic> pendingWish({
  required String requester,
  required String partner,
  required String title,
}) => {
      'requesterId': requester,
      'partnerId': partner,
      'title': title,
      'price': '100',
      'heartRating': 3,
      'reason': 'because',
      'category': '禮物',
      'scheduledAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 1)),
      ),
      'status': 'pending',
      'isSecret': false,
      'isFulfilled': false,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };

void main() {
  // 回歸測試：AppBar 紅點與「待審核」清單原本各自包一層 StreamBuilder 訂閱
  // 同一個 broadcast 串流，晚 build 的清單錯過初始事件 → 永遠停在「載入中…」。
  // 修正後改為單一 StreamBuilder 共用快照，空清單應收斂為「目前沒有待審核的許願」。
  group('審核許願分頁 — 待審清單會收斂、不卡載入中', () {
    Widget app(WishService service) => MaterialApp(
          home: WishScreen(
            partnerId: 'P1',
            initialIndex: 2, // 直接開在「審核許願」分頁
            wishService: service,
          ),
        );

    WishService serviceOn(FakeFirebaseFirestore db) => WishService(
          db: db,
          auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
        );

    testWidgets('沒有待審願望 → 顯示「目前沒有待審核的許願」，不卡在「載入中...」',
        (tester) async {
      final db = FakeFirebaseFirestore();

      await tester.pumpWidget(app(serviceOn(db)));
      await tester.pumpAndSettle();

      expect(find.text('載入中...'), findsNothing,
          reason: '空清單應收斂，不該停在載入中');
      expect(find.text('目前沒有待審核的許願'), findsOneWidget);
    });

    testWidgets('有一筆來自 P1 的待審願望 → 顯示其標題', (tester) async {
      final db = FakeFirebaseFirestore();
      await db
          .collection('wishes')
          .add(pendingWish(requester: 'P1', partner: 'me', title: '想要的禮物'));

      await tester.pumpWidget(app(serviceOn(db)));
      await tester.pumpAndSettle();

      expect(find.text('載入中...'), findsNothing);
      expect(find.text('目前沒有待審核的許願'), findsNothing);
      expect(find.text('想要的禮物'), findsOneWidget);
    });
  });
}

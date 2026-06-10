import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grant/screens/wish_screen.dart';
import 'package:grant/services/wish_service.dart';

Map<String, dynamic> myWish({
  required String title,
  required String status,
}) => {
      'requesterId': 'me',
      'partnerId': 'P1',
      'title': title,
      'price': '100',
      'heartRating': 3,
      'reason': 'because',
      'category': '禮物',
      'scheduledAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 1)),
      ),
      'status': status,
      'isSecret': false,
      'isFulfilled': false,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    };

void main() {
  // 「我的許願」分頁：編輯／刪除鈕只能出現在待審核（pending）的願望上，
  // 與 wish_service.deleteWish 及 firestore.rules（皆要求 status == pending）一致。
  // 回歸測試：先前刪除鈕沒判斷狀態，已通過願望也會顯示，按下卻靜默失敗。
  group('我的許願分頁 — 刪除鈕只在待審核顯示', () {
    Widget app(WishService service) => MaterialApp(
          home: WishScreen(
            partnerId: 'P1',
            initialIndex: 1, // 「我的許願」分頁
            wishService: service,
          ),
        );

    WishService serviceOn(FakeFirebaseFirestore db) => WishService(
          db: db,
          auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
        );

    testWidgets('待審核願望 → 顯示編輯與刪除鈕', (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('wishes').add(myWish(title: '待審', status: 'pending'));

      await tester.pumpWidget(app(serviceOn(db)));
      await tester.pumpAndSettle();

      expect(find.text('待審'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('已通過願望 → 不顯示編輯與刪除鈕', (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('wishes').add(myWish(title: '已通過', status: 'approved'));

      await tester.pumpWidget(app(serviceOn(db)));
      await tester.pumpAndSettle();

      expect(find.text('已通過'), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
    });
  });
}

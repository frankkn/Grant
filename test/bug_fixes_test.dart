import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grant/models/user_model.dart';
import 'package:grant/models/wish_model.dart';
import 'package:grant/services/pair_service.dart';
import 'package:grant/services/wish_service.dart';

/// 建立一筆符合 WishModel.fromDoc 必填欄位的願望資料
Map<String, dynamic> wishMap({
  required String requester,
  required String partner,
  required String title,
  String status = 'pending',
  bool isSecret = false,
  bool isFulfilled = false,
  DateTime? scheduledAt,
}) => {
  'requesterId': requester,
  'partnerId': partner,
  'title': title,
  'price': '100',
  'heartRating': 3,
  'reason': 'because',
  'category': '禮物',
  'scheduledAt': Timestamp.fromDate(
    scheduledAt ?? DateTime.now().add(const Duration(days: 1)),
  ),
  'status': status,
  'isSecret': isSecret,
  'isFulfilled': isFulfilled,
  'createdAt': Timestamp.now(),
  'updatedAt': Timestamp.now(),
};

void main() {
  // ─── Bug 1：配對防護 ──────────────────────────────────────────────
  group('Bug 1 — PairService.joinWithCode 配對防護', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    Future<void> seedCode(String code, String ownerId, {Duration ttl = const Duration(minutes: 10)}) {
      return db.collection('pairCodes').doc(code).set({
        'code': code,
        'ownerId': ownerId,
        'createdAt': Timestamp.now(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(ttl)),
      });
    }

    PairService serviceAs(String uid) => PairService(
      db: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
    );

    test('正常情況：雙方都未配對 → 互相綁定、配對碼被刪除', () async {
      await db.collection('users').doc('A').set({'displayName': 'A'});
      await db.collection('users').doc('B').set({'displayName': 'B'});
      await seedCode('ABC123', 'A');

      await serviceAs('B').joinWithCode('ABC123');

      final a = await db.collection('users').doc('A').get();
      final b = await db.collection('users').doc('B').get();
      expect(b.data()!['partnerId'], 'A');
      expect(a.data()!['partnerId'], 'B');
      final code = await db.collection('pairCodes').doc('ABC123').get();
      expect(code.exists, isFalse);
    });

    test('加入者已配對 → 丟錯，且不污染對方資料', () async {
      await db.collection('users').doc('A').set({'displayName': 'A'});
      await db.collection('users').doc('B').set({'displayName': 'B', 'partnerId': 'C'});
      await seedCode('ABC123', 'A');

      await expectLater(
        serviceAs('B').joinWithCode('ABC123'),
        throwsA(isA<Exception>()),
      );
      final a = await db.collection('users').doc('A').get();
      expect(a.data()!['partnerId'], isNull, reason: 'A 不該被綁定');
    });

    test('配對碼擁有者已配對 → 丟錯', () async {
      await db.collection('users').doc('A').set({'displayName': 'A', 'partnerId': 'X'});
      await db.collection('users').doc('B').set({'displayName': 'B'});
      await seedCode('ABC123', 'A');

      await expectLater(
        serviceAs('B').joinWithCode('ABC123'),
        throwsA(isA<Exception>()),
      );
    });

    test('配對碼過期 → 丟錯', () async {
      await db.collection('users').doc('A').set({'displayName': 'A'});
      await db.collection('users').doc('B').set({'displayName': 'B'});
      await seedCode('ABC123', 'A', ttl: const Duration(minutes: -1));

      await expectLater(
        serviceAs('B').joinWithCode('ABC123'),
        throwsA(isA<Exception>()),
      );
    });

    test('和自己配對 → 丟錯', () async {
      await db.collection('users').doc('A').set({'displayName': 'A'});
      await seedCode('ABC123', 'A');

      await expectLater(
        serviceAs('A').joinWithCode('ABC123'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ─── Bug 2：願望查詢限定在目前的 partner ────────────────────────────
  group('Bug 2 — WishService 只回傳和目前 partner 之間的願望', () {
    late FakeFirebaseFirestore db;
    late WishService service; // 視角為 "me"

    setUp(() {
      db = FakeFirebaseFirestore();
      service = WishService(
        db: db,
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
      );
    });

    test('watchMyWishes 只含送給目前對象 P1 的願望', () async {
      await db.collection('wishes').add(wishMap(requester: 'me', partner: 'P1', title: 'toP1'));
      await db.collection('wishes').add(wishMap(requester: 'me', partner: 'P0', title: 'toP0_舊對象'));

      final list = await service.watchMyWishes('P1').first;
      expect(list.map((w) => w.title), ['toP1']);
    });

    test('watchIncomingWishes 只含目前對象 P1 送來的 pending 願望', () async {
      await db.collection('wishes').add(wishMap(requester: 'P1', partner: 'me', title: 'fromP1'));
      await db.collection('wishes').add(wishMap(requester: 'P0', partner: 'me', title: 'fromP0_舊對象'));
      await db.collection('wishes').add(wishMap(requester: 'P1', partner: 'me', title: 'fromP1_已通過', status: 'approved'));

      final list = await service.watchIncomingWishes('P1').first;
      expect(list.map((w) => w.title), ['fromP1']);
    });

    test('watchReviewedWishes 只含目前對象 P1、且非 pending 的願望', () async {
      await db.collection('wishes').add(wishMap(requester: 'P1', partner: 'me', title: 'P1通過', status: 'approved'));
      await db.collection('wishes').add(wishMap(requester: 'P1', partner: 'me', title: 'P1待審', status: 'pending'));
      await db.collection('wishes').add(wishMap(requester: 'P0', partner: 'me', title: 'P0通過_舊對象', status: 'approved'));

      final list = await service.watchReviewedWishes('P1').first;
      expect(list.map((w) => w.title), ['P1通過']);
    });

    test('watchFulfilledWishes 只含和目前對象 P1 之間、已實現的願望（雙向）', () async {
      // 我許給 P1、已實現
      await db.collection('wishes').add(wishMap(requester: 'me', partner: 'P1', title: '我許_實現', status: 'approved', isFulfilled: true));
      // P1 許給我、已實現
      await db.collection('wishes').add(wishMap(requester: 'P1', partner: 'me', title: 'P1許_實現', status: 'approved', isFulfilled: true));
      // 舊對象 P0、已實現 → 不該出現
      await db.collection('wishes').add(wishMap(requester: 'me', partner: 'P0', title: '舊對象_實現', status: 'approved', isFulfilled: true));
      // P1、尚未實現 → 不該出現
      await db.collection('wishes').add(wishMap(requester: 'me', partner: 'P1', title: 'P1_未實現', status: 'approved'));

      // 合併兩條查詢，等到兩邊都收斂後的 emission（避免抓到不完整的第一幀）
      final list = await service
          .watchFulfilledWishes('P1')
          .firstWhere((l) => l.length >= 2)
          .timeout(const Duration(seconds: 5));
      expect(
        list.map((w) => w.title).toSet(),
        {'我許_實現', 'P1許_實現'},
        reason: '只該包含和 P1 之間、已實現的願望（雙向），排除舊對象與未實現',
      );
    });
  });

  // ─── Bug 3：鎖定中的秘密願望 ───────────────────────────────────────
  group('Bug 3 — WishModel.isLockedSecret', () {
    WishModel make({required bool isSecret, required DateTime scheduledAt}) => WishModel(
      id: 'x',
      requesterId: 'a',
      partnerId: 'b',
      title: 't',
      price: '1',
      reason: 'r',
      scheduledAt: scheduledAt,
      status: WishStatus.pending,
      isSecret: isSecret,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test('秘密願望且解鎖日在未來 → 鎖定（不計入紅點）', () {
      final w = make(isSecret: true, scheduledAt: DateTime.now().add(const Duration(days: 3)));
      expect(w.isLockedSecret, isTrue);
    });

    test('秘密願望但解鎖日已過 → 未鎖定（可審核、計入紅點）', () {
      final w = make(isSecret: true, scheduledAt: DateTime.now().subtract(const Duration(days: 1)));
      expect(w.isLockedSecret, isFalse);
    });

    test('公開願望 → 永不鎖定', () {
      final w = make(isSecret: false, scheduledAt: DateTime.now().add(const Duration(days: 3)));
      expect(w.isLockedSecret, isFalse);
    });
  });

  // ─── Bug 7：UserModel 容錯解析 ─────────────────────────────────────
  group('Bug 7 — UserModel.fromDoc 容錯解析', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    test('createdAt 為 null（serverTimestamp 尚未解析）→ 不丟錯，退回現在', () async {
      await db.collection('users').doc('U').set({
        'uid': 'U',
        'email': 'u@x.com',
        'displayName': 'U',
        'createdAt': null,
      });
      final doc = await db.collection('users').doc('U').get();
      final user = UserModel.fromDoc(doc);
      expect(user.uid, 'U');
      expect(user.createdAt, isNotNull);
    });

    test('缺少 uid/email/displayName/createdAt 欄位 → 退回預設值，不丟錯', () async {
      await db.collection('users').doc('U2').set({'partnerId': 'P'});
      final doc = await db.collection('users').doc('U2').get();
      final user = UserModel.fromDoc(doc);
      expect(user.uid, 'U2', reason: '缺 uid 時退回 doc.id');
      expect(user.email, '');
      expect(user.displayName, '');
      expect(user.partnerId, 'P');
      expect(user.createdAt, isNotNull);
    });
  });
}

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
  // ─── Bug 1：配對改由後端執行，client 僅負責帶 token 呼叫與錯誤對接 ──────
  // （配對的競態防護與授權邏輯已移至後端 Admin SDK transaction，於後端測試覆蓋）
  group('Bug 1 — PairService 配對改打後端 API', () {
    PairService serviceWith(MockClient client, {String uid = 'B'}) => PairService(
      db: FakeFirebaseFirestore(),
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
      httpClient: client,
    );

    test('generatePairCode 帶 Bearer token 呼叫 /pair/generate-code 並回傳 code', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode({'code': 'ABC123'}), 200);
      });

      final code = await serviceWith(client).generatePairCode();

      expect(code, 'ABC123');
      expect(captured.url.path, '/pair/generate-code');
      expect(captured.headers['Authorization'], startsWith('Bearer '));
    });

    test('joinWithCode 送出大寫、去空白的 code 至 /pair/join', () async {
      late Map<String, dynamic> sentBody;
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        sentBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'success': true}), 200);
      });

      await serviceWith(client).joinWithCode('  abc123 ');

      expect(captured.url.path, '/pair/join');
      expect(sentBody['code'], 'ABC123');
      expect(captured.headers['Authorization'], startsWith('Bearer '));
    });

    test('後端回非 2xx → 以後端 error 訊息丟出例外', () async {
      final client = MockClient((req) async =>
          http.Response(jsonEncode({'error': '配對碼已過期'}), 400));

      await expectLater(
        serviceWith(client).joinWithCode('ABC123'),
        throwsA(predicate((e) => e.toString().contains('配對碼已過期'))),
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

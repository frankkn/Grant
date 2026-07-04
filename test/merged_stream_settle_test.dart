import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grant/models/wish_model.dart';
import 'package:grant/services/wish_service.dart';

/// Bug 修復：watchFulfilledWishes / watchAllWishes 的 listen 回呼是 async，
/// 兩個 snapshot 的 _overlayList 可能亂序完成，過期結果會蓋掉新資料。
/// 改以遞增序號丟棄過期結果。真正的交錯難以在 fake 環境穩定重現，
/// 此處驗證「快速連續寫入後，最終 emission 必須等於資料庫最終狀態」。
Map<String, dynamic> wish({
  required String requester,
  required String partner,
  required String title,
  bool isFulfilled = false,
  bool isSecret = false,
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
  'status': 'approved',
  'isSecret': isSecret,
  'isFulfilled': isFulfilled,
  'createdAt': Timestamp.now(),
  'updatedAt': Timestamp.now(),
};

void main() {
  late FakeFirebaseFirestore db;
  late WishService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = WishService(
      db: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
    );
  });

  test('watchFulfilledWishes：連續快速寫入後，最終結果與資料庫一致', () async {
    final emissions = <List<WishModel>>[];
    final sub = service.watchFulfilledWishes('P1').listen(emissions.add);

    // 不等待、連續觸發多個 snapshot（雙向都有），最後再改變狀態
    await db.collection('wishes').doc('w1').set(
        wish(requester: 'me', partner: 'P1', title: 'A', isFulfilled: true));
    await db.collection('wishes').doc('w2').set(
        wish(requester: 'P1', partner: 'me', title: 'B', isFulfilled: true));
    await db.collection('wishes').doc('w3').set(
        wish(requester: 'me', partner: 'P1', title: 'C', isFulfilled: true));
    await db.collection('wishes').doc('w3').update({'isFulfilled': false});

    await pumpEventQueue();
    await sub.cancel();

    expect(emissions, isNotEmpty);
    expect(
      emissions.last.map((w) => w.title).toSet(),
      {'A', 'B'},
      reason: '最後一筆 emission 必須反映最終狀態（C 已取消實現）',
    );
  });

  test('watchAllWishes：含秘密願望（觸發 overlay 讀取）也收斂到最終狀態', () async {
    final emissions = <List<WishModel>>[];
    final sub = service.watchAllWishes('P1').listen(emissions.add);

    // 先寫 detail 再寫主文件（app 內是同一個 batch 一次寫入；
    // 子文件寫入不會觸發主 collection 的 snapshot，順序反了 overlay 會拿不到內容）
    await db
        .collection('wishes')
        .doc('s1')
        .collection('private')
        .doc('detail')
        .set({'title': '驚喜', 'price': '999', 'reason': 'r'});
    await db.collection('wishes').doc('s1').set(
        wish(requester: 'me', partner: 'P1', title: '', isSecret: true));
    await db.collection('wishes').doc('w2').set(
        wish(requester: 'P1', partner: 'me', title: 'B'));
    await db.collection('wishes').doc('w2').update({'title': 'B2'});

    await pumpEventQueue();
    await sub.cancel();

    expect(emissions, isNotEmpty);
    final titles = emissions.last.map((w) => w.title).toSet();
    expect(titles, {'驚喜', 'B2'},
        reason: '秘密願望 overlay 補回內容、更新後的標題不被過期結果蓋掉');
  });
}

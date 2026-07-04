import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grant/models/pair_model.dart';
import 'package:grant/services/pair_service.dart';

/// Bug 修復：ensurePair 原本無條件 set+merge，每次發悄悄話／存紀念日
/// 都會把 pair 文件的 createdAt 重寫成新的 serverTimestamp。
/// 改為文件已存在時直接返回。
void main() {
  late FakeFirebaseFirestore db;
  late PairService service;
  final pairId = PairModel.pairIdFor('me', 'P1');

  setUp(() {
    db = FakeFirebaseFirestore();
    service = PairService(
      db: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'me')),
    );
  });

  test('首次呼叫 → 建立文件含 members 與 createdAt', () async {
    await service.ensurePair('P1');
    final data = (await db.collection('pairs').doc(pairId).get()).data()!;
    expect(data['members'], ['P1', 'me']);
    expect(data['createdAt'], isNotNull);
  });

  test('文件已存在 → 不再覆寫 createdAt', () async {
    final original = Timestamp.fromDate(DateTime(2024, 2, 14));
    await db.collection('pairs').doc(pairId).set({
      'members': ['P1', 'me'],
      'createdAt': original,
    });

    await service.ensurePair('P1');

    final data = (await db.collection('pairs').doc(pairId).get()).data()!;
    expect(data['createdAt'], original,
        reason: '既有 pair 的 createdAt 不該被重寫');
  });

  test('文件已存在 → events 等既有欄位不受影響', () async {
    await db.collection('pairs').doc(pairId).set({
      'members': ['P1', 'me'],
      'createdAt': Timestamp.now(),
      'events': [
        {
          'id': 'e1',
          'title': '在一起',
          'date': Timestamp.fromDate(DateTime(2024, 2, 14)),
          'type': 'together',
        },
      ],
    });

    await service.ensurePair('P1');

    final data = (await db.collection('pairs').doc(pairId).get()).data()!;
    expect(data['events'], hasLength(1));
  });
}

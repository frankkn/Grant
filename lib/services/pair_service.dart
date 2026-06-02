import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PairService {
  PairService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// 生成配對碼，存入 pairCodes collection 並更新自己的 user 文件
  Future<String> generatePairCode() async {
    final uid = _auth.currentUser!.uid;
    final code = _generateCode();
    final expiresAt = DateTime.now().add(const Duration(minutes: 10));

    final batch = _db.batch();

    batch.set(_db.collection('pairCodes').doc(code), {
      'code': code,
      'ownerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    batch.update(_db.collection('users').doc(uid), {'pairCode': code});

    await batch.commit();
    return code;
  }

  /// 輸入配對碼，將雙方綁定為 partner
  Future<void> joinWithCode(String code) async {
    final myUid = _auth.currentUser!.uid;

    final codeDoc = await _db.collection('pairCodes').doc(code.toUpperCase()).get();
    if (!codeDoc.exists) throw Exception('找不到此配對碼');

    final data = codeDoc.data()!;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiresAt)) throw Exception('配對碼已過期');

    final partnerUid = data['ownerId'] as String;
    if (partnerUid == myUid) throw Exception('不能和自己配對');

    // 確認雙方都尚未配對，避免覆蓋掉既有配對造成「單向配對」孤兒
    final myDoc = await _db.collection('users').doc(myUid).get();
    if ((myDoc.data()?['partnerId'] as String?) != null) {
      throw Exception('你已經配對了，請先解除配對再重新配對');
    }
    final partnerDoc = await _db.collection('users').doc(partnerUid).get();
    if ((partnerDoc.data()?['partnerId'] as String?) != null) {
      throw Exception('對方已經和別人配對了');
    }

    final batch = _db.batch();

    // 互相設定 partnerId
    batch.update(_db.collection('users').doc(myUid), {
      'partnerId': partnerUid,
    });
    batch.update(_db.collection('users').doc(partnerUid), {
      'partnerId': myUid,
      'pairCode': null,
    });

    // 刪除已使用的配對碼
    batch.delete(_db.collection('pairCodes').doc(code.toUpperCase()));

    await batch.commit();
  }

  /// 解除配對
  Future<void> unpair(String partnerId) async {
    final myUid = _auth.currentUser!.uid;
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(myUid), {'partnerId': null});
    batch.update(_db.collection('users').doc(partnerId), {'partnerId': null});
    await batch.commit();
  }
}

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/pair_model.dart';
import '../models/post_model.dart';
import 'notification_service.dart';

class PairService {
  PairService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _myUid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> _pairRef(String partnerId) =>
      _db.collection('pairs').doc(PairModel.pairIdFor(_myUid, partnerId));

  /// 確保配對共享文件存在（首次用到時自動建立，現有配對毋須遷移）
  Future<void> ensurePair(String partnerId) async {
    final members = [_myUid, partnerId]..sort();
    await _pairRef(partnerId).set({
      'members': members,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 監聽配對共享文件（紀念日等）
  Stream<PairModel?> watchPair(String partnerId) {
    return _pairRef(partnerId)
        .snapshots()
        .map((doc) => doc.exists ? PairModel.fromDoc(doc) : null);
  }

  // ── 紀念日 ──────────────────────────────────────────────

  /// 新增或更新一個紀念日（依 id 比對，read-modify-write 整個陣列）
  Future<void> saveEvent(String partnerId, AnniversaryEvent event) async {
    await ensurePair(partnerId);
    final ref = _pairRef(partnerId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final raw = (snap.data()?['events'] as List<dynamic>?) ?? [];
      final events = raw
          .map((e) => AnniversaryEvent.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      final idx = events.indexWhere((e) => e.id == event.id);
      if (idx >= 0) {
        events[idx] = event;
      } else {
        events.add(event);
      }
      tx.set(ref, {
        'events': events.map((e) => e.toMap()).toList(),
      }, SetOptions(merge: true));
    });
  }

  /// 刪除一個紀念日
  Future<void> deleteEvent(String partnerId, String eventId) async {
    final ref = _pairRef(partnerId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final raw = (snap.data()?['events'] as List<dynamic>?) ?? [];
      final events = raw
          .map((e) => AnniversaryEvent.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.id != eventId)
          .toList();
      tx.set(ref, {
        'events': events.map((e) => e.toMap()).toList(),
      }, SetOptions(merge: true));
    });
  }

  // ── 悄悄話動態牆 ────────────────────────────────────────

  /// 監聽悄悄話（新→舊）
  Stream<List<PostModel>> watchPosts(String partnerId) {
    return _pairRef(partnerId)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(PostModel.fromDoc).toList());
  }

  /// 發一則悄悄話，並推播給對方
  Future<void> createPost({
    required String partnerId,
    required String text,
    required String mood,
  }) async {
    await ensurePair(partnerId);
    await _pairRef(partnerId).collection('posts').add({
      'authorId': _myUid,
      'text': text,
      'mood': mood,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final preview = mood.isEmpty ? text : '$mood $text';
    await NotificationService().sendNotification(
      toUid: partnerId,
      title: '💌 對方傳來一則悄悄話',
      body: preview,
    );
  }

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
    final codeRef = _db.collection('pairCodes').doc(code.toUpperCase());
    final myRef = _db.collection('users').doc(myUid);

    await _db.runTransaction((tx) async {
      final codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) throw Exception('找不到此配對碼');

      final data = codeSnap.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) throw Exception('配對碼已過期');

      final partnerUid = data['ownerId'] as String;
      if (partnerUid == myUid) throw Exception('不能和自己配對');

      // 在 transaction 內讀取雙方 user，確保檢查與寫入是原子的
      final mySnap = await tx.get(myRef);
      if ((mySnap.data()?['partnerId'] as String?) != null) {
        throw Exception('你已經配對了，請先解除配對再重新配對');
      }
      final partnerRef = _db.collection('users').doc(partnerUid);
      final partnerSnap = await tx.get(partnerRef);
      if ((partnerSnap.data()?['partnerId'] as String?) != null) {
        throw Exception('對方已經和別人配對了');
      }

      // 互相設定 partnerId，並刪除配對碼（原子完成）
      tx.update(myRef, {'partnerId': partnerUid});
      tx.update(partnerRef, {'partnerId': myUid, 'pairCode': null});
      tx.delete(codeRef);
    });
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

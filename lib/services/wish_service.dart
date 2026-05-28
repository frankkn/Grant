import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wish_model.dart';

class WishService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _myUid => _auth.currentUser!.uid;

  /// 送出許願
  Future<void> createWish({
    required String partnerId,
    required String title,
    String? price,
    required int heartRating,
    required String reason,
    required DateTime scheduledAt,
  }) async {
    final now = DateTime.now();
    final ref = _db.collection('wishes').doc();
    final wish = WishModel(
      id: ref.id,
      requesterId: _myUid,
      partnerId: partnerId,
      title: title,
      price: price,
      heartRating: heartRating,
      reason: reason,
      scheduledAt: scheduledAt,
      status: WishStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(wish.toMap());
  }

  /// 監聽我送出的許願
  Stream<List<WishModel>> watchMyWishes() {
    return _db
        .collection('wishes')
        .where('requesterId', isEqualTo: _myUid)
        .snapshots()
        .map((snap) => snap.docs.map(WishModel.fromDoc).toList());
  }

  /// 監聽待我審核的許願（另一半送給我的）
  Stream<List<WishModel>> watchIncomingWishes() {
    return _db
        .collection('wishes')
        .where('partnerId', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map(WishModel.fromDoc).toList());
  }

  /// 審核許願（通過或駁回）
  Future<void> reviewWish({
    required String wishId,
    required WishStatus decision,
    required String reviewNote,
  }) async {
    if (decision == WishStatus.pending) throw ArgumentError('decision 不能是 pending');
    await _db.collection('wishes').doc(wishId).update({
      'status': decision.name,
      'reviewNote': reviewNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

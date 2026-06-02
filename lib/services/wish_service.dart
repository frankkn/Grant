import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wish_model.dart';
import 'notification_service.dart';

class WishService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _myUid => _auth.currentUser!.uid;

  /// 送出許願
  Future<void> createWish({
    required String partnerId,
    required String title,
    required String price,
    required int heartRating,
    String? productUrl,
    String? description,
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
      productUrl: productUrl,
      description: description,
      reason: reason,
      scheduledAt: scheduledAt,
      status: WishStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(wish.toMap());

    // 發推播通知給另一半
    await NotificationService().sendWishNotification(
      toUid: partnerId,
      wishTitle: title,
    );
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

  /// 編輯許願（只允許 pending 狀態）
  Future<void> updateWish({
    required String wishId,
    required String title,
    required String price,
    required int heartRating,
    String? productUrl,
    String? description,
    required String reason,
    required DateTime scheduledAt,
  }) async {
    await _db.collection('wishes').doc(wishId).update({
      'title': title,
      'price': price,
      'heartRating': heartRating,
      'productUrl': productUrl,
      'description': description,
      'reason': reason,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 刪除許願（只允許 pending 狀態）
  Future<void> deleteWish(String wishId) async {
    await _db.collection('wishes').doc(wishId).delete();
  }

  /// 切換願望是否已實現，可附上感謝話
  Future<void> setWishFulfilled({
    required String wishId,
    required bool isFulfilled,
    String? fulfillmentNote,
  }) async {
    await _db.collection('wishes').doc(wishId).update({
      'isFulfilled': isFulfilled,
      if (fulfillmentNote != null) 'fulfillmentNote': fulfillmentNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 監聽雙方所有已實現的願望（用於回憶牆）
  /// 合併「我許的願」和「我審核的願」兩個 query，用 onListen 確保不遺失初始事件
  Stream<List<WishModel>> watchFulfilledWishes() {
    List<WishModel> latestMine = [];
    List<WishModel> latestReviewed = [];
    StreamSubscription? sub1, sub2;

    List<WishModel> merged() {
      final seen = <String>{};
      return [...latestMine, ...latestReviewed]
          .where((w) => seen.add(w.id))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    late StreamController<List<WishModel>> controller;
    controller = StreamController<List<WishModel>>(
      onListen: () {
        sub1 = _db
            .collection('wishes')
            .where('requesterId', isEqualTo: _myUid)
            .where('isFulfilled', isEqualTo: true)
            .snapshots()
            .listen(
              (snap) {
                latestMine = snap.docs.map(WishModel.fromDoc).toList();
                if (!controller.isClosed) controller.add(merged());
              },
              onError: controller.addError,
            );
        sub2 = _db
            .collection('wishes')
            .where('partnerId', isEqualTo: _myUid)
            .where('isFulfilled', isEqualTo: true)
            .snapshots()
            .listen(
              (snap) {
                latestReviewed = snap.docs.map(WishModel.fromDoc).toList();
                if (!controller.isClosed) controller.add(merged());
              },
              onError: controller.addError,
            );
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
      },
    );
    return controller.stream;
  }

  /// 監聽我已審核的許願（通過或駁回）
  Stream<List<WishModel>> watchReviewedWishes() {
    return _db
        .collection('wishes')
        .where('partnerId', isEqualTo: _myUid)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(WishModel.fromDoc)
              .where((w) => w.status != WishStatus.pending)
              .toList(),
        );
  }

  /// 審核許願（通過或駁回）
  Future<void> reviewWish({
    required String wishId,
    required WishStatus decision,
    required String reviewNote,
  }) async {
    if (decision == WishStatus.pending) {
      throw ArgumentError('decision 不能是 pending');
    }
    await _db.collection('wishes').doc(wishId).update({
      'status': decision.name,
      'reviewNote': reviewNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

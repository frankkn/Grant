import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/wish_model.dart';
import 'notification_service.dart';

class WishService {
  WishService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

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
    required String category,
    bool isSecret = false,
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
      isSecret: isSecret,
      category: category,
      createdAt: now,
      updatedAt: now,
    );
    await ref.set(wish.toMap());

    // 秘密許願通知文字不透露內容
    final notifyTitle = isSecret ? '🔒 有個秘密心願在等你…' : title;
    await NotificationService().sendWishNotification(
      toUid: partnerId,
      wishTitle: notifyTitle,
    );
  }

  /// 監聽我送出給目前另一半的許願
  Stream<List<WishModel>> watchMyWishes(String partnerId) {
    return _db
        .collection('wishes')
        .where('requesterId', isEqualTo: _myUid)
        .snapshots()
        .map((snap) => snap.docs
            .map(WishModel.fromDoc)
            .where((w) => w.partnerId == partnerId)
            .toList());
  }

  /// 監聽待我審核的許願（目前另一半送給我的）
  Stream<List<WishModel>> watchIncomingWishes(String partnerId) {
    return _db
        .collection('wishes')
        .where('partnerId', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map(WishModel.fromDoc)
            .where((w) => w.requesterId == partnerId)
            .toList());
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
    required String category,
    bool isSecret = false,
  }) async {
    await _db.collection('wishes').doc(wishId).update({
      'title': title,
      'price': price,
      'heartRating': heartRating,
      'productUrl': productUrl,
      'description': description,
      'reason': reason,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'category': category,
      'isSecret': isSecret,
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

  /// 監聽和目前另一半之間所有已實現的願望（用於回憶牆）
  /// 合併「我許的願」和「我審核的願」兩個 query，用 onListen 確保不遺失初始事件
  Stream<List<WishModel>> watchFulfilledWishes(String partnerId) {
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
                latestMine = snap.docs
                    .map(WishModel.fromDoc)
                    .where((w) => w.partnerId == partnerId)
                    .toList();
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
                latestReviewed = snap.docs
                    .map(WishModel.fromDoc)
                    .where((w) => w.requesterId == partnerId)
                    .toList();
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

  /// 監聽我已審核的許願（通過、駁回、協商中，且來自目前另一半）
  Stream<List<WishModel>> watchReviewedWishes(String partnerId) {
    return _db
        .collection('wishes')
        .where('partnerId', isEqualTo: _myUid)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(WishModel.fromDoc)
              .where((w) =>
                  w.status != WishStatus.pending && w.requesterId == partnerId)
              .toList(),
        );
  }

  /// 審核許願（通過或駁回）
  Future<void> reviewWish({
    required String wishId,
    required WishStatus decision,
    required String reviewNote,
  }) async {
    if (decision == WishStatus.pending || decision == WishStatus.negotiating) {
      throw ArgumentError('請使用正確的審核方法');
    }
    final wish = await _getWish(wishId);
    await _db.collection('wishes').doc(wishId).update({
      'status': decision.name,
      'reviewNote': reviewNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (wish != null) {
      final approved = decision == WishStatus.approved;
      await NotificationService().sendNotification(
        toUid: wish.requesterId,
        title: approved ? '✅ 願望通過了！' : '🥲 願望被婉拒了',
        body: wish.title,
      );
    }
  }

  /// 提案修改（B 送出協商條件）
  Future<void> proposeNegotiation({
    required String wishId,
    required String negotiationNote,
  }) async {
    final wish = await _getWish(wishId);
    await _db.collection('wishes').doc(wishId).update({
      'status': WishStatus.negotiating.name,
      'negotiationNote': negotiationNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (wish != null) {
      await NotificationService().sendNotification(
        toUid: wish.requesterId,
        title: '💬 對方想和你商量一下',
        body: wish.title,
      );
    }
  }

  /// A 接受協商提案 → 直接 approved
  Future<void> acceptNegotiation(String wishId) async {
    final wish = await _getWish(wishId);
    await _db.collection('wishes').doc(wishId).update({
      'status': WishStatus.approved.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (wish != null) {
      await NotificationService().sendNotification(
        toUid: wish.partnerId,
        title: '🤝 對方接受了你的提案',
        body: wish.title,
      );
    }
  }

  /// A 放棄協商 → rejected
  Future<void> declineNegotiation(String wishId) async {
    final wish = await _getWish(wishId);
    await _db.collection('wishes').doc(wishId).update({
      'status': WishStatus.rejected.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (wish != null) {
      await NotificationService().sendNotification(
        toUid: wish.partnerId,
        title: '🥲 對方婉拒了這次的提案',
        body: wish.title,
      );
    }
  }

  /// 讀取單一願望（推播需要 requesterId / partnerId / title）
  Future<WishModel?> _getWish(String wishId) async {
    final doc = await _db.collection('wishes').doc(wishId).get();
    return doc.exists ? WishModel.fromDoc(doc) : null;
  }
}

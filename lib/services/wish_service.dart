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

  /// 秘密願望的內容子文件 wishes/{id}/private/detail
  DocumentReference<Map<String, dynamic>> _detailRef(String wishId) =>
      _db.collection('wishes').doc(wishId).collection('private').doc('detail');

  /// 把秘密願望的內容（存在 private/detail）覆蓋回 WishModel。
  /// - 公開願望：內容本就在主文件，原樣返回。
  /// - 秘密願望（我是許願者，或已解鎖）：讀子文件補上內容。
  /// - 秘密願望（我是伴侶且未解鎖）：清空內容，連同遮蔽舊資料可能殘留在主文件者。
  Future<WishModel> _overlayDetail(WishModel w) async {
    if (!w.isSecret) return w;
    final mine = w.requesterId == _myUid;
    if (!mine && w.isLockedSecret) return w.redactedContent();
    try {
      final snap = await _detailRef(w.id).get();
      final data = snap.data();
      if (data != null) return w.withContent(data);
    } catch (_) {
      // 權限不足（理論上不會走到）或讀取失敗：保持主文件內容，不中斷串流
    }
    return w;
  }

  Future<List<WishModel>> _overlayList(List<WishModel> list) =>
      Future.wait(list.map(_overlayDetail));

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
    // 秘密願望：內容寫進 private/detail 子文件，主文件只留 meta，伴侶解鎖前讀不到內容。
    // 公開願望：內容與 meta 一起寫在主文件（沿用原行為）。
    final batch = _db.batch();
    if (isSecret) {
      batch.set(ref, wish.toMetaMap());
      batch.set(_detailRef(ref.id), wish.toContentMap());
    } else {
      batch.set(ref, {...wish.toMetaMap(), ...wish.toContentMap()});
    }
    await batch.commit();

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
        .asyncMap((snap) => _overlayList(snap.docs
            .map(WishModel.fromDoc)
            .where((w) => w.partnerId == partnerId)
            .toList()));
  }

  /// 監聽待我審核的許願（目前另一半送給我的）
  Stream<List<WishModel>> watchIncomingWishes(String partnerId) {
    return _db
        .collection('wishes')
        .where('partnerId', isEqualTo: _myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snap) => _overlayList(snap.docs
            .map(WishModel.fromDoc)
            .where((w) => w.requesterId == partnerId)
            .toList()));
  }

  /// 編輯許願（只允許 pending 狀態，且只有許願者本人）
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
    final ref = _db.collection('wishes').doc(wishId);
    final detailRef = _detailRef(wishId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('找不到此願望');
      final wish = WishModel.fromDoc(snap);
      if (wish.requesterId != _myUid) throw Exception('無權修改此願望');
      if (wish.status != WishStatus.pending) throw Exception('只能修改待審核的願望');

      final meta = {
        'heartRating': heartRating,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'category': category,
        'isSecret': isSecret,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final content = {
        'title': title,
        'price': price,
        'productUrl': productUrl,
        'description': description,
        'reason': reason,
      };

      if (isSecret) {
        // 內容移到 private/detail；主文件清掉任何殘留的內容欄位（含公開→秘密的切換）
        tx.update(ref, {
          ...meta,
          for (final k in WishModel.contentKeys) k: FieldValue.delete(),
        });
        tx.set(detailRef, content);
      } else {
        // 內容回到主文件；刪除可能存在的 detail 子文件（含秘密→公開的切換）
        tx.update(ref, {...meta, ...content});
        tx.delete(detailRef);
      }
    });
  }

  /// 刪除許願（只允許 pending 狀態，且只有許願者本人）
  Future<void> deleteWish(String wishId) async {
    final ref = _db.collection('wishes').doc(wishId);
    final detailRef = _detailRef(wishId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('找不到此願望');
      final wish = WishModel.fromDoc(snap);
      if (wish.requesterId != _myUid) throw Exception('無權刪除此願望');
      if (wish.status != WishStatus.pending) throw Exception('只能刪除待審核的願望');
      tx.delete(ref);
      tx.delete(detailRef); // 一併清掉秘密內容子文件（公開願望則為 no-op）
    });
  }

  /// 切換願望是否已實現，可附上感謝話。
  /// 僅限「已通過（approved）」的願望，且須為當事雙方之一——與 firestore.rules 一致。
  Future<void> setWishFulfilled({
    required String wishId,
    required bool isFulfilled,
    String? fulfillmentNote,
  }) async {
    final ref = _db.collection('wishes').doc(wishId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('找不到此願望');
      final wish = WishModel.fromDoc(snap);
      if (wish.requesterId != _myUid && wish.partnerId != _myUid) {
        throw Exception('無權更新此願望');
      }
      if (wish.status != WishStatus.approved) {
        throw Exception('只能標記已通過的願望為已實現');
      }
      // 取消已實現時一併清掉舊感謝話，避免殘留的 ✨ 文字繼續顯示；
      // 標記已實現時，有帶感謝話才寫入。
      final Object? noteUpdate = isFulfilled
          ? fulfillmentNote
          : FieldValue.delete();
      tx.update(ref, {
        'isFulfilled': isFulfilled,
        if (noteUpdate != null) 'fulfillmentNote': noteUpdate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
              (snap) async {
                latestMine = await _overlayList(snap.docs
                    .map(WishModel.fromDoc)
                    .where((w) => w.partnerId == partnerId)
                    .toList());
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
              (snap) async {
                latestReviewed = await _overlayList(snap.docs
                    .map(WishModel.fromDoc)
                    .where((w) => w.requesterId == partnerId)
                    .toList());
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

  /// 監聽和目前另一半之間「所有」願望（雙向，不分狀態）——供統計使用
  Stream<List<WishModel>> watchAllWishes(String partnerId) {
    List<WishModel> latestMine = [];
    List<WishModel> latestTheirs = [];
    StreamSubscription? sub1, sub2;

    List<WishModel> merged() {
      final seen = <String>{};
      return [...latestMine, ...latestTheirs]
          .where((w) => seen.add(w.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    late StreamController<List<WishModel>> controller;
    controller = StreamController<List<WishModel>>(
      onListen: () {
        sub1 = _db
            .collection('wishes')
            .where('requesterId', isEqualTo: _myUid)
            .snapshots()
            .listen(
              (snap) async {
                latestMine = await _overlayList(snap.docs
                    .map(WishModel.fromDoc)
                    .where((w) => w.partnerId == partnerId)
                    .toList());
                if (!controller.isClosed) controller.add(merged());
              },
              onError: controller.addError,
            );
        sub2 = _db
            .collection('wishes')
            .where('partnerId', isEqualTo: _myUid)
            .snapshots()
            .listen(
              (snap) async {
                latestTheirs = await _overlayList(snap.docs
                    .map(WishModel.fromDoc)
                    .where((w) => w.requesterId == partnerId)
                    .toList());
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
        .asyncMap(
          (snap) => _overlayList(snap.docs
              .map(WishModel.fromDoc)
              .where((w) =>
                  w.status != WishStatus.pending && w.requesterId == partnerId)
              .toList()),
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
    final ref = _db.collection('wishes').doc(wishId);
    WishModel? wish;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('找不到此願望');
      wish = WishModel.fromDoc(snap);
      if (wish!.partnerId != _myUid) throw Exception('無權審核此願望');
      if (wish!.status != WishStatus.pending) throw Exception('只能審核待審核的願望');
      tx.update(ref, {
        'status': decision.name,
        'reviewNote': reviewNote,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    if (wish != null) {
      final approved = decision == WishStatus.approved;
      await NotificationService().sendNotification(
        toUid: wish!.requesterId,
        title: approved ? '✅ 願望通過了！' : '🥲 願望被婉拒了',
        body: wish!.title,
      );
    }
  }

  /// 提案修改（B 送出協商條件）
  Future<void> proposeNegotiation({
    required String wishId,
    required String negotiationNote,
  }) async {
    final ref = _db.collection('wishes').doc(wishId);
    WishModel? wish;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('找不到此願望');
      wish = WishModel.fromDoc(snap);
      if (wish!.partnerId != _myUid) throw Exception('無權提案此願望');
      if (wish!.status != WishStatus.pending) throw Exception('只能對待審核的願望提案');
      tx.update(ref, {
        'status': WishStatus.negotiating.name,
        'negotiationNote': negotiationNote,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    if (wish != null) {
      await NotificationService().sendNotification(
        toUid: wish!.requesterId,
        title: '💬 對方想和你商量一下',
        body: wish!.title,
      );
    }
  }

  /// A 接受協商提案 → 直接 approved
  Future<void> acceptNegotiation(String wishId) async {
    final ref = _db.collection('wishes').doc(wishId);
    WishModel? wish;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('找不到此願望');
      wish = WishModel.fromDoc(snap);
      if (wish!.requesterId != _myUid) throw Exception('無權接受此協商');
      if (wish!.status != WishStatus.negotiating) throw Exception('此願望不在協商狀態');
      tx.update(ref, {
        'status': WishStatus.approved.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    if (wish != null) {
      await NotificationService().sendNotification(
        toUid: wish!.partnerId,
        title: '🤝 對方接受了你的提案',
        body: wish!.title,
      );
    }
  }

  /// A 放棄協商 → rejected
  Future<void> declineNegotiation(String wishId) async {
    final ref = _db.collection('wishes').doc(wishId);
    WishModel? wish;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('找不到此願望');
      wish = WishModel.fromDoc(snap);
      if (wish!.requesterId != _myUid) throw Exception('無權拒絕此協商');
      if (wish!.status != WishStatus.negotiating) throw Exception('此願望不在協商狀態');
      tx.update(ref, {
        'status': WishStatus.rejected.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    if (wish != null) {
      await NotificationService().sendNotification(
        toUid: wish!.partnerId,
        title: '🥲 對方婉拒了這次的提案',
        body: wish!.title,
      );
    }
  }
}

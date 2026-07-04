import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/pair_model.dart';
import '../models/post_model.dart';
import 'backend.dart';
import 'notification_service.dart';

class PairService {
  PairService({FirebaseFirestore? db, FirebaseAuth? auth, http.Client? httpClient})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _http = httpClient ?? http.Client();

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final http.Client _http;

  String get _myUid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> _pairRef(String partnerId) =>
      _db.collection('pairs').doc(PairModel.pairIdFor(_myUid, partnerId));

  /// 確保配對共享文件存在（首次用到時自動建立，現有配對毋須遷移）
  Future<void> ensurePair(String partnerId) async {
    final ref = _pairRef(partnerId);
    // 文件已存在就直接返回：原本無條件 set+merge，每次呼叫（發悄悄話、
    // 存紀念日）都會把 createdAt 重寫成新的 serverTimestamp。
    if ((await ref.get()).exists) return;
    final members = [_myUid, partnerId]..sort();
    await ref.set({
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

  /// 讀出 events 原始 map 陣列。直接操作 raw map（不經 AnniversaryEvent.fromMap），
  /// 這樣即使陣列裡有單一筆髒資料，也不會在解析時整批拋錯、害新增／刪除失效。
  List<Map<String, dynamic>> _rawEvents(DocumentSnapshot<Map<String, dynamic>> snap) =>
      ((snap.data()?['events'] as List<dynamic>?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  /// 新增或更新一個紀念日（依 id 比對，read-modify-write 整個陣列）
  Future<void> saveEvent(String partnerId, AnniversaryEvent event) async {
    await ensurePair(partnerId);
    final ref = _pairRef(partnerId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final events = _rawEvents(snap);
      final map = event.toMap();
      final idx = events.indexWhere((e) => e['id'] == event.id);
      if (idx >= 0) {
        events[idx] = map;
      } else {
        events.add(map);
      }
      tx.set(ref, {'events': events}, SetOptions(merge: true));
    });
  }

  /// 刪除一個紀念日
  Future<void> deleteEvent(String partnerId, String eventId) async {
    final ref = _pairRef(partnerId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final events = _rawEvents(snap)..removeWhere((e) => e['id'] == eventId);
      tx.set(ref, {'events': events}, SetOptions(merge: true));
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

  /// 生成配對碼。實際的唯一碼產生 / 舊碼清除由後端以 Admin SDK 在
  /// transaction 內完成，client 僅帶 ID token 呼叫，避免越權寫入 pairCodes。
  Future<String> generatePairCode() async {
    final data = await _postAuthed('/pair/generate-code', const {});
    final code = data['code'] as String?;
    if (code == null) throw Exception('產生配對碼失敗，請稍後再試');
    return code;
  }

  /// 輸入配對碼，將雙方綁定為 partner。雙向綁定與配對碼刪除由後端
  /// 以 Admin SDK 在 transaction 內原子完成，杜絕競態與越權配對。
  Future<void> joinWithCode(String code) async {
    await _postAuthed('/pair/join', {'code': code.trim().toUpperCase()});
  }

  /// 解除配對
  ///
  /// 不用 atomic batch：若對方早已和別人重新配對，其 partnerId 已不指向我，
  /// rules 會擋下「清空對方 partnerId」這筆跨使用者寫入，整個 batch 便會失敗，
  /// 害我連自己這邊都解除不了。改為：先清掉自己（必定有權限），再「盡力」清對方。
  Future<void> unpair(String partnerId) async {
    final myUid = _auth.currentUser!.uid;
    await _db.collection('users').doc(myUid).update({'partnerId': null});
    try {
      await _db.collection('users').doc(partnerId).update({'partnerId': null});
    } catch (_) {
      // 對方狀態已改變（例如已重新配對），自己這邊解除即可，不視為失敗。
    }
  }

  /// 帶 Firebase ID token 呼叫後端；非 2xx 時以後端回傳的 error 訊息丟出例外。
  Future<Map<String, dynamic>> _postAuthed(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) throw Exception('尚未登入');
    final resp = await _http.post(
      Uri.parse('$backendBaseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    // 後端理應回 JSON；但遇到 gateway 502/504 之類的非 JSON 回應時，
    // 不讓 jsonDecode 的 FormatException 外漏，退回空 map 交由下方狀態碼處理。
    Map<String, dynamic> data;
    try {
      data = resp.body.isNotEmpty
          ? jsonDecode(resp.body) as Map<String, dynamic>
          : <String, dynamic>{};
    } catch (_) {
      data = <String, dynamic>{};
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) return data;
    throw Exception((data['error'] as String?) ?? '操作失敗（${resp.statusCode}）');
  }
}

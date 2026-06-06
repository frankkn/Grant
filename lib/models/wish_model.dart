import 'package:cloud_firestore/cloud_firestore.dart';

enum WishStatus { pending, approved, rejected, negotiating }

const wishCategories = ['約會', '禮物', '吃飯', '旅行', '小事', '撒嬌', '其他'];

class WishModel {
  final String id;
  final String requesterId;
  final String partnerId;
  final String title;
  final String price;
  final int heartRating;
  final String? productUrl;
  final String? description;
  final String reason;
  final DateTime scheduledAt;
  final WishStatus status;
  final bool isSecret;
  final String? reviewNote;
  final String? category;
  final String? negotiationNote;
  final bool isFulfilled;
  final String? fulfillmentNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  WishModel({
    required this.id,
    required this.requesterId,
    required this.partnerId,
    required this.title,
    required this.price,
    this.heartRating = 0,
    this.productUrl,
    this.description,
    required this.reason,
    required this.scheduledAt,
    required this.status,
    this.isSecret = false,
    this.reviewNote,
    this.category,
    this.negotiationNote,
    this.isFulfilled = false,
    this.fulfillmentNote,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 秘密許願且尚未到解鎖日 → 對方還不能查看/審核（紅點也不該計入）
  bool get isLockedSecret => isSecret && DateTime.now().isBefore(scheduledAt);

  factory WishModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WishModel(
      id: doc.id,
      requesterId: data['requesterId'] as String,
      partnerId: data['partnerId'] as String,
      // 秘密願望的內容欄位不存在主文件、改放 private/detail 子文件（見 WishService），
      // 故這些欄位以預設值容錯；實際內容由 service 在可讀時 overlay 回來。
      title: (data['title'] as String?) ?? '',
      price: (data['price'] as String?) ?? '',
      heartRating: (data['heartRating'] as int?) ?? 0,
      productUrl: data['productUrl'] as String?,
      description: data['description'] as String?,
      reason: (data['reason'] as String?) ?? '',
      scheduledAt: _dateFromTimestamp(data['scheduledAt']),
      status: WishStatus.values.byName(data['status'] as String),
      isSecret: (data['isSecret'] as bool?) ?? false,
      reviewNote: data['reviewNote'] as String?,
      category: data['category'] as String?,
      negotiationNote: data['negotiationNote'] as String?,
      isFulfilled: (data['isFulfilled'] as bool?) ?? false,
      fulfillmentNote: data['fulfillmentNote'] as String?,
      createdAt: _dateFromTimestamp(data['createdAt']),
      updatedAt: _dateFromTimestamp(data['updatedAt']),
    );
  }

  static DateTime _dateFromTimestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.now();
  }

  /// 內容欄位的 key（敏感、秘密願望解鎖前不可外洩給伴侶）
  static const contentKeys = [
    'title',
    'price',
    'productUrl',
    'description',
    'reason',
  ];

  /// 主文件欄位（含伴侶在解鎖前「本就可見」的 category / heartRating / scheduledAt），
  /// 不含敏感內容欄位。
  Map<String, dynamic> toMetaMap() => {
    'requesterId': requesterId,
    'partnerId': partnerId,
    'heartRating': heartRating,
    'scheduledAt': Timestamp.fromDate(scheduledAt),
    'status': status.name,
    'isSecret': isSecret,
    'reviewNote': reviewNote,
    'category': category,
    'negotiationNote': negotiationNote,
    'isFulfilled': isFulfilled,
    'fulfillmentNote': fulfillmentNote,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  /// 敏感內容欄位。公開願望寫在主文件；秘密願望寫在 private/detail 子文件。
  Map<String, dynamic> toContentMap() => {
    'title': title,
    'price': price,
    'productUrl': productUrl,
    'description': description,
    'reason': reason,
  };

  /// 把（從 private/detail 讀到的）內容覆蓋回來，產生完整的 WishModel。
  WishModel withContent(Map<String, dynamic> d) => _copyContent(
    title: (d['title'] as String?) ?? title,
    price: (d['price'] as String?) ?? price,
    productUrl: d['productUrl'] as String?,
    description: d['description'] as String?,
    reason: (d['reason'] as String?) ?? reason,
  );

  /// 清空敏感內容（伴侶在解鎖前；亦用於遮蔽舊資料殘留在主文件的內容）。
  WishModel redactedContent() => _copyContent(
    title: '',
    price: '',
    productUrl: null,
    description: null,
    reason: '',
  );

  WishModel _copyContent({
    required String title,
    required String price,
    required String? productUrl,
    required String? description,
    required String reason,
  }) => WishModel(
    id: id,
    requesterId: requesterId,
    partnerId: partnerId,
    title: title,
    price: price,
    heartRating: heartRating,
    productUrl: productUrl,
    description: description,
    reason: reason,
    scheduledAt: scheduledAt,
    status: status,
    isSecret: isSecret,
    reviewNote: reviewNote,
    category: category,
    negotiationNote: negotiationNote,
    isFulfilled: isFulfilled,
    fulfillmentNote: fulfillmentNote,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  WishModel copyWith({
    WishStatus? status,
    String? reviewNote,
    String? category,
    String? negotiationNote,
    bool? isFulfilled,
    String? fulfillmentNote,
  }) => WishModel(
    id: id,
    requesterId: requesterId,
    partnerId: partnerId,
    title: title,
    price: price,
    heartRating: heartRating,
    productUrl: productUrl,
    description: description,
    reason: reason,
    scheduledAt: scheduledAt,
    status: status ?? this.status,
    reviewNote: reviewNote ?? this.reviewNote,
    category: category ?? this.category,
    negotiationNote: negotiationNote ?? this.negotiationNote,
    isFulfilled: isFulfilled ?? this.isFulfilled,
    fulfillmentNote: fulfillmentNote ?? this.fulfillmentNote,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

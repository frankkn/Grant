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

  factory WishModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WishModel(
      id: doc.id,
      requesterId: data['requesterId'] as String,
      partnerId: data['partnerId'] as String,
      title: data['title'] as String,
      price: (data['price'] as String?) ?? '',
      heartRating: (data['heartRating'] as int?) ?? 0,
      productUrl: data['productUrl'] as String?,
      description: data['description'] as String?,
      reason: data['reason'] as String,
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

  Map<String, dynamic> toMap() => {
    'requesterId': requesterId,
    'partnerId': partnerId,
    'title': title,
    'price': price,
    'heartRating': heartRating,
    'productUrl': productUrl,
    'description': description,
    'reason': reason,
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

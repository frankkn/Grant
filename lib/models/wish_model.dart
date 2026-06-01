import 'package:cloud_firestore/cloud_firestore.dart';

enum WishStatus { pending, approved, rejected }

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
  final String? reviewNote;
  final bool isFulfilled;
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
    this.reviewNote,
    this.isFulfilled = false,
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
      reviewNote: data['reviewNote'] as String?,
      isFulfilled: (data['isFulfilled'] as bool?) ?? false,
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
    'reviewNote': reviewNote,
    'isFulfilled': isFulfilled,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  WishModel copyWith({
    WishStatus? status,
    String? reviewNote,
    bool? isFulfilled,
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
    isFulfilled: isFulfilled ?? this.isFulfilled,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

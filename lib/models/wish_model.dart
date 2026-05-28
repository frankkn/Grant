import 'package:cloud_firestore/cloud_firestore.dart';

enum WishStatus { pending, approved, rejected }

class WishModel {
  final String id;
  final String requesterId;
  final String partnerId;
  final String title;
  final String? price;
  final int heartRating;
  final String reason;
  final DateTime scheduledAt;
  final WishStatus status;
  final String? reviewNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  WishModel({
    required this.id,
    required this.requesterId,
    required this.partnerId,
    required this.title,
    this.price,
    this.heartRating = 0,
    required this.reason,
    required this.scheduledAt,
    required this.status,
    this.reviewNote,
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
      price: data['price'] as String?,
      heartRating: (data['heartRating'] as int?) ?? 0,
      reason: data['reason'] as String,
      scheduledAt: (data['scheduledAt'] as Timestamp).toDate(),
      status: WishStatus.values.byName(data['status'] as String),
      reviewNote: data['reviewNote'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'requesterId': requesterId,
        'partnerId': partnerId,
        'title': title,
        'price': price,
        'heartRating': heartRating,
        'reason': reason,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'status': status.name,
        'reviewNote': reviewNote,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  WishModel copyWith({WishStatus? status, String? reviewNote}) => WishModel(
        id: id,
        requesterId: requesterId,
        partnerId: partnerId,
        title: title,
        reason: reason,
        scheduledAt: scheduledAt,
        status: status ?? this.status,
        reviewNote: reviewNote ?? this.reviewNote,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

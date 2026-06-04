import 'package:cloud_firestore/cloud_firestore.dart';

/// 悄悄話動態牆的一則留言
class PostModel {
  final String id;
  final String authorId;
  final String text;
  final String mood; // 心情 emoji，可為空字串
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.authorId,
    required this.text,
    required this.mood,
    required this.createdAt,
  });

  factory PostModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      authorId: data['authorId'] as String,
      text: (data['text'] as String?) ?? '',
      mood: (data['mood'] as String?) ?? '',
      // serverTimestamp 寫入後本地快取可能短暫為 null，退回現在時間
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'text': text,
        'mood': mood,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

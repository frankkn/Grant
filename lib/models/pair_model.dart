import 'package:cloud_firestore/cloud_firestore.dart';

/// 紀念日類型
/// - together：在一起紀念日（會顯示「在一起 N 天」）
/// - birthday：生日
/// - custom：自訂紀念日（第一次約會、求婚日…）
enum AnniversaryType { together, birthday, custom }

class AnniversaryEvent {
  final String id;
  final String title;
  final DateTime date;
  final AnniversaryType type;

  AnniversaryEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
  });

  /// 自起始日到今天的天數（含當天為第 1 天）。僅對 together 有意義。
  int get daysTogether {
    final today = DateTime.now();
    final start = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    return t.difference(start).inDays + 1;
  }

  /// 下一次週年（同月日，今年或明年）
  DateTime get nextOccurrence {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    var next = DateTime(today.year, date.month, date.day);
    if (next.isBefore(t)) {
      next = DateTime(today.year + 1, date.month, date.day);
    }
    return next;
  }

  /// 距離下一次週年還有幾天（0 = 今天）
  int get daysUntilNext {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    return nextOccurrence.difference(t).inDays;
  }

  factory AnniversaryEvent.fromMap(Map<String, dynamic> data) {
    return AnniversaryEvent(
      id: data['id'] as String,
      title: data['title'] as String,
      date: (data['date'] as Timestamp).toDate(),
      type: AnniversaryType.values.byName(
        (data['type'] as String?) ?? 'custom',
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': Timestamp.fromDate(date),
        'type': type.name,
      };
}

class PairModel {
  final String id;
  final List<String> members;
  final List<AnniversaryEvent> events;

  PairModel({
    required this.id,
    required this.members,
    required this.events,
  });

  /// 由雙方 uid 推導出固定的配對文件 id（排序後拼接），
  /// 兩邊都算得出同一個 id，毋須額外儲存參照、亦免資料遷移。
  static String pairIdFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  factory PairModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawEvents = (data['events'] as List<dynamic>?) ?? [];
    return PairModel(
      id: doc.id,
      members: List<String>.from((data['members'] as List<dynamic>?) ?? []),
      events: rawEvents
          .map((e) => AnniversaryEvent.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

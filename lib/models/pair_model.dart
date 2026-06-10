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
  /// 起始日若被設成未來（尚未在一起）則回傳 0，避免顯示負數。
  int get daysTogether {
    final today = DateTime.now();
    final start = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    final days = t.difference(start).inDays + 1;
    return days < 0 ? 0 : days;
  }

  /// 下一次週年（同月日，今年或明年）
  DateTime get nextOccurrence {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    var next = _occurrenceInYear(today.year);
    if (next.isBefore(t)) {
      next = _occurrenceInYear(today.year + 1);
    }
    return next;
  }

  /// 指定年份的週年日。平年沒有 2/29 → 以 2/28 表示，
  /// 避免 DateTime(year, 2, 29) 在平年溢位成 3/1（與後端推播一致）。
  DateTime _occurrenceInYear(int year) {
    if (date.month == 2 && date.day == 29 && !_isLeapYear(year)) {
      return DateTime(year, 2, 28);
    }
    return DateTime(year, date.month, date.day);
  }

  static bool _isLeapYear(int y) =>
      (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  /// 建立時間（微秒）。id 產生時用的就是 microsecondsSinceEpoch 字串，
  /// 故可直接拿來排序「先後設定」——數字越大＝越晚設定＝越新。
  int get createdAtMicros => int.tryParse(id) ?? 0;

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
      type: _typeFromName(data['type']),
    );
  }

  /// 容錯解析 type：遇到未知 / 缺漏的字串時退回 custom，
  /// 避免單一筆髒資料讓整個 events 陣列解析拋錯、紀念日清單掛掉。
  static AnniversaryType _typeFromName(Object? value) {
    if (value is String) {
      final match = AnniversaryType.values.asNameMap()[value];
      if (match != null) return match;
    }
    return AnniversaryType.custom;
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

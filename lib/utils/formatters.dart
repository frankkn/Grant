import 'package:intl/intl.dart';

/// 全 App 統一的日期／時間格式工具

final _ymd = DateFormat('yyyy年M月d日');
final _md = DateFormat('M月d日');
final _mdHm = DateFormat('M月d日 HH:mm');

/// 2026年6月5日
String formatYmd(DateTime dt) => _ymd.format(dt.toLocal());

/// 6月5日
String formatMd(DateTime dt) => _md.format(dt.toLocal());

/// 6月5日 14:30
String formatMdHm(DateTime dt) => _mdHm.format(dt.toLocal());

/// 把日期夾進 [min, max] 範圍。
/// showDatePicker 的 initialDate 必須落在 firstDate..lastDate 之間，
/// 否則直接 assert 掛掉——過期的 pending 願望其 scheduledAt 會早於今天，
/// 編輯時開日期選擇器就會踩到，故先 clamp 再傳入。
DateTime clampDate(DateTime value, DateTime min, DateTime max) {
  if (value.isBefore(min)) return min;
  if (value.isAfter(max)) return max;
  return value;
}

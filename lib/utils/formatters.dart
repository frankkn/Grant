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

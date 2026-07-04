import 'package:flutter_test/flutter_test.dart';
import 'package:grant/utils/formatters.dart';

/// Bug 修復：編輯過期願望時 showDatePicker 的 initialDate 早於 firstDate
/// 會觸發 assertion crash。_pickDate 現在先以 clampDate 夾進合法範圍。
void main() {
  group('clampDate', () {
    final today = DateTime(2026, 7, 4);
    final last = today.add(const Duration(days: 365));

    test('過期日期（昨天）→ 夾回今天，不再越過 firstDate', () {
      final past = today.subtract(const Duration(days: 1));
      expect(clampDate(past, today, last), today);
    });

    test('很久以前的日期 → 一樣夾回今天', () {
      expect(clampDate(DateTime(2024, 1, 1), today, last), today);
    });

    test('範圍內的日期 → 原樣返回', () {
      final inRange = today.add(const Duration(days: 30));
      expect(clampDate(inRange, today, last), inRange);
    });

    test('邊界值：今天與最後一天都算範圍內', () {
      expect(clampDate(today, today, last), today);
      expect(clampDate(last, today, last), last);
    });

    test('超過上限的日期 → 夾回 lastDate', () {
      final beyond = last.add(const Duration(days: 10));
      expect(clampDate(beyond, today, last), last);
    });
  });
}

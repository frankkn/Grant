import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grant/widgets/unlock_ticker.dart';

// 註：testWidgets 在 FakeAsync 區執行，tester.pump(Duration) 推進的是假時鐘
// （驅動 Timer），但 DateTime.now() 讀真實時鐘，兩者脫鉤。故此處驗證的是
// UnlockTicker 的合約本身——「到排定的解鎖時刻會觸發一次 rebuild」——
// 以 builder 被呼叫的次數判斷，而非依賴 DateTime.now() 前進。
void main() {
  testWidgets('到解鎖時刻會觸發一次 rebuild', (tester) async {
    var builds = 0;
    await tester.pumpWidget(
      UnlockTicker(
        unlockTimes: [DateTime.now().add(const Duration(milliseconds: 200))],
        builder: (_) {
          builds++;
          return const SizedBox();
        },
      ),
    );
    final before = builds;
    await tester.pump(const Duration(milliseconds: 300)); // 越過解鎖時刻
    expect(builds, greaterThan(before), reason: '計時器到點應觸發 rebuild');
  });

  testWidgets('沒有未來解鎖時刻 → 不排計時器、不額外 rebuild', (tester) async {
    var builds = 0;
    await tester.pumpWidget(
      UnlockTicker(
        unlockTimes: [DateTime.now().subtract(const Duration(days: 1))],
        builder: (_) {
          builds++;
          return const SizedBox();
        },
      ),
    );
    final before = builds;
    await tester.pump(const Duration(seconds: 2));
    expect(builds, before, reason: '無未來解鎖 → 不應有計時器觸發 rebuild');
    // 若殘留未處理的 Timer，testWidgets 會在結束時報錯。
  });

  testWidgets('父層更新解鎖時刻 → 重排計時器並到點 rebuild', (tester) async {
    var builds = 0;
    Widget make(DateTime at) => UnlockTicker(
          unlockTimes: [at],
          builder: (_) {
            builds++;
            return const SizedBox();
          },
        );

    // 遠期解鎖：計時器被截斷成安全上限（1 天），短暫 pump 不應觸發。
    await tester.pumpWidget(make(DateTime.now().add(const Duration(days: 30))));
    await tester.pump(const Duration(milliseconds: 100));

    // 改成近未來 → didUpdateWidget 重排計時器
    await tester
        .pumpWidget(make(DateTime.now().add(const Duration(milliseconds: 200))));
    final afterReschedule = builds; // pumpWidget 本身造成一次 rebuild
    await tester.pump(const Duration(milliseconds: 300));
    expect(builds, greaterThan(afterReschedule), reason: '重排後的計時器應到點 rebuild');
  });
}

import 'dart:async';
import 'package:flutter/widgets.dart';

/// 在「最近一個未來解鎖時刻」自動 rebuild 一次子樹，讓依賴
/// [WishModel.isLockedSecret]（以 DateTime.now() 計算）的 UI——紅點數量、
/// 解鎖 banner、審核清單卡片——在秘密願望到點時即時更新，
/// 毋須等下一次 Firestore snapshot。
///
/// [builder] 回傳什麼都行（box 或 sliver），本 widget 只是透明轉發，
/// 故可同時用於一般版面與 CustomScrollView 的 slivers。
///
/// 父層資料變動（傳入新的 [unlockTimes]）時會重設計時器。
class UnlockTicker extends StatefulWidget {
  /// 秘密願望的 scheduledAt（解鎖時刻）集合；過去的時間會被忽略。
  final Iterable<DateTime> unlockTimes;
  final WidgetBuilder builder;

  const UnlockTicker({
    super.key,
    required this.unlockTimes,
    required this.builder,
  });

  @override
  State<UnlockTicker> createState() => _UnlockTickerState();
}

class _UnlockTickerState extends State<UnlockTicker> {
  Timer? _timer;

  // web 的 setTimeout 上限約 24.8 天；更遠的解鎖先排一段安全上限，
  // 到期後重新評估，避免超長延遲在瀏覽器上溢位、立刻誤觸發。
  static const _maxDelay = Duration(days: 1);

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(UnlockTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 資料每次更新都重排：以當下 wall-clock 重新計算，省去比對 Iterable 的麻煩。
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    DateTime? soonest;
    for (final t in widget.unlockTimes) {
      if (t.isAfter(now) && (soonest == null || t.isBefore(soonest))) {
        soonest = t;
      }
    }
    if (soonest == null) return;
    var delay = soonest.difference(now);
    if (delay > _maxDelay) delay = _maxDelay;
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _schedule(); // 重新評估下一個邊界（含被截斷的遠期解鎖）
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

import 'package:flutter/material.dart';
import '../models/pair_model.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/wish_model.dart';
import '../services/auth_service.dart';
import '../services/music_service.dart';
import '../services/pair_service.dart';
import '../services/wish_service.dart';
import '../widgets/unlock_ticker.dart';
import 'anniversary_screen.dart';
import 'login_screen.dart';
import 'memory_wall_screen.dart';
import 'pair_screen.dart';
import 'settings_screen.dart';
import 'whisper_screen.dart';
import '../widgets/mood_emoji.dart';
import 'wish_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();
  // 同一條 user stream 供 AppBar 與 body 共用，建立一次後快取，
  // 避免對使用者文件開兩個 listener，也避免 rebuild 時重訂閱。
  late final Stream<UserModel?> _userStream = _auth.watchCurrentUser();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grant'),
        actions: [
          StreamBuilder<UserModel?>(
            stream: _userStream,
            builder: (context, snap) => IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(partnerId: snap.data?.partnerId),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _auth.logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: _userStream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snap.data!;
          return GestureDetector(
            onTap: () => MusicService().startOnWeb(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/background.jpg', fit: BoxFit.cover),
                // 深色模式：在背景圖上加暗色遮罩，整體更沉穩
                if (Theme.of(context).brightness == Brightness.dark)
                  Container(color: Colors.black.withValues(alpha: 0.45)),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GreetingCard(user: user, auth: _auth),
                      if (user.partnerId != null)
                        Expanded(child: _PartnerSections(partnerId: user.partnerId!))
                      else
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: _NotebookButton(
                                icon: Icons.favorite_border,
                                label: '配對另一半',
                                onPressed: () {
                                  MusicService().startOnWeb();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const PairScreen()),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 頂部問候卡片
class _GreetingCard extends StatelessWidget {
  final UserModel user;
  final AuthService auth;
  const _GreetingCard({required this.user, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.pink.shade100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '你好，${user.displayName}！',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                user.partnerId != null
                    ? FutureBuilder<UserModel?>(
                        future: auth.fetchUser(user.partnerId!),
                        builder: (context, partnerSnap) {
                          final name = partnerSnap.data?.displayName;
                          return Text(
                            name != null ? '已和 $name 配對 ❤️' : '已配對 ❤️',
                            style: const TextStyle(color: Colors.pink),
                          );
                        },
                      )
                    : const Text('尚未配對',
                        style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/snowball.png',
              width: 90,
              height: 90,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}

/// 已配對首頁的主體：上方資訊容器（最多 3 則，越新越上）＋中間筆記本按鈕
/// ＋下方資訊（神秘心願溢位、悄悄話）。
///
/// 紀念日與神秘心願同源於這裡快取的兩條 stream（pair 與 incoming wishes），
/// 集中決定「神秘心願放上面或往下擠」，也讓 watchIncomingWishes 只訂閱一次。
class _PartnerSections extends StatefulWidget {
  final String partnerId;
  const _PartnerSections({required this.partnerId});

  @override
  State<_PartnerSections> createState() => _PartnerSectionsState();
}

class _PartnerSectionsState extends State<_PartnerSections> {
  // 建立一次後快取，避免外層 user-stream 每次 rebuild 都重新訂閱 Firestore。
  late final Stream<PairModel?> _pairStream =
      PairService().watchPair(widget.partnerId);
  late final Stream<List<WishModel>> _wishesStream =
      WishService().watchIncomingWishes(widget.partnerId);

  /// 首頁上方資訊容器最多顯示幾則
  static const _maxTop = 3;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PairModel?>(
      stream: _pairStream,
      builder: (context, pairSnap) {
        return StreamBuilder<List<WishModel>>(
          stream: _wishesStream,
          builder: (context, wishSnap) {
            final wishes = wishSnap.data ?? const <WishModel>[];
            return _layout(context, pairSnap.data, wishes);
          },
        );
      },
    );
  }

  Widget _layout(BuildContext context, PairModel? pair, List<WishModel> wishes) {
    // 紀念日：依「建立先後」新→舊排序（後設定的在上）。
    final anniversaries = [...(pair?.events ?? <AnniversaryEvent>[])]
      ..sort((a, b) => b.createdAtMicros.compareTo(a.createdAtMicros));
    final secrets = wishes.where((w) => w.isSecret).toList();
    final hasSecret = secrets.isNotEmpty;

    // 神秘心願視為「最新」：上方還有空位（紀念日 < 3）就放最頂端，
    // 否則 3 格被紀念日佔滿，神秘心願往下擠到底部。
    final secretInTop = hasSecret && anniversaries.length < _maxTop;
    final topAnniv =
        anniversaries.take(secretInTop ? _maxTop - 1 : _maxTop).toList();

    final topItems = <Widget>[
      if (secretInTop)
        _SecretUnlockBanner(secrets: secrets, partnerId: widget.partnerId),
      ...topAnniv.map(
          (e) => _AnniversaryBanner(event: e, partnerId: widget.partnerId)),
    ];
    final bottomItems = <Widget>[
      if (hasSecret && !secretInTop)
        _SecretUnlockBanner(secrets: secrets, partnerId: widget.partnerId),
      _LatestWhisperBanner(partnerId: widget.partnerId),
    ];

    // 用 Stack 把按鈕「固定錨」在區域中央（對準背景筆記本），banner 則釘在頂端／
    // 底端各自疊放。按鈕位置不再隨 banner 數量或非同步載入而上下跳動。
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.center,
          child: _notebook(context, wishes, secrets),
        ),
        // 上方資訊：釘在頂端，往下疊（最多 3 則）
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Column(mainAxisSize: MainAxisSize.min, children: topItems),
        ),
        // 下方資訊：釘在底端（神秘心願溢位 + 悄悄話）
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(mainAxisSize: MainAxisSize.min, children: bottomItems),
        ),
      ],
    );
  }

  Widget _notebook(
      BuildContext context, List<WishModel> wishes, List<WishModel> secrets) {
    return Transform.translate(
      // 往左移對齊筆記本；y 為從正中央的微調（單位 px，正值往下、負值往上）
      offset: const Offset(-15, -20),
      child: SizedBox(
        width: 150,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NotebookButton(
                icon: Icons.star,
                label: '前往許願',
                onPressed: () => _openWish(context, 0),
              ),
              const SizedBox(height: 10),
              _NotebookButton(
                icon: Icons.list_alt,
                label: '願望清單',
                onPressed: () => _openWish(context, 1),
              ),
              const SizedBox(height: 10),
              // 到解鎖時刻自動 rebuild，讓未審核數即時更新。
              UnlockTicker(
                unlockTimes: secrets.map((w) => w.scheduledAt),
                builder: (_) => _NotebookButton(
                  icon: Icons.fact_check_outlined,
                  label: '審核願望',
                  // 排除尚未解鎖的秘密許願，否則紅點清不掉
                  badgeCount: wishes.where((w) => !w.isLockedSecret).length,
                  onPressed: () => _openWish(context, 2),
                ),
              ),
              const SizedBox(height: 10),
              _NotebookButton(
                icon: Icons.auto_stories,
                label: '回憶牆',
                onPressed: () {
                  MusicService().startOnWeb();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MemoryWallScreen(partnerId: widget.partnerId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _NotebookButton(
                icon: Icons.chat_bubble_outline,
                label: '悄悄話',
                onPressed: () {
                  MusicService().startOnWeb();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WhisperScreen(partnerId: widget.partnerId),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWish(BuildContext context, int index) {
    MusicService().startOnWeb();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WishScreen(partnerId: widget.partnerId, initialIndex: index),
      ),
    );
  }
}

class _NotebookButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final int badgeCount;
  const _NotebookButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeCount > 0;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFCE4EC), // pink.shade50，同問候卡片
          foregroundColor: const Color(0xFFC2185B),
          padding: const EdgeInsets.symmetric(vertical: 9),
          elevation: 6,
          shadowColor: Colors.pink.withValues(alpha: 0.59),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 左側隱形佔位，與右側數字對稱，讓圖示＋文字維持置中、與其他按鈕對齊
            if (hasBadge) ...[
              Opacity(opacity: 0, child: _CountChip(count: badgeCount)),
              const SizedBox(width: 6),
            ],
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label),
            if (hasBadge) ...[
              const SizedBox(width: 6),
              _CountChip(count: badgeCount),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final int count;
  const _CountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// 首頁資訊橫幅的共用外觀
class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final Widget? leading;
  final VoidCallback? onTap;
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
    this.leading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 深色背景上提亮前景色以維持對比；底色也稍微加深
    final fg = isDark ? Color.lerp(color, Colors.white, 0.45)! : color;
    final bg = color.withValues(alpha: isDark ? 0.22 : 0.12);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 10),
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: fg, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: fg, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 單一紀念日倒數。
/// 文字格式：在一起類「在一起第 N 天，距離 名稱(M/D) 還有 X 天」；
/// 其他類「距離 名稱(M/D) 還有 X 天」；當天「今天是 名稱(M/D) 🎉」。
class _AnniversaryBanner extends StatelessWidget {
  final AnniversaryEvent event;
  final String partnerId;
  const _AnniversaryBanner({required this.event, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    return _InfoBanner(
      icon: Icons.favorite,
      color: Colors.pink,
      text: _text(event),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnniversaryScreen(partnerId: partnerId),
        ),
      ),
    );
  }

  static String _text(AnniversaryEvent e) {
    final days = e.daysUntilNext;
    final md = '${e.date.month}/${e.date.day}';
    if (days == 0) return '今天是 ${e.title}($md) 🎉';
    if (e.type == AnniversaryType.together) {
      return '在一起第 ${e.daysTogether} 天，距離 ${e.title}($md) 還有 $days 天';
    }
    return '距離 ${e.title}($md) 還有 $days 天';
  }
}

/// 即將／剛解鎖的神秘心願（不洩漏內容）。secrets 由 [_PartnerSections] 提供，
/// 同時用於上方容器或（被紀念日擠下時）底部。
class _SecretUnlockBanner extends StatelessWidget {
  final List<WishModel> secrets;
  final String partnerId;
  const _SecretUnlockBanner({required this.secrets, required this.partnerId});

  @override
  Widget build(BuildContext context) {
    if (secrets.isEmpty) return const SizedBox.shrink();
    // 到解鎖時刻自動 rebuild：讓「N 天後解鎖」即時翻成「已解鎖」。
    return UnlockTicker(
      unlockTimes: secrets.map((w) => w.scheduledAt),
      builder: (context) {
        // 已解鎖的優先提示，否則顯示最接近解鎖的那一個
        final unlocked = secrets.where((w) => !w.isLockedSecret).toList();
        if (unlocked.isNotEmpty) {
          return _InfoBanner(
            icon: Icons.lock_open,
            color: Colors.deepPurple,
            text: '有 ${unlocked.length} 個神秘心願已解鎖，快去看看 🎁',
            onTap: () => _openReview(context),
          );
        }
        final soonest = secrets
            .reduce((a, b) => a.scheduledAt.isBefore(b.scheduledAt) ? a : b);
        // 無條件進位：剩 1.9 天應顯示「2 天」而非截斷成「1 天」。
        final minutes =
            soonest.scheduledAt.difference(DateTime.now()).inMinutes;
        final days = (minutes / (60 * 24)).ceil();
        return _InfoBanner(
          icon: Icons.lock_clock,
          color: Colors.deepPurple,
          text: '神秘心願將在 ${days < 1 ? 1 : days} 天後解鎖 🎁',
        );
      },
    );
  }

  void _openReview(BuildContext context) {
    MusicService().startOnWeb();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WishScreen(partnerId: partnerId, initialIndex: 2),
      ),
    );
  }
}

/// 對方最新一則悄悄話（放在按鈕下方）
class _LatestWhisperBanner extends StatefulWidget {
  final String partnerId;
  const _LatestWhisperBanner({required this.partnerId});

  @override
  State<_LatestWhisperBanner> createState() => _LatestWhisperBannerState();
}

class _LatestWhisperBannerState extends State<_LatestWhisperBanner> {
  // 建立一次後快取，避免外層 user-stream 每次 rebuild 都重新訂閱 Firestore。
  late final Stream<List<PostModel>> _stream =
      PairService().watchPosts(widget.partnerId);

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid;
    return StreamBuilder<List<PostModel>>(
      stream: _stream,
      builder: (context, snap) {
        final posts = snap.data ?? [];
        // 只在對方有發文時提示
        final fromPartner = posts.where((p) => p.authorId != myUid).toList();
        if (fromPartner.isEmpty) return const SizedBox.shrink();
        final latest = fromPartner.first;
        return _InfoBanner(
          icon: Icons.chat_bubble,
          color: Colors.teal,
          leading: latest.mood.isEmpty ? null : moodEmoji(latest.mood, 16),
          text: latest.text,
          onTap: () {
            MusicService().startOnWeb();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WhisperScreen(partnerId: widget.partnerId),
              ),
            );
          },
        );
      },
    );
  }
}

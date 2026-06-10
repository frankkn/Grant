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
                Container(
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
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            user.partnerId != null
                                ? FutureBuilder<UserModel?>(
                                    future: _auth.fetchUser(user.partnerId!),
                                    builder: (context, partnerSnap) {
                                      final name = partnerSnap.data?.displayName;
                                      return Text(
                                        name != null
                                            ? '已和 $name 配對 ❤️'
                                            : '已配對 ❤️',
                                        style: const TextStyle(color: Colors.pink),
                                      );
                                    },
                                  )
                                : const Text(
                                    '尚未配對',
                                    style: TextStyle(color: Colors.grey),
                                  ),
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
                ),
                if (user.partnerId != null) ...[
                  _CountdownBanner(partnerId: user.partnerId!),
                  _SecretUnlockBanner(partnerId: user.partnerId!),
                  _LatestWhisperBanner(partnerId: user.partnerId!),
                ],
                Expanded(
                  child: Center(
                    child: user.partnerId == null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _NotebookButton(
                              icon: Icons.favorite_border,
                              label: '配對另一半',
                              onPressed: () {
                                MusicService().startOnWeb();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PairScreen()),
                                );
                              },
                            ),
                          )
                        : Transform.translate(
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
                                    onPressed: () => _openWish(context, user.partnerId!, 0),
                                  ),
                                  const SizedBox(height: 10),
                                  _NotebookButton(
                                    icon: Icons.list_alt,
                                    label: '願望清單',
                                    onPressed: () => _openWish(context, user.partnerId!, 1),
                                  ),
                                  const SizedBox(height: 10),
                                  _ReviewBadgeButton(
                                    partnerId: user.partnerId!,
                                    onPressed: () => _openWish(context, user.partnerId!, 2),
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
                                          builder: (_) => MemoryWallScreen(
                                            partnerId: user.partnerId!,
                                          ),
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
                                          builder: (_) => WhisperScreen(
                                            partnerId: user.partnerId!,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              ),
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

  void _openWish(BuildContext context, String partnerId, int index) {
    MusicService().startOnWeb();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WishScreen(partnerId: partnerId, initialIndex: index),
      ),
    );
  }
}

/// 「審核願望」按鈕＋未審核數徽章。
/// 獨立成 StatefulWidget 並在 initState 快取 stream，避免首頁外層（監聽使用者
/// 文件）每次 rebuild 都重建 watchIncomingWishes —— 那會造成重複 Firestore
/// 讀取（含每筆秘密願望的 private/detail overlay）與紅點閃爍。
class _ReviewBadgeButton extends StatefulWidget {
  final String partnerId;
  final VoidCallback onPressed;
  const _ReviewBadgeButton({required this.partnerId, required this.onPressed});

  @override
  State<_ReviewBadgeButton> createState() => _ReviewBadgeButtonState();
}

class _ReviewBadgeButtonState extends State<_ReviewBadgeButton> {
  // 建立一次後快取，避免每次 build 重新訂閱 Firestore。
  late final Stream<List<WishModel>> _stream =
      WishService().watchIncomingWishes(widget.partnerId);

  /// 可實際審核的待審願望數（排除尚未解鎖的秘密許願）
  static int _reviewableCount(List<WishModel>? wishes) {
    if (wishes == null) return 0;
    return wishes.where((w) => !w.isLockedSecret).length;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WishModel>>(
      stream: _stream,
      builder: (context, wishSnap) {
        final wishes = wishSnap.data;
        return UnlockTicker(
          unlockTimes: (wishes ?? [])
              .where((w) => w.isSecret)
              .map((w) => w.scheduledAt),
          builder: (context) => _NotebookButton(
            icon: Icons.fact_check_outlined,
            label: '審核願望',
            badgeCount: _reviewableCount(wishes),
            onPressed: widget.onPressed,
          ),
        );
      },
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
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                    maxLines: 1,
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

/// 最近的一個紀念日倒數
class _CountdownBanner extends StatelessWidget {
  final String partnerId;
  const _CountdownBanner({required this.partnerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PairModel?>(
      stream: PairService().watchPair(partnerId),
      builder: (context, snap) {
        final events = snap.data?.events ?? [];
        if (events.isEmpty) return const SizedBox.shrink();
        final next = events.reduce(
            (a, b) => a.daysUntilNext <= b.daysUntilNext ? a : b);
        final days = next.daysUntilNext;
        final String text;
        if (next.type == AnniversaryType.together && days != 0) {
          text = '在一起 ${next.daysTogether} 天　・　${next.title} 還有 $days 天';
        } else if (days == 0) {
          text = '今天是「${next.title}」🎉';
        } else {
          text = '距離「${next.title}」還有 $days 天';
        }
        return _InfoBanner(
          icon: Icons.favorite,
          color: Colors.pink,
          text: text,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AnniversaryScreen(partnerId: partnerId),
            ),
          ),
        );
      },
    );
  }
}

/// 即將／剛解鎖的神秘心願（不洩漏內容）
class _SecretUnlockBanner extends StatefulWidget {
  final String partnerId;
  const _SecretUnlockBanner({required this.partnerId});

  @override
  State<_SecretUnlockBanner> createState() => _SecretUnlockBannerState();
}

class _SecretUnlockBannerState extends State<_SecretUnlockBanner> {
  // 建立一次後快取，避免每次 build 重新訂閱 Firestore。
  late final Stream<List<WishModel>> _stream =
      WishService().watchIncomingWishes(widget.partnerId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WishModel>>(
      stream: _stream,
      builder: (context, snap) {
        final secrets = (snap.data ?? []).where((w) => w.isSecret).toList();
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
            final soonest = secrets.reduce(
                (a, b) => a.scheduledAt.isBefore(b.scheduledAt) ? a : b);
            // 無條件進位：剩 1.9 天應顯示「2 天」而非截斷成「1 天」。
            // 此分支只在仍有未解鎖秘密時出現（scheduledAt > now），故至少為 1。
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
      },
    );
  }

  void _openReview(BuildContext context) {
    MusicService().startOnWeb();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WishScreen(partnerId: widget.partnerId, initialIndex: 2),
      ),
    );
  }
}

/// 對方最新一則悄悄話
class _LatestWhisperBanner extends StatelessWidget {
  final String partnerId;
  const _LatestWhisperBanner({required this.partnerId});

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid;
    return StreamBuilder<List<PostModel>>(
      stream: PairService().watchPosts(partnerId),
      builder: (context, snap) {
        final posts = snap.data ?? [];
        // 只在對方有發文時提示
        final fromPartner =
            posts.where((p) => p.authorId != myUid).toList();
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
                builder: (_) => WhisperScreen(partnerId: partnerId),
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/wish_model.dart';
import '../services/auth_service.dart';
import '../services/music_service.dart';
import '../services/wish_service.dart';
import 'login_screen.dart';
import 'memory_wall_screen.dart';
import 'pair_screen.dart';
import 'settings_screen.dart';
import 'wish_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grant'),
        actions: [
          StreamBuilder<UserModel?>(
            stream: auth.watchCurrentUser(),
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
              await auth.logout();
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
        stream: auth.watchCurrentUser(),
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
                                    future: auth.fetchUser(user.partnerId!),
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
                Expanded(
                  child: Center(
                    child: user.partnerId == null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _NotebookButton(
                              icon: Icons.favorite_border,
                              label: '配對另一半',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PairScreen()),
                              ),
                            ),
                          )
                        : Transform.translate(
                            // 往左移，對齊偏左的筆記本
                            offset: const Offset(-16, 0),
                            child: SizedBox(
                              width: 161,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _NotebookButton(
                                    icon: Icons.star,
                                    label: '前往許願',
                                    onPressed: () => _openWish(context, user.partnerId!, 0),
                                  ),
                                  const SizedBox(height: 17),
                                  _NotebookButton(
                                    icon: Icons.list_alt,
                                    label: '願望清單',
                                    onPressed: () => _openWish(context, user.partnerId!, 1),
                                  ),
                                  const SizedBox(height: 17),
                                  StreamBuilder<List<WishModel>>(
                                    stream: WishService()
                                        .watchIncomingWishes(user.partnerId!),
                                    builder: (context, wishSnap) {
                                      return _NotebookButton(
                                        icon: Icons.fact_check_outlined,
                                        label: '審核願望',
                                        badgeCount: _reviewableCount(wishSnap.data),
                                        onPressed: () => _openWish(context, user.partnerId!, 2),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 17),
                                  _NotebookButton(
                                    icon: Icons.auto_stories,
                                    label: '回憶牆',
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MemoryWallScreen(
                                          partnerId: user.partnerId!,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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

  /// 可實際審核的待審願望數（排除尚未解鎖的秘密許願）
  static int _reviewableCount(List<WishModel>? wishes) {
    if (wishes == null) return 0;
    return wishes.where((w) => !w.isLockedSecret).length;
  }

  void _openWish(BuildContext context, String partnerId, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WishScreen(partnerId: partnerId, initialIndex: index),
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
          padding: const EdgeInsets.symmetric(vertical: 16),
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

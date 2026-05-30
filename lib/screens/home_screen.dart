import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
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
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('你好，${user.displayName}！',
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                Text(
                  user.partnerId != null ? '狀態：已配對 ❤️' : '狀態：尚未配對',
                  style: TextStyle(
                    color: user.partnerId != null ? Colors.pink : Colors.grey,
                  ),
                ),
                const Divider(height: 32),
                if (user.partnerId == null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.favorite_border),
                    label: const Text('配對另一半'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PairScreen()),
                    ),
                  ),
                if (user.partnerId != null) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.star),
                    label: const Text('許願 / 審核'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WishScreen(partnerId: user.partnerId!),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/name_setup_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/music_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try { await ThemeService().initialize(); } catch (_) {}
  try { await NotificationService().initialize(); } catch (_) {}
  try { await MusicService().initialize(); } catch (_) {}
  try { await AuthService().handleGoogleRedirectResult(); } catch (_) {}
  runApp(const GrantApp());
}

class GrantApp extends StatefulWidget {
  const GrantApp({super.key});

  @override
  State<GrantApp> createState() => _GrantAppState();
}

class _GrantAppState extends State<GrantApp> {
  @override
  void initState() {
    super.initState();
    // Flutter Web（CanvasKit）首次遇到 emoji 才會「非同步」下載彩色字型，且下載
    // 完成後不會自動重繪已排版好的文字 → emoji 第一次顯示會是灰階，要返回再進入
    // 該頁才恢復。這裡監聽字型載入事件，載入完成後重建一次，讓 emoji 即時補上色彩。
    PaintingBinding.instance.systemFonts.addListener(_onSystemFontsChanged);
  }

  void _onSystemFontsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onSystemFontsChanged);
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.pinkAccent,
          brightness: brightness,
        ),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService().mode,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'Grant',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: themeMode,
        // 寬螢幕（網頁／桌機）時，將內容限制在手機寬度的置中欄位，兩側留白；
        // 手機螢幕比 480 窄，這層不會有作用。
        builder: (context, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return ColoredBox(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFECECEC),
            child: Center(
              child: ClipRect(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
        home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.data == null) return const LoginScreen();
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snap.data!.uid).get(),
            builder: (context, userSnap) {
              if (!userSnap.hasData) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              final data = userSnap.data!.data() as Map<String, dynamic>?;
              final name = data?['displayName'] as String?;
              if (name == null || name.trim().isEmpty) return const NameSetupScreen();
              return const HomeScreen();
            },
          );
        },
        ),
      ),
    );
  }
}

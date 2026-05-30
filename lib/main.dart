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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try { await NotificationService().initialize(); } catch (_) {}
  try { await MusicService().initialize(); } catch (_) {}
  try { await AuthService().handleGoogleRedirectResult(); } catch (_) {}
  runApp(const GrantApp());
}

class GrantApp extends StatelessWidget {
  const GrantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
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
    );
  }
}

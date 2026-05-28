import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GrantApp());
}

class GrantApp extends StatelessWidget {
  const GrantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

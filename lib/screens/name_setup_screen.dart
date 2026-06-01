import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class NameSetupScreen extends StatefulWidget {
  const NameSetupScreen({super.key});

  @override
  State<NameSetupScreen> createState() => _NameSetupScreenState();
}

class _NameSetupScreenState extends State<NameSetupScreen> {
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '請輸入你的暱稱');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      await AuthService().updateDisplayName(name);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      setState(() => _error = '錯誤：$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.favorite, color: Colors.pinkAccent, size: 64),
            const SizedBox(height: 24),
            const Text(
              '你想讓另一半怎麼稱呼你？',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                hintText: '輸入你的暱稱',
                border: OutlineInputBorder(),
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
              autofocus: true,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('確認', style: TextStyle(fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}

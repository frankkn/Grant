import 'package:flutter/material.dart';
import '../services/pair_service.dart';

class PairScreen extends StatefulWidget {
  const PairScreen({super.key});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _pairService = PairService();
  final _codeCtrl = TextEditingController();
  String? _generatedCode;
  String? _message;

  Future<void> _generate() async {
    try {
      final code = await _pairService.generatePairCode();
      setState(() {
        _generatedCode = code;
        _message = null;
      });
    } catch (e) {
      setState(() => _message = '錯誤：$e');
    }
  }

  Future<void> _join() async {
    try {
      await _pairService.joinWithCode(_codeCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配對成功！ ❤️')),
      );
      Navigator.of(context).pop(); // 返回首頁，首頁會透過 stream 即時更新配對狀態
    } catch (e) {
      setState(() => _message = '錯誤：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('情侶配對')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('方式一：生成配對碼（10 分鐘內有效）',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _generate,
              child: const Text('生成我的配對碼'),
            ),
            if (_generatedCode != null)
              SelectableText(
                '你的配對碼：$_generatedCode',
                style: const TextStyle(fontSize: 24, letterSpacing: 4),
                textAlign: TextAlign.center,
              ),
            const Divider(height: 40),
            const Text('方式二：輸入另一半的配對碼',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: '輸入配對碼',
                hintText: 'XXXXXX',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _join,
              child: const Text('確認配對'),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_message!,
                    style: TextStyle(
                      color: _message!.startsWith('錯誤') ? Colors.red : Colors.green,
                    )),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/pair_service.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  final String? partnerId;
  const SettingsScreen({super.key, this.partnerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          if (partnerId != null)
            ListTile(
              leading: const Icon(Icons.link_off, color: Colors.red),
              title: const Text('解除配對', style: TextStyle(color: Colors.red)),
              onTap: () => _showUnpairDialog(context),
            ),
        ],
      ),
    );
  }

  void _showUnpairDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _UnpairDialog(partnerId: partnerId!),
    );
  }
}

class _UnpairDialog extends StatefulWidget {
  final String partnerId;
  const _UnpairDialog({required this.partnerId});

  @override
  State<_UnpairDialog> createState() => _UnpairDialogState();
}

class _UnpairDialogState extends State<_UnpairDialog> {
  final _ctrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  bool get _canConfirm => _ctrl.text == '我確定';

  Future<void> _confirm() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await PairService().unpair(widget.partnerId);
      if (mounted) {
        Navigator.of(context).pop(); // 關閉 dialog
        Navigator.of(context).pop(); // 返回首頁
      }
    } catch (e) {
      setState(() { _error = '錯誤：$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('解除配對'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '解除配對無法復原，雙方的配對關係將立即消除。',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          const Text('請輸入「我確定」以繼續：'),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              hintText: '我確定',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('返回'),
        ),
        ElevatedButton(
          onPressed: _canConfirm && !_isLoading ? _confirm : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('確認'),
        ),
      ],
    );
  }
}

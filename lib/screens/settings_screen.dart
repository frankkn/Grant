import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/pair_service.dart';
import '../services/auth_service.dart';
import '../services/music_service.dart';

class SettingsScreen extends StatefulWidget {
  final String? partnerId;
  const SettingsScreen({super.key, this.partnerId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _music = MusicService();
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      setState(() => _version = 'v${info.version}');
    });
  }

  Future<void> _changeVolume(int delta) async {
    await _music.setVolume(_music.volume + delta);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('音量'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _music.volume > 0 ? () => _changeVolume(-10) : null,
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${_music.volume}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _music.volume < 100 ? () => _changeVolume(10) : null,
                ),
              ],
            ),
          ),
          const Divider(),
          if (widget.partnerId != null)
            ListTile(
              leading: const Icon(Icons.link_off, color: Colors.red),
              title: const Text('解除配對', style: TextStyle(color: Colors.red)),
              onTap: () => _showUnpairDialog(context),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.grey),
            title: const Text('版本', style: TextStyle(color: Colors.grey)),
            trailing: Text(_version, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showUnpairDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _UnpairDialog(partnerId: widget.partnerId!),
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

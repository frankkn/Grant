import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/user_model.dart';
import '../services/pair_service.dart';
import '../services/auth_service.dart';
import '../services/music_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import 'anniversary_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String? partnerId;
  const SettingsScreen({super.key, this.partnerId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _music = MusicService();
  final _auth = AuthService();
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
          StreamBuilder<UserModel?>(
            stream: _auth.watchCurrentUser(),
            builder: (context, snap) {
              final name = snap.data?.displayName;
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('暱稱'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (name != null)
                      Text(name, style: const TextStyle(fontSize: 16)),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                onTap: name == null
                    ? null
                    : () => _showRenameDialog(context, name),
              );
            },
          ),
          const Divider(),
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
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService().mode,
            builder: (context, mode, _) => ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('外觀'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_themeLabel(mode), style: const TextStyle(fontSize: 16)),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              onTap: () => _showThemePicker(context, mode),
            ),
          ),
          const Divider(),
          const _NotificationTile(),
          const Divider(),
          if (widget.partnerId != null)
            ListTile(
              leading: const Icon(Icons.cake_outlined, color: Colors.pink),
              title: const Text('紀念日'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AnniversaryScreen(partnerId: widget.partnerId!),
                ),
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

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => '跟隨系統',
        ThemeMode.light => '淺色',
        ThemeMode.dark => '深色',
      };

  void _showThemePicker(BuildContext context, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((m) {
            return RadioListTile<ThemeMode>(
              value: m,
              groupValue: current,
              title: Text(_themeLabel(m)),
              onChanged: (v) {
                if (v != null) ThemeService().setMode(v);
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String currentName) {
    showDialog(
      context: context,
      builder: (context) => _RenameDialog(currentName: currentName),
    );
  }

  void _showUnpairDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _UnpairDialog(partnerId: widget.partnerId!),
    );
  }
}

/// 推播通知開關。顯示目前狀態（開／關／被系統封鎖），並讓使用者切換接收。
/// 「關閉」是移除 token 停止接收，不會（也無法）收回系統權限。
class _NotificationTile extends StatefulWidget {
  const _NotificationTile();

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile>
    with WidgetsBindingObserver {
  NotificationStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回到前景時重新讀取：使用者可能剛去系統設定改了通知權限。
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final s = await NotificationService().currentStatus();
    if (mounted) setState(() => _status = s);
  }

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (on) {
        final granted = await NotificationService().enable();
        if (!granted && mounted) {
          messenger.showSnackBar(const SnackBar(
            content: Text('尚未取得通知權限，請到系統／瀏覽器設定允許後再試'),
          ));
        }
      } else {
        await NotificationService().disable();
      }
    } finally {
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final blocked = status == NotificationStatus.blocked;
    final (String subtitle, Color subColor) = switch (status) {
      null => ('檢查中…', Colors.grey),
      NotificationStatus.enabled => ('已開啟，收得到對方的悄悄話與許願通知', Colors.grey),
      NotificationStatus.disabled => ('已關閉，開啟開關即可開始接收', Colors.grey),
      NotificationStatus.blocked =>
        ('已被系統封鎖，請到裝置設定開啟本 App 的通知權限', Colors.orange),
    };
    return ListTile(
      leading: const Icon(Icons.notifications_active_outlined, color: Colors.pink),
      title: const Text('推播通知'),
      subtitle: Text(subtitle, style: TextStyle(color: subColor, fontSize: 12)),
      trailing: (_busy || status == null)
          ? const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Switch(
              value: status == NotificationStatus.enabled,
              onChanged: blocked ? null : _toggle,
            ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final String currentName;
  const _RenameDialog({required this.currentName});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _ctrl = TextEditingController(text: widget.currentName);
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '請輸入你的暱稱');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      await AuthService().updateDisplayName(name);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _error = '錯誤：$e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改暱稱'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '輸入你的暱稱',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _isLoading ? null : _save(),
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
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('儲存'),
        ),
      ],
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
      if (mounted) setState(() { _error = '錯誤：$e'; _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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

import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicService {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  AudioPlayer? _player;
  static const _volumeKey = 'music_volume';
  static const _audioFile = 'audio/Velvet Clipboard.mp3';
  int _volume = 70;
  bool _started = false;

  int get volume => _volume;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _volume = prefs.getInt(_volumeKey) ?? 70;

    if (kIsWeb) return; // Web 等使用者互動後再播

    _player = AudioPlayer();
    await _player!.setReleaseMode(ReleaseMode.loop);
    await _player!.setVolume(_volume / 100);
    if (_volume > 0) {
      await _player!.play(AssetSource(_audioFile));
    }
  }

  // Web 上使用者互動後呼叫
  Future<void> startOnWeb() async {
    if (!kIsWeb || _started || _volume == 0) return;
    _started = true;
    try {
      _player = AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setVolume(_volume / 100);
      await _player!.play(AssetSource(_audioFile));
    } catch (_) {}
  }

  Future<void> setVolume(int volume) async {
    _volume = volume.clamp(0, 100);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_volumeKey, _volume);

    try {
      if (_player == null) return;
      if (_volume == 0) {
        await _player!.pause();
      } else {
        await _player!.setVolume(_volume / 100);
        if (_player!.state != PlayerState.playing) {
          await _player!.play(AssetSource(_audioFile));
        }
      }
    } catch (_) {}
  }
}

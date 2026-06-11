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
  // 靜音前的音量，供「開啟聲音」還原；使用者從未開過聲音時預設還原成 50。
  int _lastVolume = 50;

  int get volume => _volume;
  bool get isMuted => _volume == 0;

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

  /// 一鍵切換靜音 / 開啟聲音。靜音＝音量設 0 並記住原音量；
  /// 開啟＝還原靜音前的音量（從未開過聲音則用預設 50）。
  Future<void> toggleMute() async {
    if (_volume > 0) {
      _lastVolume = _volume;
      await setVolume(0);
    } else {
      await setVolume(_lastVolume > 0 ? _lastVolume : 50);
    }
  }

  Future<void> setVolume(int volume) async {
    _volume = volume.clamp(0, 100);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_volumeKey, _volume);

    try {
      // Web 上播放器要等使用者互動後才建立；若尚未建立（_player == null）而此次
      // 調高音量本身就是使用者手勢，直接在此啟動播放，不必等下一次導頁。
      if (_player == null) {
        if (_volume > 0) await startOnWeb();
        return;
      }
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

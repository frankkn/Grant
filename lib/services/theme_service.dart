import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全 App 的主題模式（淺色／深色／跟隨系統），偏好存於 shared_preferences。
/// 用 ValueNotifier 讓 MaterialApp 在切換時即時重建。
class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const _key = 'theme_mode';

  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    mode.value = _parse(prefs.getString(_key));
  }

  Future<void> setMode(ThemeMode m) async {
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, m.name);
  }

  static ThemeMode _parse(String? v) => ThemeMode.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ThemeMode.system,
      );
}

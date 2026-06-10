import 'package:flutter/material.dart';

// 心情 emoji → 內建小圖。Firestore 仍存 emoji 字串（與 Android 原生、既有資料
// 相容），這些圖只用於「顯示」，避免 Flutter Web 字型 emoji 首次載入時變灰階。
const moodAssets = {
  '❤️': 'assets/emoji/heart.png',
  '😊': 'assets/emoji/smile.png',
  '🥰': 'assets/emoji/love.png',
  '😢': 'assets/emoji/cry.png',
  '😡': 'assets/emoji/angry.png',
  '🤔': 'assets/emoji/think.png',
  '😴': 'assets/emoji/sleep.png',
  '🎉': 'assets/emoji/party.png',
};

/// 以內建小圖渲染心情 emoji；未知字串（理論上不會發生）退回純文字。
Widget moodEmoji(String mood, double size) {
  final asset = moodAssets[mood];
  if (asset == null) return Text(mood, style: TextStyle(fontSize: size));
  return Image.asset(asset, width: size, height: size);
}

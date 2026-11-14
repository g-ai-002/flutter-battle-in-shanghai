import 'package:flutter/material.dart';

import '../theme/battle_painting.dart';

/// 文字缓存键：内容与样式组成记录，命中比较不拼接字符串。
typedef _LabelKey = (String, double, int, int, double);

/// 战场文字缓存：按内容与样式复用 [TextPainter]。
///
/// 浮动分数与波次提示每帧都在重排，缓存后只在文字或样式真正变化时才
/// 重新 layout；透明度先量化到固定档位，避免同一个字每帧都被当成新 key。
class BattleLabelCache {
  /// 缓存条目上限，超出后淘汰最久未使用的一条。
  static const int maxEntries = 96;

  /// 透明度量化档数。
  static const int alphaSteps = 10;

  final Map<_LabelKey, TextPainter> _painters = {};

  /// 当前缓存的条目数。
  int get length => _painters.length;

  /// 把透明度量化到固定档位，缓存 key 不再逐帧变化。
  static Color steady(Color color) =>
      color.withValues(alpha: (color.a * alphaSteps).round() / alphaSteps);

  /// 取一支排好版的画笔；相同文字与样式返回同一实例。
  TextPainter painter(
    String text,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w600,
    double spacing = 0,
  }) {
    final key = (text, size, color.toARGB32(), weight.value, spacing);
    final cached = _painters.remove(key);
    if (cached != null) {
      _painters[key] = cached;
      return cached;
    }
    if (_painters.length >= maxEntries) {
      final oldest = _painters.keys.first;
      _painters.remove(oldest)?.dispose();
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: battlefieldLabelStyle(
          fontSize: size,
          color: color,
          weight: weight,
          letterSpacing: spacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _painters[key] = painter;
    return painter;
  }

  /// 释放全部排版资源。
  void dispose() {
    for (final painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
  }
}

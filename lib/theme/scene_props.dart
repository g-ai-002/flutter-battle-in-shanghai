import 'package:flutter/material.dart';

import '../game/battle_scenes.dart';
import 'paint_kit.dart';
import 'scene_palette.dart';

/// 阵地专属景物：闸北的断墙瓦砾、外滩的江堤栏杆、四行仓库的砖墙木箱。
///
/// 整层不随时间变化，由 `SceneCache` 预渲染成位图，战斗中不再重复绘制。
void paintSceneProps(
  Canvas canvas,
  Size size,
  BattleScene scene,
  ScenePalette palette,
) {
  switch (scene) {
    case BattleScene.zhabei:
      // 塌了半边的砖墙与散落的瓦砾。
      final brick = fillPaint(const Color(0xFF4A3628));
      final mortar = strokePaint(const Color(0xFF684C38), 0.7);
      for (final x in [34.0, 232.0]) {
        canvas.drawRect(Rect.fromLTWH(x, 96, 34, 46), brick);
        canvas.drawRect(Rect.fromLTWH(x, 96, 34, 46), mortar);
        for (var row = 1; row < 4; row++) {
          canvas.drawLine(
            Offset(x, 96 + row * 11.5),
            Offset(x + 34, 96 + row * 11.5),
            mortar,
          );
        }
        canvas.drawLine(Offset(x + 17, 96), Offset(x + 17, 142), mortar);
      }
      final rubble = fillPaint(palette.rubble);
      for (var i = 0; i < 7; i++) {
        final seed = i * 53.9;
        canvas.drawCircle(
          Offset(44 + (seed * 9) % 210, 196 + (seed * 5) % 150),
          3 + (seed % 4),
          rubble,
        );
      }
    case BattleScene.bund:
      // 远处江面：横向波纹与对岸灯火。
      final water = fillPaint(const Color(0xFF1B2733));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 42), water);
      final shimmer = strokePaint(palette.beam.withValues(alpha: 0.20), 0.8);
      for (var i = 0; i < 7; i++) {
        final y = 6.0 + i * 5;
        final offset = (i * 37) % 60.0;
        canvas.drawLine(Offset(offset, y), Offset(offset + 46, y), shimmer);
      }
      for (var i = 0; i < 6; i++) {
        canvas.drawCircle(
          Offset(30 + i * 46.0, 3.5),
          1.1,
          fillPaint(palette.window.withValues(alpha: 0.45)),
        );
      }
      // 江堤石栏与两盏路灯。
      final rail = strokePaint(const Color(0xFF5A6672), 1.0);
      canvas.drawLine(const Offset(0, 46), Offset(size.width, 46), rail);
      for (var i = 0; i < 8; i++) {
        canvas.drawLine(
          Offset(12 + i * 38.0, 40),
          Offset(12 + i * 38.0, 52),
          rail,
        );
      }
      for (final x in [46.0, 254.0]) {
        canvas.drawLine(
          Offset(x, 60),
          Offset(x, 108),
          strokePaint(const Color(0xFF3B434C), 1.6),
        );
        canvas.drawCircle(
          Offset(x, 58),
          2.2,
          fillPaint(palette.window.withValues(alpha: 0.75)),
        );
      }
    case BattleScene.warehouse:
      // 仓库砖墙与堆在墙根的木箱。
      final wall = fillPaint(const Color(0xFF4C3128));
      final brick = strokePaint(const Color(0xFF6B4736), 0.6);
      for (final x in [27.0, 251.0]) {
        canvas.drawRect(Rect.fromLTWH(x, 56, 22, size.height - 140), wall);
        for (var y = 56.0; y < size.height - 84; y += 9) {
          canvas.drawLine(Offset(x, y), Offset(x + 22, y), brick);
        }
      }
      final crate = fillPaint(const Color(0xFF6B5233));
      final crateEdge = strokePaint(const Color(0xFFC79A5B), 1.0);
      for (final spot in const [
        Offset(48, 176),
        Offset(66, 214),
        Offset(246, 250),
      ]) {
        final box = Rect.fromCenter(center: spot, width: 16, height: 14);
        canvas.drawRect(box, crate);
        canvas.drawRect(box, crateEdge);
        canvas.drawLine(
          box.topLeft,
          box.bottomRight,
          strokePaint(const Color(0xFFC79A5B), 0.7),
        );
      }
      final smear = fillPaint(const Color(0x33000000));
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(150, 150), width: 86, height: 26),
        smear,
      );
    case BattleScene.suzhou:
      // 苏州河：河面、钢桁架与桥头系缆桩。
      final river = Rect.fromLTWH(0, 0, size.width, 40);
      canvas.drawRect(river, fillPaint(const Color(0xFF142426)));
      final ripple = strokePaint(palette.beam.withValues(alpha: 0.16), 0.8);
      for (var i = 0; i < 6; i++) {
        final y = 6.0 + i * 6;
        final x = (i * 43) % 74.0;
        canvas.drawLine(Offset(x, y), Offset(x + 56, y), ripple);
      }
      final steel = strokePaint(const Color(0xFF46595B), 2.2);
      final rivet = fillPaint(const Color(0xFF718587));
      for (final left in [true, false]) {
        for (var i = 0; i < 5; i++) {
          final y = 54.0 + i * 72;
          final x0 = left ? 0.0 : size.width;
          final x1 = left ? 34.0 : size.width - 34;
          canvas.drawLine(Offset(x0, y), Offset(x1, y + 46), steel);
          canvas.drawLine(Offset(x0, y + 46), Offset(x1, y + 92), steel);
          canvas.drawCircle(
            Offset(left ? 7 : size.width - 7, y + 22),
            1.6,
            rivet,
          );
        }
      }
      canvas.drawLine(
        const Offset(0, 44),
        Offset(size.width, 44),
        strokePaint(const Color(0xFF5C6E6F), 1.2),
      );
      for (final x in [40.0, 260.0]) {
        final post = Rect.fromLTWH(x - 3, 176, 6, 12);
        canvas.drawRect(post, fillPaint(const Color(0xFF3D4B4C)));
      }
  }
}

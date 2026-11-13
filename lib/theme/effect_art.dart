import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/battle_config.dart';
import 'art_palette.dart';
import 'paint_kit.dart';

/// 战斗特效与可拾取物：爆炸、枪口火光、补给箱、工事与空袭飞机。

/// 爆炸：扩散光环 + 火球 + 放射碎屑。
void paintExplosion(
  Canvas canvas,
  Offset center,
  double radius,
  double progress,
) {
  final ease = 1 - math.pow(1 - progress, 2.4).toDouble();
  final alpha = (1 - progress).clamp(0.0, 1.0);
  final r = radius * (0.35 + ease * 0.95);
  // 半径与透明度量化后复用画笔：一场爆炸的 30 来帧只建一次 shader。
  final alphaStep = (alpha * 20).round();
  final alphaValue = alphaStep / 20;
  final radiusStep = (r * 2).round();
  final radiusValue = radiusStep / 2;
  final core = radialPaint(
    0x10000 + radiusStep * 32 + alphaStep,
    radiusValue,
    [
      Color.fromRGBO(255, 226, 168, alphaValue * 0.95),
      Color.fromRGBO(255, 138, 61, alphaValue * 0.7),
      Color.fromRGBO(194, 69, 47, alphaValue * 0.25),
      const Color(0x00C2452F),
    ],
    const [0, 0.35, 0.72, 1],
  );
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.drawCircle(Offset.zero, radiusValue, core);
  canvas.drawCircle(
    Offset.zero,
    r * (0.9 + progress * 0.4),
    strokePaint(const Color(0xFFFFD9A0).withValues(alpha: alpha * 0.35), 1.6),
  );
  final ray = strokePaint(
    const Color(0xFFFFC46B).withValues(alpha: alpha * 0.7),
    1.4,
  )..strokeCap = StrokeCap.round;
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4 + progress * 0.6;
    final inner = r * 0.35;
    final outer = r * (1.05 + (i.isEven ? 0.35 : 0.15));
    canvas.drawLine(
      Offset(math.cos(angle) * inner, math.sin(angle) * inner),
      Offset(math.cos(angle) * outer, math.sin(angle) * outer),
      ray,
    );
  }
  canvas.restore();
}

/// 枪口火光：短促的星形。
void paintMuzzle(Canvas canvas, Offset center, double radius, double alpha) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4;
    final r = i.isEven ? radius : radius * 0.42;
    final point = Offset(
      center.dx + math.cos(angle) * r,
      center.dy + math.sin(angle) * r,
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  canvas.drawPath(
    path,
    fillPaint(const Color(0xFFFFE1A1).withValues(alpha: alpha)),
  );
}

/// 补给箱：木箱 + 内部图标。
void paintPickup(
  Canvas canvas,
  Offset center,
  PickupKind kind,
  double bob, {
  double fade = 1,
}) {
  final y = center.dy + math.sin(bob) * 2;
  final fadeStep = (fade * 10).round();
  final glow = radialPaint(
    0x20000 + fadeStep,
    14,
    [
      Color.fromRGBO(255, 217, 160, 0.24 * fadeStep / 10),
      const Color(0x00FFD9A0),
    ],
    const [0, 1],
  );
  canvas.save();
  canvas.translate(center.dx, y);
  canvas.drawCircle(Offset.zero, 14, glow);
  final box = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: 17, height: 17),
    const Radius.circular(3),
  );
  canvas.drawRRect(
    box,
    fillPaint(const Color(0xFF6B5233).withValues(alpha: fade)),
  );
  canvas.drawRRect(
    box,
    strokePaint(const Color(0xFFC79A5B).withValues(alpha: fade), 1.2),
  );
  final icon = strokePaint(const Color(0xFFFFEBC7).withValues(alpha: fade), 2)
    ..strokeCap = StrokeCap.round;
  switch (kind) {
    case PickupKind.medkit:
      canvas.drawLine(const Offset(-4, 0), const Offset(4, 0), icon);
      canvas.drawLine(const Offset(0, -4), const Offset(0, 4), icon);
    case PickupKind.ammo:
      for (final x in [-3.5, 0.0, 3.5]) {
        canvas.drawLine(Offset(x, -4), Offset(x, 4), icon);
      }
    case PickupKind.shield:
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 4.6),
        math.pi,
        math.pi,
        false,
        icon,
      );
      canvas.drawLine(const Offset(-4.6, 0), const Offset(4.6, 0), icon);
  }
  canvas.restore();
}

/// 工事图形以中心为原点时的外接范围（含阴影、描边与裂缝），供缓存取图。
const double kCoverArtLeft = -30;
const double kCoverArtTop = -14;
const double kCoverArtWidth = 72;
const double kCoverArtHeight = 28;

/// 工事：两排沙袋堆成的临时掩体，血量越低颜色越灰、还带裂缝。
void paintCoverWall(
  Canvas canvas,
  Offset center,
  double hpRatio,
  double time,
  double shake,
) {
  final jitter = shake > 0 ? math.sin(time * 70) * shake * 1.6 : 0.0;
  canvas.save();
  canvas.translate(center.dx + jitter, center.dy);
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(0, 6), width: 56, height: 12),
    fillPaint(const Color(0x55000000)),
  );
  final wear = (1 - hpRatio).clamp(0.0, 1.0);
  final bagColor = Color.lerp(kSandbag, const Color(0xFF6B5A44), wear * 0.6)!;
  final light = Color.lerp(kSandbagLight, const Color(0xFF8A7A60), wear * 0.5)!;
  for (var row = 0; row < 2; row++) {
    final y = row == 0 ? -6.0 : 3.0;
    final offset = row == 0 ? 0.0 : 8.0;
    for (var i = 0; i < 4; i++) {
      final x = -26 + offset + i * 15 - (row == 0 ? 0 : 3);
      final bag = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 16, 10),
        const Radius.circular(4),
      );
      canvas.drawRRect(bag, fillPaint(bagColor));
      canvas.drawRRect(bag, strokePaint(light.withValues(alpha: 0.6), 0.8));
    }
  }
  if (wear > 0.35) {
    final crack = strokePaint(
      const Color(0x66000000).withValues(alpha: 0.35 + wear * 0.3),
      0.9,
    );
    canvas.drawLine(const Offset(-14, -6), const Offset(-6, 2), crack);
    canvas.drawLine(const Offset(-6, 2), const Offset(-2, -4), crack);
    canvas.drawLine(const Offset(9, 3), const Offset(15, -4), crack);
  }
  canvas.restore();
}

/// 空袭轰炸机：从左侧掠过战场上空，机翼下挂着航弹。
void paintAirstrikePlane(Canvas canvas, Size size, double progress) {
  final x = -46 + progress * (size.width + 92);
  const y = 44.0;
  final alpha = (1 - (progress - 0.5).abs() * 1.4).clamp(0.0, 1.0);
  if (alpha <= 0) return;
  canvas.save();
  canvas.translate(x, y);
  // 尾迹
  final trail = strokePaint(
    const Color(0x55FFE6C0).withValues(alpha: alpha * 0.5),
    1.4,
  );
  canvas.drawLine(const Offset(-18, 0), const Offset(-44, 2), trail);
  canvas.drawLine(const Offset(-18, 0), const Offset(-40, -2), trail);
  final body = fillPaint(const Color(0xFF37322A).withValues(alpha: alpha));
  // 机身
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(-17, -3.2, 34, 6.4),
      const Radius.circular(3),
    ),
    body,
  );
  // 主翼与尾翼
  final wing = Path()
    ..moveTo(-2, -2)
    ..lineTo(7, -2)
    ..lineTo(1, -13)
    ..lineTo(-6, -13)
    ..close();
  canvas.drawPath(wing, body);
  final wingBack = Path()
    ..moveTo(-2, 2)
    ..lineTo(7, 2)
    ..lineTo(2, 12)
    ..lineTo(-5, 12)
    ..close();
  canvas.drawPath(wingBack, body);
  canvas.drawRect(
    const Rect.fromLTWH(-17, -2, 5, 8),
    fillPaint(const Color(0xFF2A251E).withValues(alpha: alpha)),
  );
  // 座舱与引擎火光
  canvas.drawCircle(
    const Offset(9, -1),
    1.8,
    fillPaint(const Color(0xFF9FC4D8).withValues(alpha: alpha * 0.9)),
  );
  canvas.drawCircle(
    const Offset(-17, 0),
    2.4,
    fillPaint(const Color(0xFFFFC46B).withValues(alpha: alpha * 0.7)),
  );
  canvas.restore();
}

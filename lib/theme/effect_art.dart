import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/battle_config.dart';
import 'art_palette.dart';
import 'paint_kit.dart';

/// 战斗特效与可拾取物：爆炸、枪口火光、补给箱、工事与空袭飞机。

/// 爆炸火球的透明度档数：整场战斗只有这么多支火球画笔。
const int kExplosionAlphaSteps = 20;

/// 火球核心的径向渐变：半径归一化为 1，绘制时按实际半径缩放画布。
///
/// 渐变半径若跟着火球半径走，一场爆炸的三十来帧就会建三十来支 shader；
/// 归一化后同一透明度只对应一支画笔，预热量也固定成二十一支。
Paint _explosionCore(int alphaStep) {
  final alpha = alphaStep / kExplosionAlphaSteps;
  return radialPaint(
    0x10000 + alphaStep,
    1,
    [
      Color.fromRGBO(255, 226, 168, alpha * 0.95),
      Color.fromRGBO(255, 138, 61, alpha * 0.7),
      Color.fromRGBO(194, 69, 47, alpha * 0.25),
      const Color(0x00C2452F),
    ],
    const [0, 0.35, 0.72, 1],
  );
}

/// 开局预热全部爆炸渐变，战斗中不再新建原生 shader。
void prewarmExplosionPaints() {
  for (var step = 0; step <= kExplosionAlphaSteps; step++) {
    _explosionCore(step);
  }
}

/// 爆炸光环与放射碎屑的颜色：按透明度档位缓存，稳态帧不再逐帧新建 Color。
final List<Color> _explosionRing = List.generate(
  kExplosionAlphaSteps + 1,
  (step) => Color.fromRGBO(255, 217, 160, step / kExplosionAlphaSteps * 0.35),
);
final List<Color> _explosionRay = List.generate(
  kExplosionAlphaSteps + 1,
  (step) => Color.fromRGBO(255, 196, 107, step / kExplosionAlphaSteps * 0.7),
);

/// 八条放射碎屑的单位半径路径：整场只建一次，按火球半径缩放画布。
final Path _explosionRays = () {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4;
    final outer = i.isEven ? 1.4 : 1.2;
    path
      ..moveTo(math.cos(angle) * 0.35, math.sin(angle) * 0.35)
      ..lineTo(math.cos(angle) * outer, math.sin(angle) * outer);
  }
  return path;
}();

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
  final step = (alpha * kExplosionAlphaSteps).round();
  final core = _explosionCore(step);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(r);
  canvas.drawCircle(Offset.zero, 1, core);
  canvas.restore();
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.drawCircle(
    Offset.zero,
    r * (0.9 + progress * 0.4),
    strokePaint(_explosionRing[step], 1.6),
  );
  // 八条碎屑合为一条路径并整体旋转，单次爆炸省下七条绘制指令。
  canvas.rotate(progress * 0.6);
  canvas.scale(r);
  canvas.drawPath(
    _explosionRays,
    strokePaint(_explosionRay[step], 1.4 / r)..strokeCap = StrokeCap.round,
  );
  canvas.restore();
}

/// 单位半径的星形火光路径：每发子弹都要画，路径只建一次。
final Path _muzzleStar = () {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4;
    final r = i.isEven ? 1.0 : 0.42;
    final point = Offset(math.cos(angle) * r, math.sin(angle) * r);
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}();

/// 枪口火光：短促的星形。路径按单位半径缓存，缩放画布即可套用任意大小。
void paintMuzzle(Canvas canvas, Offset center, double radius, double alpha) {
  if (radius <= 0 || alpha <= 0) return;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(radius);
  canvas.drawPath(
    _muzzleStar,
    fillPaint(const Color(0xFFFFE1A1).withValues(alpha: alpha)),
  );
  canvas.restore();
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

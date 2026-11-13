import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../game/battle_config.dart';
import '../utils/constants.dart';

/// 战场美术：全部用 Canvas 程序化绘制，仓库不存放图片资源。
///
/// 所有函数都在「战场逻辑坐标」下作画（0..300 × 0..400），由调用方先统一
/// 缩放，因此同一套画法在手机、桌面与 Web 上比例完全一致。

const Color _roadTop = Color(0xFF241D17);
const Color _roadBottom = Color(0xFF0E0B09);
const Color _roof = Color(0xFF2A221B);
const Color _roofEdge = Color(0xFF3A2F25);
const Color _window = Color(0xFFCD8C4A);
const Color _sandbag = Color(0xFF7A6A4C);
const Color _sandbagLight = Color(0xFF9A8862);
const Color _ember = Color(0xFFFFA24A);

/// 背景街道：柏油路、屋顶、车道线与随滚动下移的杂物。
void paintStreet(Canvas canvas, Size size, double time) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        const [Color(0xFF2A211A), _roadTop, _roadBottom],
        const [0, 0.45, 1],
      ),
  );

  // 两侧屋顶：顶视角度下像压在街道边的楼房。
  const roofWidth = 27.0;
  final roofPaint = Paint()..color = _roof;
  final edgePaint = Paint()
    ..color = _roofEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  const block = 92.0;
  final shift = (time * 46) % block;
  for (var i = -1; i < size.height / block + 2; i++) {
    final y = i * block + shift;
    for (final left in [true, false]) {
      final x = left ? 0.0 : size.width - roofWidth;
      final roof = Rect.fromLTWH(x, y, roofWidth, block - 10);
      canvas.drawRect(roof, roofPaint);
      canvas.drawRect(roof.deflate(2.5), edgePaint);
      // 屋顶设备与天窗
      canvas.drawRect(
        Rect.fromLTWH(x + 7, y + 12, 12, 9),
        Paint()..color = const Color(0xFF1B1611),
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 5, y + 40, 16, 3),
        Paint()..color = const Color(0xFF453727),
      );
      // 偶尔亮着的窗
      if (((i + (left ? 0 : 3)) * 37) % 5 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(x + 9, y + 58, 8, 6),
          Paint()..color = _window.withValues(alpha: 0.55),
        );
      }
    }
  }

  // 人行道边线与排水沟
  final walkPaint = Paint()..color = const Color(0xFF33291F);
  canvas.drawRect(
    Rect.fromLTWH(roofWidth, 0, 7, size.height),
    walkPaint,
  );
  canvas.drawRect(
    Rect.fromLTWH(size.width - roofWidth - 7, 0, 7, size.height),
    walkPaint,
  );
  final curb = Paint()..color = const Color(0xFF4A3B2A);
  canvas.drawRect(
    Rect.fromLTWH(roofWidth + 7, 0, 1.6, size.height),
    curb,
  );
  canvas.drawRect(
    Rect.fromLTWH(size.width - roofWidth - 8.6, 0, 1.6, size.height),
    curb,
  );

  // 车道虚线：随画面下移，制造前进感。
  const dash = 26.0;
  const gap = 30.0;
  final dashShift = (time * 132) % (dash + gap);
  final dashPaint = Paint()..color = const Color(0xFF8A7A5E);
  for (var y = -dash - gap + dashShift; y < size.height; y += dash + gap) {
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - 2.4, y, 4.8, dash),
      dashPaint,
    );
  }
  final lanePaint = Paint()..color = const Color(0xFF4D4233);
  for (final x in [roofWidth + 34, size.width - roofWidth - 34]) {
    for (var y = -40 + dashShift * 0.6; y < size.height; y += 70) {
      canvas.drawRect(Rect.fromLTWH(x, y, 1.6, 22), lanePaint);
    }
  }

  // 弹坑与碎石：固定伪随机，滚动时不会闪烁。
  final rubble = Paint()..color = const Color(0xFF3B2E22);
  for (var i = 0; i < 14; i++) {
    final seed = i * 73.7;
    final baseY = (seed * 13) % size.height;
    final y = (baseY + time * 30) % (size.height + 30) - 15;
    final x = 46 + (seed * 7) % (size.width - 92);
    final radius = 1.4 + (seed % 3);
    canvas.drawCircle(Offset(x, y), radius, rubble);
  }
  final scorch = Paint()..color = const Color(0x22000000);
  for (var i = 0; i < 4; i++) {
    final y = ((i * 137.0) + time * 30) % (size.height + 80) - 40;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(70 + i * 55, y),
        width: 34,
        height: 18,
      ),
      scorch,
    );
  }

  // 远处的探照灯：两道缓慢摆动的光柱。
  final beam = Paint()
    ..shader = ui.Gradient.linear(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.3, 210),
      [const Color(0x22FFD9A0), const Color(0x00FFD9A0)],
    );
  final sway = math.sin(time * 0.35) * 26;
  final path = Path()
    ..moveTo(size.width * 0.3 - 5 + sway, -10)
    ..lineTo(size.width * 0.3 + 5 + sway, -10)
    ..lineTo(size.width * 0.3 + 62 + sway, 210)
    ..lineTo(size.width * 0.3 - 62 + sway, 210)
    ..close();
  canvas.drawPath(path, beam);
}

/// 玩家与敌军共用的士兵剪影。
void paintSoldier(
  Canvas canvas,
  Offset center, {
  required double radius,
  required Color uniform,
  required Color helmet,
  Color accent = const Color(0xFFB5432C),
  double aim = -math.pi / 2,
  double walk = 0,
  double flash = 0,
  bool hostile = false,
}) {
  final s = radius / 9;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  // 地面阴影
  canvas.drawOval(
    Rect.fromCenter(center: Offset(0, 5 * s), width: 17 * s, height: 8 * s),
    Paint()..color = const Color(0x66000000),
  );
  // 双腿
  final legSwing = math.sin(walk) * 2.2 * s;
  final legPaint = Paint()..color = uniform.withValues(alpha: 0.9);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-5 * s + legSwing, 2 * s, 4.2 * s, 8 * s),
      Radius.circular(1.8 * s),
    ),
    legPaint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(1.2 * s - legSwing, 2 * s, 4.2 * s, 8 * s),
      Radius.circular(1.8 * s),
    ),
    legPaint,
  );
  // 背包
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-4.6 * s, -3.4 * s, 9.2 * s, 7 * s),
      Radius.circular(2.4 * s),
    ),
    Paint()..color = const Color(0xFF3F3526),
  );
  // 躯干
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-5.4 * s, -4.6 * s, 10.8 * s, 10.4 * s),
      Radius.circular(3.6 * s),
    ),
    Paint()..color = uniform,
  );
  // 肩章
  canvas.drawCircle(
    Offset(-4.4 * s, -1.2 * s),
    1.9 * s,
    Paint()..color = accent,
  );
  // 步枪：朝向 aim 方向
  final gunStart = Offset(math.cos(aim) * 3 * s, math.sin(aim) * 3 * s);
  final gunEnd = Offset(math.cos(aim) * 15 * s, math.sin(aim) * 15 * s);
  canvas.drawLine(
    gunStart,
    gunEnd,
    Paint()
      ..color = const Color(0xFF1A1512)
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    Offset(gunStart.dx + math.cos(aim + 1.2) * 3, gunStart.dy + math.sin(aim + 1.2) * 3),
    Offset(gunStart.dx + math.cos(aim - 1.4) * 2, gunStart.dy + math.sin(aim - 1.4) * 3),
    Paint()
      ..color = const Color(0xFF1A1512)
      ..strokeWidth = 1.6 * s,
  );
  // 钢盔
  canvas.drawCircle(
    Offset(0, -5.2 * s),
    4.6 * s,
    Paint()..color = helmet,
  );
  canvas.drawArc(
    Rect.fromCircle(center: Offset(0, -5.2 * s), radius: 4.8 * s),
    math.pi,
    math.pi,
    false,
    Paint()
      ..color = helmet.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * s,
  );
  // 敌我识别：敌军暗红领巾
  if (hostile) {
    canvas.drawRect(
      Rect.fromLTWH(-1.6 * s, 0.4 * s, 3.2 * s, 1.4 * s),
      Paint()..color = const Color(0xFF8E2F23),
    );
  }
  if (flash > 0) {
    canvas.drawCircle(
      Offset.zero,
      9 * s,
      Paint()..color = Colors.white.withValues(alpha: flash * 0.5),
    );
  }
  canvas.restore();
}

/// 装甲车：横向车身、履带与朝下的炮管。
void paintArmoredCar(
  Canvas canvas,
  Offset center, {
  required double radius,
  double flash = 0,
  double time = 0,
}) {
  final s = radius / 20;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(0, 6 * s), width: 40 * s, height: 14 * s),
    Paint()..color = const Color(0x66000000),
  );
  // 履带
  final track = Paint()..color = const Color(0xFF1F1B16);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-20 * s, -12 * s, 40 * s, 7 * s),
      Radius.circular(3 * s),
    ),
    track,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-20 * s, 5 * s, 40 * s, 7 * s),
      Radius.circular(3 * s),
    ),
    track,
  );
  // 车轮纹路
  for (var i = -3; i <= 3; i++) {
    final x = i * 5.2 * s;
    for (final y in [-8.5, 8.5]) {
      canvas.drawCircle(
        Offset(x, y * s),
        1.5 * s,
        Paint()..color = const Color(0xFF57493A),
      );
    }
  }
  // 车身
  final hull = RRect.fromRectAndRadius(
    Rect.fromLTWH(-16 * s, -11 * s, 32 * s, 22 * s),
    Radius.circular(4 * s),
  );
  canvas.drawRRect(hull, Paint()..color = const Color(0xFF4B4A3A));
  canvas.drawRRect(
    hull,
    Paint()
      ..color = const Color(0xFF6B6A54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * s,
  );
  // 装甲板
  canvas.drawRect(
    Rect.fromLTWH(-16 * s, -2 * s, 7 * s, 4 * s),
    Paint()..color = const Color(0xFF3A392C),
  );
  canvas.drawRect(
    Rect.fromLTWH(9 * s, -2 * s, 7 * s, 4 * s),
    Paint()..color = const Color(0xFF3A392C),
  );
  // 炮塔
  canvas.drawCircle(
    Offset(0, -1 * s),
    6.4 * s,
    Paint()..color = const Color(0xFF5C5B47),
  );
  canvas.drawRect(
    Rect.fromLTWH(-1.2 * s, 3 * s, 2.4 * s, 12 * s),
    Paint()..color = const Color(0xFF2E2D24),
  );
  // 车灯
  final lamp = 0.4 + 0.25 * math.sin(time * 5);
  canvas.drawCircle(
    Offset(-13 * s, 9 * s),
    1.5 * s,
    Paint()..color = const Color(0xFFFFD9A0).withValues(alpha: lamp),
  );
  if (flash > 0) {
    canvas.drawCircle(
      Offset.zero,
      20 * s,
      Paint()..color = Colors.white.withValues(alpha: flash * 0.35),
    );
  }
  canvas.restore();
}

/// 头目：加厚的双炮塔战车，带警示灯。
void paintBoss(
  Canvas canvas,
  Offset center, {
  required double radius,
  double flash = 0,
  double time = 0,
}) {
  final s = radius / 30;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(0, 8 * s), width: 64 * s, height: 22 * s),
    Paint()..color = const Color(0x77000000),
  );
  final track = Paint()..color = const Color(0xFF1B1712);
  for (final y in [-22.0, 12.0]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-32 * s, y * s, 64 * s, 10 * s),
        Radius.circular(4 * s),
      ),
      track,
    );
    for (var i = -5; i <= 5; i++) {
      for (final offset in [y + 2.5, y + 7.5]) {
        canvas.drawCircle(
          Offset(i * 6 * s, offset * s),
          1.6 * s,
          Paint()..color = const Color(0xFF4A3E30),
        );
      }
    }
  }
  final hull = RRect.fromRectAndRadius(
    Rect.fromLTWH(-26 * s, -18 * s, 52 * s, 36 * s),
    Radius.circular(6 * s),
  );
  canvas.drawRRect(hull, Paint()..color = const Color(0xFF4A4636));
  canvas.drawRRect(
    hull,
    Paint()
      ..color = const Color(0xFF7C755A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * s,
  );
  // 铆钉
  for (var i = -3; i <= 3; i++) {
    for (final y in [-14.0, 14.0]) {
      canvas.drawCircle(
        Offset(i * 7 * s, y * s),
        1.3 * s,
        Paint()..color = const Color(0xFF8B8263),
      );
    }
  }
  // 双炮塔
  for (final x in [-11.0, 11.0]) {
    canvas.drawCircle(
      Offset(x * s, -2 * s),
      8 * s,
      Paint()..color = const Color(0xFF5B5744),
    );
    canvas.drawRect(
      Rect.fromLTWH((x - 1.6) * s, 4 * s, 3.2 * s, 18 * s),
      Paint()..color = const Color(0xFF302C23),
    );
  }
  // 警示灯
  final blink = 0.45 + 0.4 * math.sin(time * 6).abs();
  canvas.drawCircle(
    Offset(0, -14 * s),
    2.6 * s,
    Paint()..color = const Color(0xFFFF5A3C).withValues(alpha: blink),
  );
  if (flash > 0) {
    canvas.drawCircle(
      Offset.zero,
      30 * s,
      Paint()..color = Colors.white.withValues(alpha: flash * 0.3),
    );
  }
  canvas.restore();
}

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
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.drawCircle(
    Offset.zero,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        r,
        [
          const Color(0xFFFFE2A8).withValues(alpha: alpha * 0.95),
          const Color(0xFFFF8A3D).withValues(alpha: alpha * 0.7),
          const Color(0xFFC2452F).withValues(alpha: alpha * 0.25),
          const Color(0x00C2452F),
        ],
        const [0, 0.35, 0.72, 1],
      ),
  );
  canvas.drawCircle(
    Offset.zero,
    r * (0.9 + progress * 0.4),
    Paint()
      ..color = const Color(0xFFFFD9A0).withValues(alpha: alpha * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
  );
  final ray = Paint()
    ..color = const Color(0xFFFFC46B).withValues(alpha: alpha * 0.7)
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round;
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
    Paint()..color = const Color(0xFFFFE1A1).withValues(alpha: alpha),
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
  canvas.save();
  canvas.translate(center.dx, y);
  canvas.drawCircle(
    Offset.zero,
    14,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        14,
        [
          const Color(0xFFFFD9A0).withValues(alpha: 0.24 * fade),
          const Color(0x00FFD9A0),
        ],
      ),
  );
  final box = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset.zero, width: 17, height: 17),
    const Radius.circular(3),
  );
  canvas.drawRRect(box, Paint()..color = const Color(0xFF6B5233).withValues(alpha: fade));
  canvas.drawRRect(
    box,
    Paint()
      ..color = const Color(0xFFC79A5B).withValues(alpha: fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
  final icon = Paint()
    ..color = const Color(0xFFFFEBC7).withValues(alpha: fade)
    ..strokeWidth = 2
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

/// 前景沙袋与铁丝网：压在战场底部，增强纵深。
void paintBarricade(Canvas canvas, Size size, double time) {
  final rowY = size.height - 7;
  for (var i = 0; i < 9; i++) {
    final x = 6.0 + i * 34;
    final bag = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, rowY - (i.isEven ? 0 : 2), 30, 13),
      const Radius.circular(6),
    );
    canvas.drawRRect(bag, Paint()..color = _sandbag);
    canvas.drawRRect(
      bag,
      Paint()
        ..color = _sandbagLight.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    canvas.drawLine(
      Offset(x + 4, rowY + 4),
      Offset(x + 24, rowY + 4),
      Paint()
        ..color = const Color(0x44FFF0D0)
        ..strokeWidth = 0.8,
    );
  }
  // 铁丝网
  final wire = Paint()
    ..color = const Color(0x66C8BCA6)
    ..strokeWidth = 0.7;
  for (var i = 0; i < 5; i++) {
    final y = rowY - 22 + i * 4;
    canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), wire);
  }
  for (var i = 0; i < 12; i++) {
    final x = 14.0 + i * 25;
    canvas.drawLine(Offset(x, rowY - 24), Offset(x + 6, rowY - 10), wire);
    canvas.drawLine(Offset(x + 6, rowY - 24), Offset(x, rowY - 10), wire);
  }
  // 地面余烬
  for (var i = 0; i < 6; i++) {
    final x = (i * 61.0 + time * 8) % size.width;
    final y = size.height - 18 - (i * 13 % 10);
    canvas.drawCircle(
      Offset(x, y),
      0.9,
      Paint()..color = _ember.withValues(alpha: 0.5),
    );
  }
}

/// 玩家的准星线：从枪口向上的淡光，帮助判断火力方向。
void paintAimBeam(Canvas canvas, Offset from, double length, double alpha) {
  canvas.drawLine(
    from,
    Offset(from.dx, from.dy - length),
    Paint()
      ..shader = ui.Gradient.linear(
        from,
        Offset(from.dx, from.dy - length),
        [
          const Color(0x88FFD9A0).withValues(alpha: 0.3 * alpha),
          const Color(0x00FFD9A0),
        ],
      )
      ..strokeWidth = 1.2,
  );
}

/// 战场边缘的暗角，把注意力收拢到中间。
void paintVignette(Canvas canvas, Size size) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.radial(
        rect.center,
        size.longestSide * 0.72,
        [const Color(0x00000000), const Color(0x00000000), const Color(0x99000000)],
        const [0, 0.62, 1],
      ),
  );
}

/// 低血量时的红色警示边缘。
void paintDamageWash(Canvas canvas, Size size, double intensity) {
  if (intensity <= 0) return;
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.radial(
        rect.center,
        size.longestSide * 0.62,
        [
          const Color(0x00B3261E),
          const Color(0x00B3261E),
          const Color(0xFFB3261E).withValues(alpha: 0.42 * intensity),
        ],
        const [0, 0.55, 1],
      ),
  );
}

/// 波次提示文字的样式。
TextStyle battlefieldLabelStyle({
  required double fontSize,
  Color color = const Color(0xFFF6E4C6),
  FontWeight weight = FontWeight.w700,
  double letterSpacing = 1.6,
}) => TextStyle(
  fontSize: fontSize,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
  height: 1.1,
  // Web 的 CanvasKit 没有系统中文字体回退，Wave 提示必须显式指定字体。
  fontFamily: kIsWeb ? kWebFontFamily : null,
);

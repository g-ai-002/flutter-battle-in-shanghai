import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'paint_kit.dart';

/// 地面单位的程序化剪影：士兵、装甲车与头目战车。
///
/// 单位以中心为原点、按半径缩放，因此同一套画法适配手机与桌面。

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
    fillPaint(const Color(0x66000000)),
  );
  // 双腿
  final legSwing = math.sin(walk) * 2.2 * s;
  final legPaint = fillPaint(uniform.withValues(alpha: 0.9));
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
    fillPaint(const Color(0xFF3F3526)),
  );
  // 躯干
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-5.4 * s, -4.6 * s, 10.8 * s, 10.4 * s),
      Radius.circular(3.6 * s),
    ),
    fillPaint(uniform),
  );
  // 肩章
  canvas.drawCircle(Offset(-4.4 * s, -1.2 * s), 1.9 * s, fillPaint(accent));
  // 步枪：朝向 aim 方向
  final gunStart = Offset(math.cos(aim) * 3 * s, math.sin(aim) * 3 * s);
  final gunEnd = Offset(math.cos(aim) * 15 * s, math.sin(aim) * 15 * s);
  canvas.drawLine(
    gunStart,
    gunEnd,
    strokePaint(const Color(0xFF1A1512), 2.2 * s)..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    Offset(
      gunStart.dx + math.cos(aim + 1.2) * 3,
      gunStart.dy + math.sin(aim + 1.2) * 3,
    ),
    Offset(
      gunStart.dx + math.cos(aim - 1.4) * 2,
      gunStart.dy + math.sin(aim - 1.4) * 3,
    ),
    strokePaint(const Color(0xFF1A1512), 1.6 * s),
  );
  // 钢盔
  canvas.drawCircle(Offset(0, -5.2 * s), 4.6 * s, fillPaint(helmet));
  canvas.drawArc(
    Rect.fromCircle(center: Offset(0, -5.2 * s), radius: 4.8 * s),
    math.pi,
    math.pi,
    false,
    strokePaint(helmet.withValues(alpha: 0.7), 1.2 * s),
  );
  // 敌我识别：敌军暗红领巾
  if (hostile) {
    canvas.drawRect(
      Rect.fromLTWH(-1.6 * s, 0.4 * s, 3.2 * s, 1.4 * s),
      fillPaint(const Color(0xFF8E2F23)),
    );
  }
  if (flash > 0) {
    canvas.drawCircle(
      Offset.zero,
      9 * s,
      fillPaint(Colors.white.withValues(alpha: flash * 0.5)),
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
    fillPaint(const Color(0x66000000)),
  );
  // 履带
  final track = fillPaint(const Color(0xFF1F1B16));
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
        fillPaint(const Color(0xFF57493A)),
      );
    }
  }
  // 车身
  final hull = RRect.fromRectAndRadius(
    Rect.fromLTWH(-16 * s, -11 * s, 32 * s, 22 * s),
    Radius.circular(4 * s),
  );
  canvas.drawRRect(hull, fillPaint(const Color(0xFF4B4A3A)));
  canvas.drawRRect(hull, strokePaint(const Color(0xFF6B6A54), 1 * s));
  // 装甲板
  canvas.drawRect(
    Rect.fromLTWH(-16 * s, -2 * s, 7 * s, 4 * s),
    fillPaint(const Color(0xFF3A392C)),
  );
  canvas.drawRect(
    Rect.fromLTWH(9 * s, -2 * s, 7 * s, 4 * s),
    fillPaint(const Color(0xFF3A392C)),
  );
  // 炮塔
  canvas.drawCircle(
    Offset(0, -1 * s),
    6.4 * s,
    fillPaint(const Color(0xFF5C5B47)),
  );
  canvas.drawRect(
    Rect.fromLTWH(-1.2 * s, 3 * s, 2.4 * s, 12 * s),
    fillPaint(const Color(0xFF2E2D24)),
  );
  // 车灯
  final lamp = 0.4 + 0.25 * math.sin(time * 5);
  canvas.drawCircle(
    Offset(-13 * s, 9 * s),
    1.5 * s,
    fillPaint(const Color(0xFFFFD9A0).withValues(alpha: lamp)),
  );
  if (flash > 0) {
    canvas.drawCircle(
      Offset.zero,
      20 * s,
      fillPaint(Colors.white.withValues(alpha: flash * 0.35)),
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
    fillPaint(const Color(0x77000000)),
  );
  for (final y in [-22.0, 12.0]) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-32 * s, y * s, 64 * s, 10 * s),
        Radius.circular(4 * s),
      ),
      fillPaint(const Color(0xFF1B1712)),
    );
    for (var i = -5; i <= 5; i++) {
      for (final offset in [y + 2.5, y + 7.5]) {
        canvas.drawCircle(
          Offset(i * 6 * s, offset * s),
          1.6 * s,
          fillPaint(const Color(0xFF4A3E30)),
        );
      }
    }
  }
  final hull = RRect.fromRectAndRadius(
    Rect.fromLTWH(-26 * s, -18 * s, 52 * s, 36 * s),
    Radius.circular(6 * s),
  );
  canvas.drawRRect(hull, fillPaint(const Color(0xFF4A4636)));
  canvas.drawRRect(hull, strokePaint(const Color(0xFF7C755A), 1.4 * s));
  // 铆钉
  for (var i = -3; i <= 3; i++) {
    for (final y in [-14.0, 14.0]) {
      canvas.drawCircle(
        Offset(i * 7 * s, y * s),
        1.3 * s,
        fillPaint(const Color(0xFF8B8263)),
      );
    }
  }
  // 双炮塔
  for (final x in [-11.0, 11.0]) {
    canvas.drawCircle(
      Offset(x * s, -2 * s),
      8 * s,
      fillPaint(const Color(0xFF5B5744)),
    );
    canvas.drawRect(
      Rect.fromLTWH((x - 1.6) * s, 4 * s, 3.2 * s, 18 * s),
      fillPaint(const Color(0xFF302C23)),
    );
  }
  // 警示灯
  final blink = 0.45 + 0.4 * math.sin(time * 6).abs();
  canvas.drawCircle(
    Offset(0, -14 * s),
    2.6 * s,
    fillPaint(const Color(0xFFFF5A3C).withValues(alpha: blink)),
  );
  if (flash > 0) {
    canvas.drawCircle(
      Offset.zero,
      30 * s,
      fillPaint(Colors.white.withValues(alpha: flash * 0.3)),
    );
  }
  canvas.restore();
}

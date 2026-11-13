import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../game/battle_config.dart';
import '../utils/constants.dart';
import 'paint_kit.dart';

/// 战场美术：全部用 Canvas 程序化绘制，仓库不存放图片资源。
///
/// 所有函数都在「战场逻辑坐标」下作画（0..300 × 0..400），由调用方先统一
/// 缩放，因此同一套画法在手机、桌面与 Web 上比例完全一致。

const Color _roadTop = Color(0xFF31261D);
const Color _roadBottom = Color(0xFF191310);
const Color _roof = Color(0xFF352B21);
const Color _roofEdge = Color(0xFF4B3C2D);
const Color _window = Color(0xFFCD8C4A);
const Color _sandbag = Color(0xFF8B7A57);
const Color _sandbagLight = Color(0xFFB09C72);
const Color _ember = Color(0xFFFFA24A);

/// 屋顶循环块的高度：一个块 92，缓存瓦片取两块以保留窗灯的错落。
const double kRoofBlock = 92;
const double kRoofTileHeight = kRoofBlock * 2;
const double _roofWidth = 27;

/// 背景街道：静态底色 + 滚动屋顶 + 车道线与杂物。
void paintStreet(Canvas canvas, Size size, double time) {
  paintStreetBase(canvas, size);
  paintRoofs(canvas, size, time);
  paintStreetMotion(canvas, size, time);
}

/// 静态底层：路面渐变、人行道与路缘。可整张缓存在位图里。
void paintStreetBase(Canvas canvas, Size size) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        const [Color(0xFF3B2E24), _roadTop, _roadBottom],
        const [0, 0.45, 1],
      ),
  );

  // 人行道边线与排水沟
  final walkPaint = fillPaint(const Color(0xFF43362A));
  canvas.drawRect(Rect.fromLTWH(_roofWidth, 0, 7, size.height), walkPaint);
  canvas.drawRect(
    Rect.fromLTWH(size.width - _roofWidth - 7, 0, 7, size.height),
    walkPaint,
  );
  final curb = fillPaint(const Color(0xFF5E4C38));
  canvas.drawRect(Rect.fromLTWH(_roofWidth + 7, 0, 1.6, size.height), curb);
  canvas.drawRect(
    Rect.fromLTWH(size.width - _roofWidth - 8.6, 0, 1.6, size.height),
    curb,
  );
}

/// 一个屋顶循环块：左右两侧各一块，缓存时直接渲染整块瓦片。
void paintRoofTile(Canvas canvas, Size size) {
  final roofPaint = fillPaint(_roof);
  final edgePaint = strokePaint(_roofEdge, 0.8);
  for (var i = 0; i < kRoofTileHeight ~/ kRoofBlock; i++) {
    final y = i * kRoofBlock;
    for (final left in [true, false]) {
      final x = left ? 0.0 : size.width - _roofWidth;
      final roof = Rect.fromLTWH(x, y, _roofWidth, kRoofBlock - 10);
      canvas.drawRect(roof, roofPaint);
      canvas.drawRect(roof.deflate(2.5), edgePaint);
      // 屋顶设备与天窗
      canvas.drawRect(
        Rect.fromLTWH(x + 7, y + 12, 12, 9),
        fillPaint(const Color(0xFF1B1611)),
      );
      canvas.drawRect(
        Rect.fromLTWH(x + 5, y + 40, 16, 3),
        fillPaint(const Color(0xFF453727)),
      );
      // 偶尔亮着的窗
      if (((i + (left ? 0 : 3)) * 37) % 5 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(x + 9, y + 58, 8, 6),
          fillPaint(_window.withValues(alpha: 0.55)),
        );
      }
    }
  }
}

/// 滚动屋顶：以 [kRoofTileHeight] 为一个循环向下平移。
void paintRoofs(Canvas canvas, Size size, double time) {
  final shift = (time * 46) % kRoofTileHeight;
  for (var y = shift - kRoofTileHeight; y < size.height; y += kRoofTileHeight) {
    canvas.save();
    canvas.translate(0, y);
    paintRoofTile(canvas, size);
    canvas.restore();
  }
}

/// 随前进感滚动的车道线、碎石与探照灯。
void paintStreetMotion(Canvas canvas, Size size, double time) {
  paintStreetScroll(canvas, size, time);
  paintSearchlight(canvas, size, time);
}

/// 车道线、碎石与弹坑的滚动部分；探照灯单独成层，便于缓存成位图。
void paintStreetScroll(Canvas canvas, Size size, double time) {
  // 车道虚线：随画面下移，制造前进感。
  const dash = 26.0;
  const gap = 30.0;
  final dashShift = (time * 132) % (dash + gap);
  final dashPaint = fillPaint(const Color(0xFF9C8A6A));
  for (var y = -dash - gap + dashShift; y < size.height; y += dash + gap) {
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - 2.4, y, 4.8, dash),
      dashPaint,
    );
  }
  final lanePaint = fillPaint(const Color(0xFF5E5140));
  for (final x in [_roofWidth + 34, size.width - _roofWidth - 34]) {
    for (var y = -40 + dashShift * 0.6; y < size.height; y += 70) {
      canvas.drawRect(Rect.fromLTWH(x, y, 1.6, 22), lanePaint);
    }
  }

  // 弹坑与碎石：固定伪随机，滚动时不会闪烁。
  final rubble = fillPaint(const Color(0xFF4A3A2B));
  for (var i = 0; i < 14; i++) {
    final seed = i * 73.7;
    final baseY = (seed * 13) % size.height;
    final y = (baseY + time * 30) % (size.height + 30) - 15;
    final x = 46 + (seed * 7) % (size.width - 92);
    final radius = 1.4 + (seed % 3);
    canvas.drawCircle(Offset(x, y), radius, rubble);
  }
  final scorch = fillPaint(const Color(0x22000000));
  for (var i = 0; i < 4; i++) {
    final y = ((i * 137.0) + time * 30) % (size.height + 80) - 40;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(70 + i * 55, y), width: 34, height: 18),
      scorch,
    );
  }
}

/// 探照灯外接范围：缓存位图时按这个矩形取图，摆动只做平移。
const double kSearchlightWidth = 140;
const double kSearchlightHeight = 220;
const double kSearchlightTop = -10;

/// 远处的探照灯：一道缓慢摆动的光柱，平移量随时间变化。
void paintSearchlight(Canvas canvas, Size size, double time) {
  final sway = math.sin(time * 0.35) * 26;
  canvas.save();
  canvas.translate(sway, 0);
  paintSearchlightBeam(canvas, size);
  canvas.restore();
}

/// 零摆位的光柱本体，供直接绘制与静态图层缓存共用。
void paintSearchlightBeam(Canvas canvas, Size size) {
  final x = size.width * 0.3;
  final beam = linearPaint(
    0x51000 + size.width.round(),
    Offset(x, 0),
    Offset(x, 210),
    const [Color(0x22FFD9A0), Color(0x00FFD9A0)],
    const [0, 1],
  );
  final path = Path()
    ..moveTo(x - 5, kSearchlightTop)
    ..lineTo(x + 5, kSearchlightTop)
    ..lineTo(x + 62, 210)
    ..lineTo(x - 62, 210)
    ..close();
  canvas.drawPath(path, beam);
}

/// 玩家周围的暖色环境光：缓存成图后按位置贴图，避免每帧新建渐变。
void paintPlayerGlow(Canvas canvas, double radius) {
  canvas.drawCircle(
    Offset.zero,
    radius,
    Paint()
      ..shader = ui.Gradient.radial(Offset.zero, radius, [
        const Color(0x1FFFD9A0),
        const Color(0x00FFD9A0),
      ]),
  );
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
  final bagColor = Color.lerp(_sandbag, const Color(0xFF6B5A44), wear * 0.6)!;
  final light = Color.lerp(_sandbagLight, const Color(0xFF8A7A60), wear * 0.5)!;
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

/// 前景街垒的外接高度：缓存时只取战场底部这一条。
const double kBarricadeStripHeight = 36;

/// 前景沙袋与铁丝网：压在战场底部，增强纵深。
void paintBarricade(Canvas canvas, Size size, double time) {
  paintBarricadeBase(canvas, size);
  paintBarricadeEmbers(canvas, size, time);
}

/// 不随时间变化的沙袋与铁丝网，可整条缓存成位图。
void paintBarricadeBase(Canvas canvas, Size size) {
  final rowY = size.height - 7;
  for (var i = 0; i < 9; i++) {
    final x = 6.0 + i * 34;
    final bag = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, rowY - (i.isEven ? 0 : 2), 30, 13),
      const Radius.circular(6),
    );
    canvas.drawRRect(bag, fillPaint(_sandbag));
    canvas.drawRRect(
      bag,
      strokePaint(_sandbagLight.withValues(alpha: 0.75), 0.9),
    );
    canvas.drawLine(
      Offset(x + 4, rowY + 4),
      Offset(x + 24, rowY + 4),
      strokePaint(const Color(0x44FFF0D0), 0.8),
    );
  }
  // 铁丝网
  final wire = strokePaint(const Color(0x66C8BCA6), 0.7);
  for (var i = 0; i < 5; i++) {
    final y = rowY - 22 + i * 4;
    canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), wire);
  }
  for (var i = 0; i < 12; i++) {
    final x = 14.0 + i * 25;
    canvas.drawLine(Offset(x, rowY - 24), Offset(x + 6, rowY - 10), wire);
    canvas.drawLine(Offset(x + 6, rowY - 24), Offset(x, rowY - 10), wire);
  }
}

/// 地面余烬：只随时间横向漂移，单独绘制以保留动态感。
void paintBarricadeEmbers(Canvas canvas, Size size, double time) {
  final ember = fillPaint(_ember.withValues(alpha: 0.5));
  for (var i = 0; i < 6; i++) {
    final x = (i * 61.0 + time * 8) % size.width;
    final y = size.height - 18 - (i * 13 % 10);
    canvas.drawCircle(Offset(x, y), 0.9, ember);
  }
}

/// 玩家的准星线：从枪口向上的淡光，帮助判断火力方向。
///
/// 渐变以枪口为原点缓存，玩家移动只平移画布，不必逐帧新建 shader。
void paintAimBeam(Canvas canvas, Offset from, double length, double alpha) {
  final lengthStep = (length * 2).round();
  final alphaStep = (alpha * 10).round();
  final beam = linearPaint(
    0x60000 + lengthStep * 16 + alphaStep,
    Offset.zero,
    Offset(0, -lengthStep / 2),
    [
      const Color(0x88FFD9A0).withValues(alpha: 0.3 * alphaStep / 10),
      const Color(0x00FFD9A0),
    ],
    const [0, 1],
  )..strokeWidth = 1.2;
  canvas.save();
  canvas.translate(from.dx, from.dy);
  canvas.drawLine(Offset.zero, Offset(0, -lengthStep / 2), beam);
  canvas.restore();
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
        [
          const Color(0x00000000),
          const Color(0x00000000),
          const Color(0x88000000),
        ],
        const [0, 0.7, 1],
      ),
  );
}

/// 低血量时的红色警示边缘。
void paintDamageWash(Canvas canvas, Size size, double intensity) {
  if (intensity <= 0) return;
  final step = (intensity * 10).round().clamp(1, 10);
  final radius = size.longestSide * 0.62;
  final wash = radialPaint(
    0x70000 + size.width.round() * 32 + step,
    radius,
    [
      const Color(0x00B3261E),
      const Color(0x00B3261E),
      Color.fromRGBO(179, 38, 30, 0.42 * step / 10),
    ],
    const [0, 0.55, 1],
  );
  canvas.save();
  canvas.translate(size.width / 2, size.height / 2);
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    ),
    wash,
  );
  canvas.restore();
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

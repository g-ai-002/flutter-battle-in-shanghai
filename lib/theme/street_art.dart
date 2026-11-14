import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'art_palette.dart';
import 'paint_kit.dart';
import 'scene_palette.dart';

/// 街景美术：路面、屋顶、探照灯、环境光、街垒与暗角。
///
/// 全部在「战场逻辑坐标」下作画（0..300 × 0..400），调用方先统一缩放。

/// 屋顶循环块的高度：一个块 92，缓存瓦片取两块以保留窗灯的错落。
const double kRoofBlock = 92;
const double kRoofTileHeight = kRoofBlock * 2;
const double _roofWidth = 27;

/// 背景街道：静态底色 + 滚动屋顶 + 车道线与杂物。
void paintStreet(
  Canvas canvas,
  Size size,
  double time, [
  ScenePalette palette = ScenePalette.zhabei,
]) {
  paintStreetBase(canvas, size, palette);
  paintRoofs(canvas, size, time, palette);
  paintStreetScroll(canvas, size, time, palette);
  paintSearchlight(canvas, size, time, palette);
}

/// 静态底层：路面渐变、人行道与路缘。可整张缓存在位图里。
void paintStreetBase(
  Canvas canvas,
  Size size, [
  ScenePalette palette = ScenePalette.zhabei,
]) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        [
          Color.lerp(palette.roadTop, palette.curb, 0.18)!,
          palette.roadTop,
          palette.roadBottom,
        ],
        const [0, 0.45, 1],
      ),
  );

  // 人行道边线与排水沟
  final walkPaint = fillPaint(palette.walk);
  canvas.drawRect(Rect.fromLTWH(_roofWidth, 0, 7, size.height), walkPaint);
  canvas.drawRect(
    Rect.fromLTWH(size.width - _roofWidth - 7, 0, 7, size.height),
    walkPaint,
  );
  final curb = fillPaint(palette.curb);
  canvas.drawRect(Rect.fromLTWH(_roofWidth + 7, 0, 1.6, size.height), curb);
  canvas.drawRect(
    Rect.fromLTWH(size.width - _roofWidth - 8.6, 0, 1.6, size.height),
    curb,
  );
}

/// 一个屋顶循环块：左右两侧各一块，缓存时直接渲染整块瓦片。
void paintRoofTile(
  Canvas canvas,
  Size size, [
  ScenePalette palette = ScenePalette.zhabei,
]) {
  final roofPaint = fillPaint(palette.roof);
  final edgePaint = strokePaint(palette.roofEdge, 0.8);
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
        fillPaint(palette.roofEdge),
      );
      // 偶尔亮着的窗
      if (((i + (left ? 0 : 3)) * 37) % 5 == 0) {
        canvas.drawRect(
          Rect.fromLTWH(x + 9, y + 58, 8, 6),
          fillPaint(palette.window.withValues(alpha: 0.55)),
        );
      }
    }
  }
}

/// 滚动屋顶：以 [kRoofTileHeight] 为一个循环向下平移。
void paintRoofs(
  Canvas canvas,
  Size size,
  double time, [
  ScenePalette palette = ScenePalette.zhabei,
]) {
  final shift = (time * 46) % kRoofTileHeight;
  for (var y = shift - kRoofTileHeight; y < size.height; y += kRoofTileHeight) {
    canvas.save();
    canvas.translate(0, y);
    paintRoofTile(canvas, size, palette);
    canvas.restore();
  }
}

/// 车道线、碎石与弹坑的滚动部分；探照灯单独成层，便于缓存成位图。
///
/// 每类滚动元素的横向位置固定、只随时间纵向平移，因此把几何建一次路径、
/// 逐帧按周期平移贴图即可：一帧从三十来条绘制指令降到六次 drawPath。
void paintStreetScroll(
  Canvas canvas,
  Size size,
  double time, [
  ScenePalette palette = ScenePalette.zhabei,
]) {
  if (_scrollField != size || _dashPath == null) _buildScrollPaths(size);
  // 车道虚线：随画面下移，制造前进感。
  final dashShift = (time * 132) % (_dash + _dashGap);
  canvas.save();
  canvas.translate(0, dashShift);
  canvas.drawPath(_dashPath!, fillPaint(palette.lane));
  canvas.restore();

  canvas.save();
  canvas.translate(0, dashShift * 0.6);
  canvas.drawPath(_lanePath!, fillPaint(palette.lane.withValues(alpha: 0.55)));
  canvas.restore();

  // 弹坑与碎石：固定伪随机，滚动时不会闪烁。
  final risePeriod = size.height + 30;
  final rise = (time * 30) % risePeriod;
  final rubble = fillPaint(palette.rubble);
  canvas.save();
  canvas.translate(0, rise - risePeriod);
  canvas.drawPath(_rubblePath!, rubble);
  canvas.translate(0, risePeriod);
  canvas.drawPath(_rubblePath!, rubble);
  canvas.restore();

  final scorchPeriod = size.height + 80;
  final scorchShift = (time * 30) % scorchPeriod;
  final scorch = fillPaint(const Color(0x22000000));
  canvas.save();
  canvas.translate(0, scorchShift - scorchPeriod);
  canvas.drawPath(_scorchPath!, scorch);
  canvas.translate(0, scorchPeriod);
  canvas.drawPath(_scorchPath!, scorch);
  canvas.restore();
}

const double _dash = 26;
const double _dashGap = 30;

Size _scrollField = Size.zero;
Path? _dashPath;
Path? _lanePath;
Path? _rubblePath;
Path? _scorchPath;

/// 生成滚动元素的周期几何；战场尺寸变化时重建一次。
void _buildScrollPaths(Size size) {
  _scrollField = size;
  const period = _dash + _dashGap;
  final dashes = Path();
  for (var y = -period; y < size.height + period; y += period) {
    dashes.addRect(Rect.fromLTWH(size.width / 2 - 2.4, y, 4.8, _dash));
  }
  _dashPath = dashes;

  final lanes = Path();
  for (final x in [_roofWidth + 34, size.width - _roofWidth - 34]) {
    for (var y = -40.0; y < size.height + 70; y += 70) {
      lanes.addRect(Rect.fromLTWH(x, y, 1.6, 22));
    }
  }
  _lanePath = lanes;

  final rubble = Path();
  for (var i = 0; i < 14; i++) {
    final seed = i * 73.7;
    final baseY = (seed * 13) % size.height;
    final x = 46 + (seed * 7) % (size.width - 92);
    rubble.addOval(
      Rect.fromCircle(
        center: Offset(x, baseY - 15),
        radius: 1.4 + (seed % 3),
      ),
    );
  }
  _rubblePath = rubble;

  final scorch = Path();
  for (var i = 0; i < 4; i++) {
    scorch.addOval(
      Rect.fromCenter(
        center: Offset(70 + i * 55, i * 137.0 - 40),
        width: 34,
        height: 18,
      ),
    );
  }
  _scorchPath = scorch;
}

/// 探照灯外接范围：缓存位图时按这个矩形取图，摆动只做平移。
const double kSearchlightWidth = 140;
const double kSearchlightHeight = 220;
const double kSearchlightTop = -10;

/// 远处的探照灯：一道缓慢摆动的光柱，平移量随时间变化。
void paintSearchlight(
  Canvas canvas,
  Size size,
  double time, [
  ScenePalette palette = ScenePalette.zhabei,
]) {
  final sway = math.sin(time * 0.35) * 26;
  canvas.save();
  canvas.translate(sway, 0);
  paintSearchlightBeam(canvas, size, palette);
  canvas.restore();
}

/// 零摆位的光柱本体，供直接绘制与静态图层缓存共用。
void paintSearchlightBeam(
  Canvas canvas,
  Size size, [
  ScenePalette palette = ScenePalette.zhabei,
]) {
  final x = size.width * 0.3;
  final beam = linearPaint(
    0x51000 + size.width.round() * 8 + palette.id,
    Offset(x, 0),
    Offset(x, 210),
    [palette.beam.withValues(alpha: 0.13), palette.beam.withValues(alpha: 0)],
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
void paintPlayerGlow(
  Canvas canvas,
  double radius, [
  ScenePalette palette = ScenePalette.zhabei,
]) {
  canvas.drawCircle(
    Offset.zero,
    radius,
    Paint()
      ..shader = ui.Gradient.radial(Offset.zero, radius, [
        palette.beam.withValues(alpha: 0.12),
        palette.beam.withValues(alpha: 0),
      ]),
  );
}

/// 前景街垒的外接高度：缓存时只取战场底部这一条。
const double kBarricadeStripHeight = 36;

/// 前景沙袋与铁丝网：压在战场底部，增强纵深。
void paintBarricade(
  Canvas canvas,
  Size size,
  double time, [
  ScenePalette palette = ScenePalette.zhabei,
]) {
  paintBarricadeBase(canvas, size, palette);
  paintBarricadeEmbers(canvas, size, time, palette);
}

/// 不随时间变化的沙袋与铁丝网，可整条缓存成位图。
void paintBarricadeBase(
  Canvas canvas,
  Size size, [
  ScenePalette palette = ScenePalette.zhabei,
]) {
  final rowY = size.height - 7;
  for (var i = 0; i < 9; i++) {
    final x = 6.0 + i * 34;
    final bag = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, rowY - (i.isEven ? 0 : 2), 30, 13),
      const Radius.circular(6),
    );
    canvas.drawRRect(bag, fillPaint(kSandbag));
    canvas.drawRRect(
      bag,
      strokePaint(kSandbagLight.withValues(alpha: 0.75), 0.9),
    );
    canvas.drawLine(
      Offset(x + 4, rowY + 4),
      Offset(x + 24, rowY + 4),
      strokePaint(palette.beam.withValues(alpha: 0.27), 0.8),
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
void paintBarricadeEmbers(
  Canvas canvas,
  Size size,
  double time, [
  ScenePalette palette = ScenePalette.zhabei,
]) {
  final ember = fillPaint(palette.ember.withValues(alpha: 0.5));
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

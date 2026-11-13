import 'package:flutter/rendering.dart';

/// 绘制辅助：整帧共用两个 Paint，避免每帧反复创建画笔制造垃圾。
///
/// 战场与静态图层缓存都用这套画笔，同一时刻只有一个绘制流程在跑，
/// 因此共享实例是安全的。
final Paint _fill = Paint();
final Paint _stroke = Paint()..style = PaintingStyle.stroke;

Paint fillPaint(Color color) => _fill
  ..color = color
  ..style = PaintingStyle.fill
  ..strokeWidth = 0
  ..strokeCap = StrokeCap.butt
  ..shader = null;

Paint strokePaint(
  Color color,
  double width, {
  StrokeCap cap = StrokeCap.butt,
}) => _stroke
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = cap
  ..shader = null;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show visibleForTesting;
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

/// 渐变画笔缓存上限：关键是让稳态帧不再创建原生 shader，
/// 条目本身只是一个 Paint 与一段渐变，超限时整体清空即可。
const int _maxCachedGradients = 256;

final Map<int, Paint> _radialPaints = {};
final Map<int, Paint> _linearPaints = {};

int _gradientBuilds = 0;

/// 测试用：本进程创建过的原生渐变数量。
@visibleForTesting
int get gradientBuildCount => _gradientBuilds;

/// 测试用：清空缓存与计数器。
@visibleForTesting
void resetGradientCache() {
  _radialPaints.clear();
  _linearPaints.clear();
  _gradientBuilds = 0;
}

/// 复用径向渐变画笔：调用方把半径与透明度量化后写进 [key]。
///
/// 爆炸、护盾与补给光晕每帧都在变透明度，但档位有限；量化后同一支画笔
/// 会被反复使用，逐帧新建 shader 的开销随之消失。
Paint radialPaint(
  int key,
  double radius,
  List<Color> colors,
  List<double> stops,
) {
  final cached = _radialPaints[key];
  if (cached != null) return cached;
  if (_radialPaints.length >= _maxCachedGradients) _radialPaints.clear();
  _gradientBuilds++;
  return _radialPaints[key] = Paint()
    ..shader = ui.Gradient.radial(Offset.zero, radius, colors, stops);
}

/// 复用线性渐变画笔，规则与 [radialPaint] 相同。
Paint linearPaint(
  int key,
  Offset from,
  Offset to,
  List<Color> colors,
  List<double> stops,
) {
  final cached = _linearPaints[key];
  if (cached != null) return cached;
  if (_linearPaints.length >= _maxCachedGradients) _linearPaints.clear();
  _gradientBuilds++;
  return _linearPaints[key] = Paint()
    ..shader = ui.Gradient.linear(from, to, colors, stops);
}

import 'dart:ui';

/// 同色几何的合批绘制：把颜色与线宽相同的线段、圆点收进同一条 [Path]。
///
/// 满屏弹道、碎屑粒子与余烬如果逐条 `drawLine` / `drawCircle`，一帧就是
/// 上百次绘制指令，还要反复改写共享画笔。合批后每组只留一次 `drawPath`，
/// 画笔按组缓存，稳态帧不再新建几何之外的对象。
class PathBatch {
  PathBatch({this.maxGroups = 64});

  /// 组数上限：颜色或线宽变化超出预算时整体清空重建，避免无界增长。
  final int maxGroups;

  final Map<int, Path> _paths = <int, Path>{};
  final Map<int, Paint> _paints = <int, Paint>{};
  final List<int> _order = <int>[];
  final Set<int> _seen = <int>{};

  /// 本帧参与合批的组数，测试用来确认绘制调用被压到个位数。
  int get groupCount => _order.length;

  /// 开始新的一帧：清空上一帧的几何，保留 Path 与画笔对象复用。
  void begin() {
    for (final key in _order) {
      _paths[key]!.reset();
    }
    _order.clear();
    _seen.clear();
  }

  /// 实心圆点，颜色与半透明档位相同的圆点会落在同一条路径里。
  void dot(Color color, Offset center, double radius) {
    if (radius <= 0) return;
    _path(color.toARGB32(), color: color, stroke: false)
        .addOval(Rect.fromCircle(center: center, radius: radius));
  }

  /// 圆头线段：弹道尾焰与曳光都是这种画法。
  void line(
    Color color,
    double width,
    Offset from,
    Offset to, {
    StrokeCap cap = StrokeCap.round,
  }) {
    if (width <= 0) return;
    final widthKey = (width * 10).round().clamp(0, 4095);
    final key =
        0x100000000 +
        color.toARGB32() * 4096 +
        widthKey * 2 +
        (cap == StrokeCap.round ? 1 : 0);
    _path(
      key,
      color: color,
      stroke: true,
      width: widthKey / 10,
      cap: cap,
    )
      ..moveTo(from.dx, from.dy)
      ..lineTo(to.dx, to.dy);
  }

  /// 把本帧的每一组几何画出去；调用方负责在合适的图层顺序上调 [begin]。
  void flush(Canvas canvas) {
    for (final key in _order) {
      canvas.drawPath(_paths[key]!, _paints[key]!);
    }
  }

  Path _path(
    int key, {
    required Color color,
    required bool stroke,
    double width = 0,
    StrokeCap cap = StrokeCap.butt,
  }) {
    final existing = _paths[key];
    if (existing != null) return existing;
    if (_paths.length >= maxGroups) _reset();
    final path = Path();
    _paths[key] = path;
    _paints[key] = Paint()
      ..color = color
      ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = stroke ? width : 0
      ..strokeCap = cap;
    if (_seen.add(key)) _order.add(key);
    return path;
  }

  void _reset() {
    _paths.clear();
    _paints.clear();
    _order.clear();
    _seen.clear();
  }
}

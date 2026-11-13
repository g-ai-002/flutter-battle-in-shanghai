import 'entities.dart';

/// 圆形范围是否相触：[contactRadius] 是双方半径之和。
bool circleOverlap(
  double ax,
  double ay,
  double bx,
  double by,
  double contactRadius,
) {
  final dx = ax - bx;
  final dy = ay - by;
  return dx * dx + dy * dy <= contactRadius * contactRadius;
}

/// 线段与圆是否相交：用上一逻辑步到当前步的轨迹判定命中。
///
/// 30Hz 下单步位移可能超过子弹与敌军的半径和，只比较端点会穿模。
bool segmentHitsCircle(
  double x1,
  double y1,
  double x2,
  double y2,
  double cx,
  double cy,
  double radius,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final lengthSquared = dx * dx + dy * dy;
  var t = 0.0;
  if (lengthSquared > 0) {
    t = (((cx - x1) * dx + (cy - y1) * dy) / lengthSquared).clamp(0.0, 1.0);
  }
  final px = x1 + dx * t;
  final py = y1 + dy * t;
  return circleOverlap(px, py, cx, cy, radius);
}

/// 线段与矩形是否相交（Liang-Barsky 裁剪）。
///
/// 工事是薄薄一面沙袋墙，子弹一步就可能跨过去，同样要用线段判定。
bool segmentHitsBox(
  double x1,
  double y1,
  double x2,
  double y2,
  double left,
  double top,
  double right,
  double bottom,
) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  var enter = 0.0;
  var exit = 1.0;
  bool clip(double p, double q) {
    if (p == 0) return q >= 0;
    final t = q / p;
    if (p < 0) {
      if (t > exit) return false;
      if (t > enter) enter = t;
    } else {
      if (t < enter) return false;
      if (t < exit) exit = t;
    }
    return true;
  }

  // 端点已在盒内时直接命中。
  if (x1 >= left && x1 <= right && y1 >= top && y1 <= bottom) return true;
  return clip(-dx, x1 - left) &&
      clip(dx, right - x1) &&
      clip(-dy, y1 - top) &&
      clip(dy, bottom - y1) &&
      enter <= exit;
}

/// 距离 [x], [y] 最近的存活敌军，没有则返回 null。
EnemyUnit? nearestEnemy(
  Iterable<EnemyUnit> enemies,
  double x,
  double y,
) {
  EnemyUnit? nearest;
  var best = double.infinity;
  for (final enemy in enemies) {
    if (enemy.dead) continue;
    final dx = enemy.x - x;
    final dy = enemy.y - y;
    final distance = dx * dx + dy * dy;
    if (distance >= best) continue;
    best = distance;
    nearest = enemy;
  }
  return nearest;
}

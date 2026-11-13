import '../utils/constants.dart';
import 'battle_config.dart';
import 'combat_math.dart';
import 'entities.dart';

/// 空袭落点规划：找到敌军最密集处，横向铺开三枚航弹。
///
/// 落点先有预警圈，炸弹从屏幕上方垂直落下；不伤玩家，也不影响己方子弹。
List<GrenadeHazard> planAirstrike(List<EnemyUnit> enemies) {
  final target = densestCluster(enemies);
  final baseX = (target?.x ?? Field.width / 2)
      .clamp(kAirstrikeSpacing + 30, Field.width - kAirstrikeSpacing - 30)
      .toDouble();
  final baseY = (target?.y ?? 150).clamp(90.0, Field.height - 90).toDouble();
  const halfSpan = (kAirstrikeBombs - 1) / 2;
  return [
    for (var i = 0; i < kAirstrikeBombs; i++)
      GrenadeHazard(
        kind: HazardKind.bomb,
        fromX: baseX + (i - halfSpan) * kAirstrikeSpacing,
        fromY: -40,
        toX: baseX + (i - halfSpan) * kAirstrikeSpacing,
        toY: baseY,
        duration: kAirstrikeFuse + i * 0.18,
        damage: kAirstrikeDamage,
        radius: kAirstrikeRadius,
        fromPlayer: true,
      ),
  ];
}

/// 敌军最密集的位置：以每个敌军为圆心数一数周围有多少同伴。
EnemyUnit? densestCluster(List<EnemyUnit> enemies) {
  EnemyUnit? best;
  var bestCount = 0;
  for (final enemy in enemies) {
    if (enemy.dead) continue;
    var count = 0;
    for (final other in enemies) {
      if (other.dead) continue;
      if (circleOverlap(enemy.x, enemy.y, other.x, other.y, kAirstrikeRadius)) {
        count++;
      }
    }
    if (count <= bestCount) continue;
    bestCount = count;
    best = enemy;
  }
  return best;
}

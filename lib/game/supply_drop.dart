import 'dart:math' as math;

import '../utils/constants.dart';
import 'battle_config.dart';
import 'entities.dart';

/// 击败敌军后的补给掉落规则。
///
/// 头目必掉急救包与弹药箱，精英必掉一件，普通敌兵按概率掉落；
/// 玩家残血时急救包的权重会提高。
List<PickupItem> rollDrops(
  EnemyUnit enemy, {
  required double playerHpRatio,
  required math.Random random,
}) {
  if (enemy.isBoss) {
    return [
      PickupItem(kind: PickupKind.medkit, x: 120, y: 200),
      PickupItem(kind: PickupKind.ammo, x: 180, y: 200),
    ];
  }
  final chance = enemy.isElite ? 1.0 : 0.15;
  if (random.nextDouble() > chance) return const [];
  return [
    PickupItem(
      kind: rollPickupKind(playerHpRatio, random),
      x: enemy.x.clamp(20.0, Field.width - 20).toDouble(),
      y: enemy.y.clamp(60.0, Field.height - 40).toDouble(),
    ),
  ];
}

/// 按当前血量挑选补给类型：血量低于 55% 时更偏向急救包。
PickupKind rollPickupKind(double playerHpRatio, math.Random random) {
  final roll = random.nextDouble();
  if (playerHpRatio < 0.55) {
    if (roll < 0.55) return PickupKind.medkit;
    if (roll < 0.80) return PickupKind.ammo;
    return PickupKind.shield;
  }
  if (roll < 0.40) return PickupKind.ammo;
  if (roll < 0.75) return PickupKind.shield;
  return PickupKind.medkit;
}

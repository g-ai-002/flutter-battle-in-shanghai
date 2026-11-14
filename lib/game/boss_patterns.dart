import 'dart:ui';

import 'battle_config.dart';
import 'battle_scenes.dart';

/// 头目弹幕表：每处阵地四招循环（扇形、齐射、增援、重火力）。
/// 重火力要么是闸北的重炮直射，要么是其余阵地的炮击预警，二选一。
typedef BossFan = ({int count, double spread, double speed, double damage});
typedef BossSummon = ({EnemyKind kind, int count, double holdY});
typedef BossDirect = ({double speed, double damage, double radius});
typedef BossBombard = ({double damage, double radius, double fuse});

typedef BossKit = ({
  BossFan fan,
  BossFan aimed,
  BossSummon summon,
  BossDirect? direct,
  BossBombard? bombard,
});

/// 头目的巡逻与开火节奏，四处阵地一致。
const double kBossInterval = 2.1;
const double kBossPatrolCenter = 150;
const double kBossPatrolSpan = 74;
const double kBossPatrolSpeed = 0.55;

/// 一处阵地一份完整弹幕：四招的参数都放在同一条记录里，模拟层只查一次表。
const Map<BattleScene, BossKit> bossKits = {
  BattleScene.zhabei: (
    fan: (count: 9, spread: 1.1, speed: 128, damage: 10),
    aimed: (count: 3, spread: 0.075, speed: 176, damage: 12),
    summon: (kind: EnemyKind.infantry, count: 2, holdY: 0),
    direct: (speed: 138, damage: 22, radius: 6), bombard: null,
  ),
  BattleScene.bund: (
    fan: (count: 7, spread: 1.0, speed: 136, damage: 8),
    aimed: (count: 3, spread: 0.1, speed: 196, damage: 9),
    summon: (kind: EnemyKind.rifleman, count: 1, holdY: 118),
    direct: null, bombard: (damage: 16, radius: 40, fuse: 1.3),
  ),
  BattleScene.warehouse: (
    fan: (count: 9, spread: 1.4, speed: 118, damage: 8),
    aimed: (count: 3, spread: 0.09, speed: 210, damage: 12),
    summon: (kind: EnemyKind.raider, count: 2, holdY: 0),
    direct: null, bombard: (damage: 24, radius: 46, fuse: 1.3),
  ),
  BattleScene.suzhou: (
    fan: (count: 8, spread: 1.25, speed: 124, damage: 9),
    aimed: (count: 4, spread: 0.085, speed: 198, damage: 10),
    summon: (kind: EnemyKind.rifleman, count: 2, holdY: 116),
    direct: null, bombard: (damage: 22, radius: 44, fuse: 1.25),
  ),
};

const Color kBossShotColor = Color(0xFFFF9A56);
const Color kBossHeavyColor = Color(0xFFFF5A3C);
const double kBossShotRadius = 3.6;

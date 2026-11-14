import 'dart:ui';

import 'battle_config.dart';
import 'battle_scenes.dart';

/// 头目弹幕表：每处阵地四招循环（扇形、齐射、增援、重火力）。
/// 重火力要么是闸北的重炮直射，要么是外滩与仓库的炮击预警。

typedef BossFan = ({int count, double spread, double speed, double damage});
typedef BossSummon = ({EnemyKind kind, int count, double holdY});
typedef BossDirect = ({double speed, double damage, double radius});
typedef BossBombard = ({double damage, double radius, double fuse});

/// 头目的巡逻与开火节奏，三处阵地一致。
const double kBossInterval = 2.1;
const double kBossPatrolCenter = 150;
const double kBossPatrolSpan = 74;
const double kBossPatrolSpeed = 0.55;

const Map<BattleScene, BossFan> bossFans = {
  BattleScene.zhabei: (count: 9, spread: 1.1, speed: 128, damage: 10),
  BattleScene.bund: (count: 7, spread: 1.0, speed: 136, damage: 8),
  BattleScene.warehouse: (count: 9, spread: 1.4, speed: 118, damage: 8),
};

const Map<BattleScene, BossFan> bossAimed = {
  BattleScene.zhabei: (count: 3, spread: 0.075, speed: 176, damage: 12),
  BattleScene.bund: (count: 3, spread: 0.1, speed: 196, damage: 9),
  BattleScene.warehouse: (count: 3, spread: 0.09, speed: 210, damage: 12),
};

const Map<BattleScene, BossSummon> bossSummons = {
  BattleScene.zhabei: (kind: EnemyKind.infantry, count: 2, holdY: 0),
  BattleScene.bund: (kind: EnemyKind.rifleman, count: 1, holdY: 118),
  BattleScene.warehouse: (kind: EnemyKind.raider, count: 2, holdY: 0),
};

/// 闸北用重炮直射，外滩与仓库改为带预警圈的炮击。
const Map<BattleScene, BossDirect> bossDirects = {
  BattleScene.zhabei: (speed: 138, damage: 22, radius: 6),
};

const Map<BattleScene, BossBombard> bossBombards = {
  BattleScene.bund: (damage: 16, radius: 40, fuse: 1.3),
  BattleScene.warehouse: (damage: 24, radius: 46, fuse: 1.3),
};

const Color kBossShotColor = Color(0xFFFF9A56);
const Color kBossHeavyColor = Color(0xFFFF5A3C);
const double kBossShotRadius = 3.6;

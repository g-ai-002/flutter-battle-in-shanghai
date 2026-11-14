import 'dart:math' as math;
import 'dart:ui';

import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_scenes.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:battle_in_shanghai/game/boss_patterns.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:battle_in_shanghai/theme/unit_art.dart';
import 'package:flutter_test/flutter_test.dart';

BattleSim makeSim({BattleScene scene = BattleScene.zhabei, int seed = 7}) {
  final sim = BattleSim(
    mode: BattleMode.campaign,
    difficulty: Difficulty.veteran,
    scene: scene,
    random: math.Random(seed),
  )..start();
  var elapsed = 0.0;
  while (elapsed < 1.6 - 1e-9) {
    sim.update(1 / 60);
    elapsed += 1 / 60;
  }
  sim.enemies.clear();
  sim.player.fireCooldown = 100;
  return sim;
}

EnemyUnit unit(
  EnemyKind kind, {
  double x = 150,
  double y = 200,
  double holdY = 200,
}) =>
    EnemyUnit(kind: kind, x: x, y: y, hp: 500, maxHp: 500, holdY: holdY)
      ..spawnGuard = 0;

EnemyUnit boss({double x = 150, double y = 78}) =>
    EnemyUnit(kind: EnemyKind.boss, x: x, y: y, hp: 900, maxHp: 900, holdY: y)
      ..attackTimer = 0;

void main() {
  group('兵种行为表', () {
    test('推进、驻守与头目三种行为各有归属', () {
      const advance = {EnemyKind.infantry, EnemyKind.raider, EnemyKind.shield};
      const hold = {
        EnemyKind.rifleman,
        EnemyKind.grenadier,
        EnemyKind.armoredCar,
      };
      for (final kind in EnemyKind.values) {
        final spec = EnemySpec.specs[kind]!;
        if (advance.contains(kind)) {
          expect(spec.ai, EnemyAi.advance, reason: kind.label);
          expect(spec.fire, isNull, reason: kind.label);
        } else if (hold.contains(kind)) {
          expect(spec.ai, EnemyAi.hold, reason: kind.label);
          expect(spec.fire, isNotNull, reason: kind.label);
        } else {
          expect(spec.ai, EnemyAi.boss, reason: kind.label);
        }
      }
    });

    test('自毁冲锋与正面装甲只落在对应兵种上', () {
      for (final kind in EnemyKind.values) {
        final spec = EnemySpec.specs[kind]!;
        expect(
          spec.ram,
          kind == EnemyKind.infantry || kind == EnemyKind.raider,
          reason: kind.label,
        );
        expect(
          spec.frontArmor,
          kind == EnemyKind.shield ? kShieldBlock : 0,
          reason: kind.label,
        );
      }
    });

    test('士兵外观表覆盖全部步行兵种，并带刀 / 盾标志', () {
      for (final kind in EnemyKind.values) {
        final walker = kind != EnemyKind.armoredCar && kind != EnemyKind.boss;
        expect(enemyLooks.containsKey(kind), walker, reason: kind.label);
      }
      final raider = enemyLooks[EnemyKind.raider]!;
      final shield = enemyLooks[EnemyKind.shield]!;
      expect(raider.blade, isTrue);
      expect(raider.shield, isFalse);
      expect(shield.shield, isTrue);
      expect(shield.blade, isFalse);
      expect(enemyLooks[EnemyKind.infantry]!.aimAtPlayer, isFalse);
      expect(enemyLooks[EnemyKind.rifleman]!.aimAtPlayer, isTrue);
    });
  });

  group('驻守开火表', () {
    test('枪手按 1.5 秒节奏打出单发 152 速子弹', () {
      final sim = makeSim();
      sim.enemies.add(unit(EnemyKind.rifleman));
      sim.update(1 / 60);
      expect(sim.enemyShots, hasLength(1));
      final shot = sim.enemyShots.single;
      expect(shot.damage, closeTo(11, 0.001));
      expect(
        math.sqrt(shot.vx * shot.vx + shot.vy * shot.vy),
        closeTo(152, 0.01),
      );
      expect(shot.radius, 3);
    });

    test('装甲车三连发，左右各偏 0.10 弧度', () {
      final sim = makeSim();
      sim.enemies.add(unit(EnemyKind.armoredCar));
      sim.update(1 / 60);
      expect(sim.enemyShots, hasLength(3));
      expect(sim.enemyShots.map((shot) => shot.radius), everyElement(3.4));
      expect(
        sim.enemyShots.map((shot) => shot.color.toARGB32()),
        everyElement(0xFFFFB066),
      );
    });

    test('掷弹兵抛出 1.2 秒引信、44 半径的手雷', () {
      final sim = makeSim();
      sim.enemies.add(unit(EnemyKind.grenadier));
      sim.update(1 / 60);
      expect(sim.hazards, hasLength(1));
      final hazard = sim.hazards.single;
      expect(hazard.kind, HazardKind.grenade);
      expect(hazard.duration, closeTo(1.2, 0.001));
      expect(hazard.radius, 44);
      expect(hazard.damage, closeTo(22, 0.001));
      expect(hazard.fromPlayer, isFalse);
    });
  });

  group('头目弹幕表', () {
    test('四处阵地都有扇形、齐射、增援与一种重火力', () {
      for (final scene in BattleScene.values) {
        final kit = bossKits[scene]!;
        expect(kit.fan.count, greaterThan(1), reason: scene.label);
        expect(kit.aimed.count, greaterThan(1), reason: scene.label);
        expect(kit.summon.count, greaterThan(0), reason: scene.label);
        expect(
          (kit.direct == null) != (kit.bombard == null),
          isTrue,
          reason: scene.label,
        );
      }
      expect(bossKits[BattleScene.zhabei]!.summon.kind, EnemyKind.infantry);
      expect(bossKits[BattleScene.bund]!.summon.kind, EnemyKind.rifleman);
      expect(bossKits[BattleScene.warehouse]!.summon.kind, EnemyKind.raider);
      expect(bossKits[BattleScene.suzhou]!.summon.kind, EnemyKind.rifleman);
    });

    test('闸北重炮直射，其余阵地的炮击按表取值', () {
      final zhabei = makeSim();
      zhabei.enemies.add(boss()..pattern = 3);
      zhabei.update(1 / 60);
      expect(zhabei.hazards, isEmpty);
      expect(zhabei.enemyShots.single.radius, 6);
      expect(zhabei.enemyShots.single.damage, closeTo(22, 0.001));

      for (final scene in [
        BattleScene.bund,
        BattleScene.warehouse,
        BattleScene.suzhou,
      ]) {
        final sim = makeSim(scene: scene);
        sim.enemies.add(boss()..pattern = 3);
        sim.update(1 / 60);
        final bomb = sim.hazards.single;
        final expected = bossKits[scene]!.bombard!;
        expect(bomb.kind, HazardKind.bomb, reason: scene.label);
        expect(bomb.duration, closeTo(expected.fuse, 0.001));
        expect(bomb.radius, expected.radius);
        expect(bomb.damage, closeTo(expected.damage, 0.001));
      }
    });

    test('巡逻与开火节奏来自常量表，四招循环', () {
      final sim = makeSim();
      final leader = boss()
        ..timer = math.pi / (2 * kBossPatrolSpeed)
        ..attackTimer = 100;
      sim.enemies.add(leader);
      sim.update(1 / 60);
      expect(leader.x, greaterThan(kBossPatrolCenter + kBossPatrolSpan - 1));
      expect(leader.attackTimer, closeTo(100 - 1 / 60, 0.001));

      final firing = makeSim();
      final shooter = boss()..pattern = 0;
      firing.enemies.add(shooter);
      firing.update(1 / 60);
      expect(
        firing.enemyShots,
        hasLength(bossKits[BattleScene.zhabei]!.fan.count),
      );
      expect(shooter.pattern, 1);
      expect(shooter.attackTimer, closeTo(kBossInterval, 0.001));
    });

    test('头目子弹统一配色，扇形与齐射共用半径', () {
      final sim = makeSim();
      sim.enemies.add(boss());
      sim.update(1 / 60);
      expect(
        sim.enemyShots.map((shot) => shot.color.toARGB32()),
        everyElement(kBossShotColor.toARGB32()),
      );
      expect(
        sim.enemyShots.map((shot) => shot.radius),
        everyElement(kBossShotRadius),
      );
      expect(const Color(0xFFFF5A3C), kBossHeavyColor);
    });
  });
}

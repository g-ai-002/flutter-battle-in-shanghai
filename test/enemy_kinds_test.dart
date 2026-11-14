import 'dart:math' as math;
import 'dart:ui';

import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_scenes.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:battle_in_shanghai/game/campaign_waves.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:battle_in_shanghai/game/wave_plan.dart';
import 'package:flutter_test/flutter_test.dart';

BattleSim makeSim({BattleScene scene = BattleScene.zhabei, int seed = 7}) {
  final sim = BattleSim(
    mode: BattleMode.campaign,
    difficulty: Difficulty.veteran,
    scene: scene,
    random: math.Random(seed),
  )..start();
  // 越过第一波的集结时间，同时把自动射击关掉，避免子弹干扰判定。
  var elapsed = 0.0;
  while (elapsed < 1.6 - 1e-9) {
    sim.update(1 / 60);
    elapsed += 1 / 60;
  }
  sim.enemies.clear();
  sim.player.fireCooldown = 100;
  return sim;
}

EnemyUnit unit(EnemyKind kind, {double x = 150, double y = 200, double hp = 100}) =>
    EnemyUnit(kind: kind, x: x, y: y, hp: hp, maxHp: hp, holdY: 0);

EnemyUnit boss(EnemyKind kind, {double x = 150, double y = 78}) => EnemyUnit(
  kind: kind,
  x: x,
  y: y,
  hp: 900,
  maxHp: 900,
  holdY: y,
)..attackTimer = 0;

BattleBullet shotAt(EnemyUnit target) => BattleBullet(
  x: target.x,
  y: target.y + 12,
  vx: 0,
  vy: -600,
  damage: 20,
  radius: 2.4,
  fromPlayer: true,
  color: const Color(0xFFFFD166),
);

void main() {
  group('新兵种', () {
    test('刀锋兵比步兵快，盾牌兵更慢且被标记为精英', () {
      final infantry = EnemySpec.specs[EnemyKind.infantry]!;
      final raider = EnemySpec.specs[EnemyKind.raider]!;
      final shield = EnemySpec.specs[EnemyKind.shield]!;
      expect(raider.speed, greaterThan(infantry.speed));
      expect(raider.hp, lessThan(infantry.hp));
      expect(shield.speed, lessThan(infantry.speed));
      expect(shield.hp, greaterThan(infantry.hp));
      expect(shield.elite, isTrue);
    });

    test('刀锋兵冲锋比步兵推进得更远', () {
      final sim = makeSim();
      final raider = unit(EnemyKind.raider, y: 100);
      final infantry = unit(EnemyKind.infantry, y: 100);
      sim.enemies.addAll([raider, infantry]);
      for (var i = 0; i < 30; i++) {
        sim.update(1 / 60);
      }
      expect(raider.y, greaterThan(infantry.y));
      expect(raider.y - 100, greaterThan(20));
    });

    test('刀锋兵贴身冲锋会造成伤害并同归于尽', () {
      final sim = makeSim();
      sim.enemies.clear();
      final raider = unit(
        EnemyKind.raider,
        x: sim.player.x,
        y: sim.player.y,
      )..spawnGuard = 0;
      sim.enemies.add(raider);
      final before = sim.player.hp;
      sim.update(1 / 60);
      expect(sim.player.hp, lessThan(before));
      expect(raider.dead, isTrue);
    });

    test('盾牌兵挡下部分子弹伤害，步兵则吃满伤害', () {
      final shieldSim = makeSim();
      final shield = unit(EnemyKind.shield);
      shieldSim.enemies.add(shield);
      shieldSim.playerShots.add(shotAt(shield));
      shieldSim.update(1 / 60);

      final infantrySim = makeSim();
      final infantry = unit(EnemyKind.infantry);
      infantrySim.enemies.add(infantry);
      infantrySim.playerShots.add(shotAt(infantry));
      infantrySim.update(1 / 60);

      expect(shield.hp, closeTo(100 - 20 * (1 - kShieldBlock), 0.01));
      expect(infantry.hp, closeTo(80, 0.01));
      expect(shield.hp, greaterThan(infantry.hp));
    });

    test('手雷与空袭的爆炸伤害无视盾牌', () {
      final sim = makeSim();
      final shield = unit(EnemyKind.shield);
      sim.enemies.add(shield);
      sim.hazards.add(
        GrenadeHazard(
          fromX: 150,
          fromY: 120,
          toX: shield.x,
          toY: shield.y,
          duration: 0.01,
          damage: 20,
          radius: 30,
          fromPlayer: true,
        ),
      );
      sim.update(0.02);
      expect(shield.hp, closeTo(80, 0.01));
    });
  });

  group('阵地头目', () {
    test('三处阵地的扇形弹幕张角各不相同', () {
      double widestVx(BattleScene scene) {
        final sim = makeSim(scene: scene);
        sim.enemies.add(boss(EnemyKind.boss));
        sim.update(1 / 60);
        return sim.enemyShots
            .map((bullet) => bullet.vx.abs())
            .reduce(math.max);
      }

      expect(widestVx(BattleScene.warehouse), greaterThan(widestVx(BattleScene.zhabei)));
      expect(widestVx(BattleScene.zhabei), greaterThan(widestVx(BattleScene.bund)));
    });

    test('头目增援随阵地变化：步兵、枪手与刀锋兵', () {
      List<EnemyKind> summons(BattleScene scene) {
        final sim = makeSim(scene: scene);
        final leader = boss(EnemyKind.boss)..pattern = 2;
        sim.enemies.add(leader);
        sim.update(1 / 60);
        return sim.enemies
            .where((enemy) => enemy != leader)
            .map((enemy) => enemy.kind)
            .toList();
      }

      expect(summons(BattleScene.zhabei), everyElement(EnemyKind.infantry));
      expect(summons(BattleScene.bund), everyElement(EnemyKind.rifleman));
      expect(summons(BattleScene.warehouse), everyElement(EnemyKind.raider));
    });

    test('闸北重炮直射，外滩与仓库改为炮击预警', () {
      for (final scene in BattleScene.values) {
        final sim = makeSim(scene: scene);
        sim.enemies.add(boss(EnemyKind.boss)..pattern = 3);
        sim.update(1 / 60);
        if (scene == BattleScene.zhabei) {
          expect(sim.enemyShots, isNotEmpty, reason: scene.label);
          expect(sim.hazards, isEmpty, reason: scene.label);
        } else {
          expect(sim.hazards, hasLength(1), reason: scene.label);
          expect(sim.hazards.single.kind, HazardKind.bomb, reason: scene.label);
        }
      }
    });

    test('头目播报使用阵地专属名称', () {
      final sim = makeSim(scene: BattleScene.warehouse);
      expect(sim.scene.bossName, '重型突击炮');
    });
  });

  group('波次混编', () {
    test('三处战役都混入了刀锋兵或盾牌兵', () {
      for (final scene in BattleScene.values) {
        final kinds = sceneWaves(scene, Difficulty.veteran)
            .expand((wave) => wave.orders)
            .map((order) => order.kind)
            .toSet();
        expect(
          kinds.intersection({EnemyKind.raider, EnemyKind.shield}),
          isNotEmpty,
          reason: scene.label,
        );
      }
    });

    test('无尽模式后期加入刀锋兵与盾牌兵', () {
      final mid = endlessWave(6, Difficulty.veteran).orders;
      final late = endlessWave(8, Difficulty.veteran).orders;
      expect(mid.map((order) => order.kind), contains(EnemyKind.raider));
      expect(late.map((order) => order.kind), contains(EnemyKind.raider));
      expect(late.map((order) => order.kind), contains(EnemyKind.shield));
    });
  });
}

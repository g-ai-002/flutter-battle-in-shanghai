import 'dart:math' as math;
import 'dart:ui';

import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

BattleSim makeSim({
  BattleMode mode = BattleMode.campaign,
  Difficulty difficulty = Difficulty.veteran,
  int seed = 7,
}) => BattleSim(mode: mode, difficulty: difficulty, random: math.Random(seed));

void advance(BattleSim sim, double seconds, {double step = 1 / 60}) {
  var elapsed = 0.0;
  while (elapsed < seconds - 1e-9) {
    sim.update(step);
    elapsed += step;
  }
}

EnemyUnit dummyEnemy({
  required double x,
  required double y,
  double hp = 30,
  EnemyKind kind = EnemyKind.infantry,
  double holdY = 0,
  double guard = 0,
}) =>
    EnemyUnit(
      kind: kind,
      x: x,
      y: y,
      hp: hp,
      maxHp: hp,
      holdY: holdY,
    )..spawnGuard = guard;

/// 把一波敌军直接判定死亡并推进，用于快速跑完波次。
void clearEnemies(BattleSim sim) {
  for (final enemy in sim.enemies) {
    enemy.hp = 0;
    enemy.dead = true;
  }
}

void main() {
  group('开局', () {
    test('初始处于待命状态，玩家满血位于街道下方', () {
      final sim = makeSim();
      expect(sim.status, BattleStatus.ready);
      expect(sim.wave, 0);
      expect(sim.player.hp, kPlayerMaxHp);
      expect(sim.player.y, greaterThan(Field.playerMinY));
      expect(sim.playerShots, isEmpty);
      expect(sim.cues, isEmpty);
    });

    test('开始后进入第一波，先有集结时间再出怪', () {
      final sim = makeSim()..start();
      expect(sim.status, BattleStatus.running);
      expect(sim.wave, 1);
      expect(sim.waveBreak, greaterThan(0));
      expect(sim.announcing, isTrue);
      expect(sim.enemies, isEmpty);

      advance(sim, 1.6);
      expect(sim.waveBreak, lessThanOrEqualTo(0));
      advance(sim, 0.6);
      expect(sim.enemies, isNotEmpty);
      expect(sim.remainingEnemies, greaterThan(0));
    });

    test('重开会清空战场并回到第一波', () {
      final sim = makeSim()..start();
      advance(sim, 3);
      sim.throwGrenade();
      sim.restart();
      expect(sim.status, BattleStatus.running);
      expect(sim.score, 0);
      expect(sim.kills, 0);
      expect(sim.wave, 1);
      expect(sim.hazards, isEmpty);
      expect(sim.player.hp, kPlayerMaxHp);
      expect(sim.player.weapon, WeaponKind.pistol);
    });
  });

  group('移动与射击', () {
    test('玩家被限制在战场下半段内', () {
      final sim = makeSim()..start();
      sim.movePlayer(-1000, -1000);
      expect(sim.player.x, Field.playerMarginX);
      expect(sim.player.y, Field.playerMinY);
      sim.movePlayer(1000, 1000);
      expect(sim.player.x, Field.width - Field.playerMarginX);
      expect(sim.player.y, Field.playerMaxY);
    });

    test('开战后自动朝正前方射击', () {
      final sim = makeSim()..start();
      advance(sim, 1.7);
      expect(sim.playerShots, isNotEmpty);
      expect(sim.playerShots.first.vy, lessThan(0));
      expect(sim.cues, contains(BattleCue.shot));
    });

    test('冲锋枪射速更快，弹道数量更多', () {
      final sim = makeSim()..start();
      advance(sim, 1.7);
      sim.enemies.clear();
      sim.playerShots.clear();
      sim.player.weapon = WeaponKind.smg;
      sim.player.weaponUntil = sim.time + 10;
      advance(sim, 1);
      final smgShots = sim.playerShots.length;

      final pistol = makeSim()..start();
      advance(pistol, 1.7);
      pistol.enemies.clear();
      pistol.playerShots.clear();
      advance(pistol, 1);
      expect(smgShots, greaterThan(pistol.playerShots.length));
    });

    test('临时武器到期后回到手枪', () {
      final sim = makeSim()..start();
      advance(sim, 1.7);
      sim.player.weapon = WeaponKind.shotgun;
      sim.player.weaponUntil = sim.time + 0.05;
      advance(sim, 0.2);
      expect(sim.player.weapon, WeaponKind.pistol);
      expect(sim.weaponSecondsLeft, 0);
    });
  });

  group('伤害与得分', () {
    BattleSim readySim() {
      final sim = makeSim()..start();
      advance(sim, 1.7);
      sim.enemies.clear();
      return sim;
    }

    test('击破头目必定掉落急救包与弹药箱', () {
      final sim = readySim();
      sim.enemies.add(
        dummyEnemy(
          x: sim.player.x,
          y: sim.player.y - 40,
          hp: 1,
          kind: EnemyKind.boss,
          holdY: 78,
        ),
      );
      advance(sim, 0.3);
      expect(sim.enemies.any((enemy) => enemy.isBoss), isFalse);
      expect(sim.pickups.length, greaterThanOrEqualTo(2));
      expect(
        sim.pickups.any((pickup) => pickup.kind == PickupKind.medkit),
        isTrue,
      );
      expect(
        sim.pickups.any((pickup) => pickup.kind == PickupKind.ammo),
        isTrue,
      );
    });

    test('击破步兵获得分数与连击', () {
      final sim = readySim();
      final before = sim.score;
      sim.enemies.add(dummyEnemy(x: sim.player.x, y: sim.player.y - 26));
      advance(sim, 0.4);
      expect(sim.kills, 1);
      expect(sim.score, greaterThan(before));
      expect(sim.combo, 1);
      expect(sim.enemies.every((enemy) => !enemy.dead), isTrue);
    });

    test('连击倍率随击杀提升且有上限', () {
      final sim = readySim();
      sim.combo = 0;
      expect(sim.comboMultiplier, 1);
      sim.combo = kComboStep;
      expect(sim.comboMultiplier, closeTo(1.25, 1e-9));
      sim.combo = 999;
      expect(sim.comboMultiplier, kMaxComboMultiplier);
    });

    test('敌军子弹命中扣血，短暂无敌期内不再扣血', () {
      final sim = readySim();
      sim.enemyShots.add(
        BattleBullet(
          x: sim.player.x,
          y: sim.player.y,
          vx: 0,
          vy: 0,
          damage: 10,
          radius: 3,
          fromPlayer: false,
          color: const Color(0xFF000000),
        ),
      );
      final hp = sim.player.hp;
      advance(sim, 1 / 60);
      expect(sim.player.hp, hp - 10);
      sim.enemyShots.add(
        BattleBullet(
          x: sim.player.x,
          y: sim.player.y,
          vx: 0,
          vy: 0,
          damage: 10,
          radius: 3,
          fromPlayer: false,
          color: const Color(0xFF000000),
        ),
      );
      advance(sim, 1 / 60);
      expect(sim.player.hp, hp - 10);
    });

    test('护盾期间免疫伤害', () {
      final sim = readySim();
      sim.player.shieldUntil = sim.time + 5;
      expect(sim.shieldActive, isTrue);
      sim.enemyShots.add(
        BattleBullet(
          x: sim.player.x,
          y: sim.player.y,
          vx: 0,
          vy: 0,
          damage: 15,
          radius: 3,
          fromPlayer: false,
          color: const Color(0xFF000000),
        ),
      );
      advance(sim, 1 / 60);
      expect(sim.player.hp, kPlayerMaxHp);
    });

    test('步兵贴近街垒会连续造成接触伤害', () {
      final sim = readySim();
      sim.player.hp = 60;
      sim.enemies.add(
        dummyEnemy(x: sim.player.x, y: sim.player.y),
      );
      advance(sim, 1 / 60);
      expect(sim.player.hp, 60 - 14);
    });

    test('生命耗尽判定失败并给出结算数据', () {
      final sim = readySim();
      sim.player.hp = 4;
      sim.enemies.add(
        dummyEnemy(x: sim.player.x, y: sim.player.y),
      );
      advance(sim, 0.1);
      expect(sim.status, BattleStatus.lost);
      expect(sim.finished, isTrue);
      expect(sim.result.won, isFalse);
      expect(sim.cues, contains(BattleCue.defeat));
    });
  });

  group('手雷与补给', () {
    test('手雷飞向最近的敌军并造成范围伤害', () {
      final sim = makeSim()..start();
      advance(sim, 1.7);
      sim.enemies.clear();
      final enemy = dummyEnemy(x: 210, y: 120, hp: 500);
      sim.enemies.add(enemy);
      expect(sim.throwGrenade(), isTrue);
      expect(sim.hazards, hasLength(1));
      expect(sim.throwGrenade(), isFalse);
      expect(sim.grenadeCooldownLeft, greaterThan(0));
      advance(sim, 0.9);
      expect(sim.hazards, isEmpty);
      expect(enemy.hp, lessThan(500));
    });

    test('急救包回复生命，弹药箱切换武器', () {
      final sim = makeSim()..start();
      advance(sim, 1.7);
      sim.player.hp = 40;
      sim.pickups.add(
        PickupItem(kind: PickupKind.medkit, x: sim.player.x, y: sim.player.y),
      );
      advance(sim, 1 / 60);
      expect(sim.player.hp, 70);
      expect(sim.pickups, isEmpty);

      sim.pickups.add(
        PickupItem(kind: PickupKind.ammo, x: sim.player.x, y: sim.player.y),
      );
      advance(sim, 1 / 60);
      expect(sim.player.weapon, isNot(WeaponKind.pistol));
      expect(sim.weaponSecondsLeft, greaterThan(0));
    });

    test('钢盔提供限时护盾', () {
      final sim = makeSim()..start();
      advance(sim, 1.7);
      sim.pickups.add(
        PickupItem(kind: PickupKind.shield, x: sim.player.x, y: sim.player.y),
      );
      advance(sim, 1 / 60);
      expect(sim.shieldActive, isTrue);
      expect(
        sim.player.shieldUntil - sim.time,
        closeTo(kPlayerMaxShieldSeconds, 0.2),
      );
    });
  });

  group('波次推进', () {
    test('清空一波后进入下一波，并给出波次奖励', () {
      final sim = makeSim()..start();
      var steps = 0;
      while (sim.wave < 2 && steps < 4000) {
        sim.update(0.05);
        sim.enemyShots.clear();
        sim.hazards.clear();
        clearEnemies(sim);
        steps++;
      }
      expect(sim.wave, 2);
      expect(sim.score, greaterThan(0));
      expect(steps, lessThan(4000));
    });

    test('战役模式击退五波后胜利', () {
      final sim = makeSim()..start();
      var steps = 0;
      var sawBoss = false;
      while (!sim.finished && steps < 20000) {
        sim.update(0.05);
        sim.enemyShots.clear();
        sim.hazards.clear();
        if (sim.boss != null) sawBoss = true;
        clearEnemies(sim);
        steps++;
      }
      expect(sim.finished, isTrue);
      expect(sim.status, BattleStatus.won);
      expect(sawBoss, isTrue);
      expect(sim.score, greaterThan(0));
      expect(sim.result.won, isTrue);
      expect(sim.cues, contains(BattleCue.victory));
    });

    test('无尽模式不会通关，波次持续增长', () {
      final sim = makeSim(mode: BattleMode.endless)..start();
      var steps = 0;
      while (sim.wave < 6 && steps < 8000) {
        sim.update(0.05);
        sim.enemyShots.clear();
        sim.hazards.clear();
        clearEnemies(sim);
        steps++;
      }
      expect(sim.wave, greaterThanOrEqualTo(6));
      expect(sim.status, isNot(BattleStatus.won));
    });

    test('暂停期间战场完全静止', () {
      final sim = makeSim()..start();
      advance(sim, 1.7);
      sim.pause();
      final time = sim.time;
      final hp = sim.player.hp;
      advance(sim, 3);
      expect(sim.time, time);
      expect(sim.player.hp, hp);
      sim.resume();
      advance(sim, 0.2);
      expect(sim.time, greaterThan(time));
    });
  });

  group('音效提示', () {
    test('提示队列由外部取走，重复播放不重复入队', () {
      final sim = makeSim()..start();
      advance(sim, 1.7);
      expect(sim.cues, isNotEmpty);
      sim.cues.clear();
      sim.throwGrenade();
      expect(sim.cues, contains(BattleCue.enemyShot));
      advance(sim, 0.8);
      expect(sim.cues, contains(BattleCue.explosion));
    });
  });
}

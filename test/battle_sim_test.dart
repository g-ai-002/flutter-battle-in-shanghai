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

    test('飞出战场的子弹被原地清理，留下的子弹保持顺序', () {
      final sim = makeSim()..start();
      advance(sim, 1.7);
      sim.enemies.clear();
      sim.playerShots.clear();
      sim.enemyShots.clear();
      // 关掉自动射击，避免新子弹干扰统计。
      sim.player.fireCooldown = 10;
      final keep = BattleBullet(
        x: 150,
        y: 200,
        vx: 0,
        vy: -60,
        damage: 5,
        radius: 2,
        fromPlayer: true,
        color: const Color(0xFFFFD166),
      );
      sim.playerShots.add(keep);
      sim.playerShots.add(
        BattleBullet(
          x: 150,
          y: -20,
          vx: 0,
          vy: -300,
          damage: 5,
          radius: 2,
          fromPlayer: true,
          color: const Color(0xFFFFD166),
        ),
      );
      sim.enemyShots.add(
        BattleBullet(
          x: 150,
          y: Field.height + 4,
          vx: 0,
          vy: 300,
          damage: 5,
          radius: 2,
          fromPlayer: false,
          color: const Color(0xFFFF8A5B),
        ),
      );
      advance(sim, 0.1);
      expect(sim.playerShots, [same(keep)]);
      expect(sim.enemyShots, isEmpty);
    });

    test('子弹尾焰颜色按阵营在生成时确定', () {
      final friendly = BattleBullet(
        x: 0,
        y: 0,
        vx: 0,
        vy: -100,
        damage: 1,
        radius: 2,
        fromPlayer: true,
        color: const Color(0xFFFFD166),
      );
      final hostile = BattleBullet(
        x: 0,
        y: 0,
        vx: 0,
        vy: 100,
        damage: 1,
        radius: 2,
        fromPlayer: false,
        color: const Color(0xFFFF8A5B),
      );
      expect(friendly.trailColor.a, closeTo(0.4, 1e-6));
      expect(hostile.trailColor.a, closeTo(0.35, 1e-6));
      expect(friendly.trailColor.r, friendly.color.r);
      expect(hostile.trailColor.g, hostile.color.g);
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

  group('工事与掩体', () {
    BattleSim readySim() {
      final sim = makeSim()..start();
      advance(sim, 1.7);
      sim.enemies.clear();
      return sim;
    }

    test('开局布置两处工事，站在后方即可进入掩护状态', () {
      final sim = makeSim()..start();
      expect(sim.covers, hasLength(2));
      expect(sim.coverLimit, kCoverMax);

      final cover = sim.covers.first;
      sim.player.x = cover.x;
      sim.player.y = cover.y + 20;
      expect(sim.sheltering, isTrue);

      sim.player.y = cover.y - 20;
      expect(sim.sheltering, isFalse);
      sim.player.y = cover.y + 20;
      sim.player.x = cover.x + kCoverHalfWidth + 40;
      expect(sim.sheltering, isFalse);
    });

    test('掩护状态下受到的伤害减少四成', () {
      final sim = readySim();
      final cover = sim.covers.first;
      sim.player.x = cover.x;
      sim.player.y = cover.y + 20;
      sim.enemyShots.add(
        BattleBullet(
          x: sim.player.x,
          y: sim.player.y,
          vx: 0,
          vy: 0,
          damage: 20,
          radius: 3,
          fromPlayer: false,
          color: const Color(0xFF000000),
        ),
      );
      final hp = sim.player.hp;
      advance(sim, 1 / 60);
      expect(sim.player.hp, closeTo(hp - 12, 1e-9));
    });

    test('敌军子弹被沙袋吸收，工事掉血', () {
      final sim = readySim();
      sim.player.fireCooldown = 999;
      final cover = sim.covers.first;
      final hp = cover.hp;
      sim.enemyShots.add(
        BattleBullet(
          x: cover.x,
          y: cover.top - 12,
          vx: 0,
          vy: 120,
          damage: 30,
          radius: 3,
          fromPlayer: false,
          color: const Color(0xFF000000),
        ),
      );
      advance(sim, 0.2);
      expect(sim.enemyShots, isEmpty);
      expect(cover.hp, lessThan(hp));
      expect(sim.player.hp, kPlayerMaxHp);
    });

    test('步兵被工事挡住，一边挖沙袋一边停下', () {
      final sim = readySim();
      sim.player.fireCooldown = 999;
      final cover = sim.covers.first;
      final enemy = dummyEnemy(
        x: cover.x,
        y: cover.top - 6,
        hp: 40000,
      );
      sim.enemies.add(enemy);
      final hp = cover.hp;
      advance(sim, 0.6);
      expect(enemy.y, lessThan(cover.bottom + 20));
      expect(cover.hp, lessThan(hp));
      expect(sim.player.hp, kPlayerMaxHp);
    });

    test('工事有冷却与数量上限，重开后复位', () {
      final sim = readySim();
      sim.player.fireCooldown = 999;
      sim.player.x = 40;
      expect(sim.deployCover(), isTrue);
      expect(sim.covers, hasLength(3));
      expect(sim.coverCooldownLeft, greaterThan(0));
      expect(sim.deployCover(), isFalse);

      sim.restart();
      expect(sim.covers, hasLength(2));
      expect(sim.coverCooldownLeft, 0);
    });

    test('工事到期后自动拆除', () {
      final sim = readySim();
      final cover = sim.covers.first;
      cover.life = 0.05;
      advance(sim, 0.2);
      expect(sim.covers, hasLength(1));
      expect(sim.cues, contains(BattleCue.cover));
    });
  });

  group('空袭支援', () {
    test('呼叫后进入冷却，炸弹落地清除集群', () {
      final sim = makeSim()..start();
      advance(sim, 9);
      sim.enemies.clear();
      sim.player.fireCooldown = 999;
      final cluster = [
        for (var i = 0; i < 3; i++)
          dummyEnemy(x: 120.0 + i * 14, y: 120, hp: 120),
      ];
      sim.enemies.addAll(cluster);
      expect(sim.airstrikeCooldownLeft, 0);
      expect(sim.callAirstrike(), isTrue);
      expect(sim.airstrikeCooldownLeft, greaterThan(0));
      expect(sim.callAirstrike(), isFalse);
      expect(sim.hazards, hasLength(kAirstrikeBombs));
      expect(
        sim.hazards.every((hazard) => hazard.kind == HazardKind.bomb),
        isTrue,
      );

      advance(sim, 2.4);
      expect(sim.hazards, isEmpty);
      // 后续波次可能已经补进新敌军，只要求被瞄准的这一群全部被清除。
      expect(sim.enemies.any(cluster.contains), isFalse);
      expect(sim.kills, greaterThanOrEqualTo(3));
    });

    test('开局需要等待片刻才能呼叫空袭，炸弹不会伤到自己', () {
      final sim = makeSim()..start();
      expect(sim.airstrikeCooldownLeft, greaterThan(0));
      expect(sim.callAirstrike(), isFalse);
      advance(sim, 8.2);
      sim.enemies.clear();
      sim.enemies.add(dummyEnemy(x: 150, y: 120, hp: 4000));
      sim.player.fireCooldown = 999;
      final hp = sim.player.hp;
      expect(sim.callAirstrike(), isTrue);
      advance(sim, 2);
      expect(sim.player.hp, hp);
      expect(sim.enemies.single.hp, lessThan(4000));
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

  group('视觉反馈', () {
    test('爆炸抖动按时间衰减，不会永久停留', () {
      final sim = makeSim()..start();
      // 关掉自动射击，避免枪口抖动干扰衰减断言。
      sim.player.fireCooldown = 999;
      sim.shake = 12;
      advance(sim, 0.1);
      expect(sim.shake, lessThan(12));
      advance(sim, 0.6);
      expect(sim.shake, 0);
    });

    test('集结提示按波次倒计时淡出', () {
      final sim = makeSim()..start();
      expect(sim.announcing, isTrue);
      expect(sim.waveBreakRatio, greaterThan(0));
      advance(sim, 1.6);
      expect(sim.waveBreakRatio, lessThanOrEqualTo(0));
    });

    test('粒子对象复用且同时存在的数量有上限', () {
      final sim = makeSim()..start();
      sim.player.fireCooldown = 999;

      GrenadeHazard blast(double x, double y) => GrenadeHazard(
        fromX: x,
        fromY: y,
        toX: x,
        toY: y,
        duration: 0.01,
        damage: 0,
        radius: 24,
        fromPlayer: false,
      );

      for (var i = 0; i < 40; i++) {
        sim.hazards.add(blast(150, 220));
      }
      advance(sim, 0.05);
      expect(sim.particles, isNotEmpty);
      expect(sim.particles.length, lessThanOrEqualTo(BattleSim.maxParticles));
      final spawned = Set<Particle>.identity()..addAll(sim.particles);

      // 等所有粒子熄灭后再次爆炸，死亡粒子应从对象池里取回复用。
      advance(sim, 2.2);
      expect(sim.particles, isEmpty);
      for (var i = 0; i < 20; i++) {
        sim.hazards.add(blast(150, 220));
      }
      advance(sim, 0.05);
      expect(sim.particles.any(spawned.contains), isTrue);
    });
  });
}

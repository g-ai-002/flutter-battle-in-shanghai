import 'dart:math' as math;
import 'dart:ui' show Color;

import '../utils/constants.dart';
import 'airstrike.dart';
import 'battle_config.dart';
import 'battle_feedback.dart';
import 'battle_scenes.dart';
import 'combat_math.dart';
import 'cover_field.dart';
import 'entities.dart';
import 'supply_drop.dart';
import 'wave_director.dart';
import 'wave_plan.dart';

/// 战场模拟：纯 Dart 的固定步长逻辑，不依赖 Flutter 渲染与平台能力。
///
/// 渲染层只读取实体列表，输入通过 [movePlayer] / [throwGrenade] 进入，
/// 声音等反馈以 [cues] 队列交给控制器。这样逻辑可以在测试里直接推进。
class BattleSim {
  BattleSim({
    required this.mode,
    required this.difficulty,
    this.scene = BattleScene.zhabei,
    math.Random? random,
  }) : _random = random ?? math.Random() {
    _feedback = BattleFeedback(random: _random);
    _waves = WaveDirector(
      mode: mode,
      difficulty: difficulty,
      scene: scene,
      random: _random,
    );
    player = PlayerSoldier(x: Field.width / 2, y: Field.playerStartY);
  }

  final BattleMode mode;
  final Difficulty difficulty;

  /// 当前阵地：决定街景配色、阵地景物与战役波次表。
  final BattleScene scene;
  final math.Random _random;
  late final BattleFeedback _feedback;
  final CoverField _covers = CoverField();
  late final WaveDirector _waves;

  late PlayerSoldier player;

  BattleStatus status = BattleStatus.ready;
  double time = 0;
  int score = 0;
  int kills = 0;
  int combo = 0;
  int maxCombo = 0;
  double comboTimer = 0;

  final List<EnemyUnit> enemies = [];
  final List<BattleBullet> playerShots = [];
  final List<BattleBullet> enemyShots = [];
  final List<GrenadeHazard> hazards = [];
  final List<PickupItem> pickups = [];

  /// 粒子上限：满屏爆炸时保证绘制量可控。
  static const int maxParticles = BattleFeedback.maxParticles;

  List<CoverWall> get covers => _covers.walls;
  List<BattleEffect> get effects => _feedback.effects;
  List<ScorePopup> get popups => _feedback.popups;
  List<Particle> get particles => _feedback.particles;

  /// 待消费的播放提示，控制器取走后清空。
  List<BattleCue> get cues => _feedback.cues;

  double get shake => _feedback.shake;
  set shake(double value) => _feedback.shake = value;

  bool get running => status == BattleStatus.running;
  bool get finished =>
      status == BattleStatus.won || status == BattleStatus.lost;

  int get wave => _waves.wave;
  double get waveBreak => _waves.waveBreak;

  /// 战役模式的总波数，无尽模式返回 0。
  int get waveCount => _waves.waveCount;

  bool get bossActive => enemies.any((enemy) => enemy.isBoss);
  EnemyUnit? get boss {
    for (final enemy in enemies) {
      if (enemy.isBoss) return enemy;
    }
    return null;
  }

  /// 尚未清完的敌军数量（含还没进场的）。
  int get remainingEnemies => enemies.length + _waves.pendingSpawns;

  bool get bossWarning => _waves.bossWarning;

  bool get announcing => _waves.announcing;

  /// 波次开始时的大字提示。
  String get announcement => _waves.announcement;

  /// 当前波次的阵型名称，例如「两翼夹击」。
  String get waveName => _waves.waveName;

  /// 集结提示的淡出进度，渲染层直接按它计算透明度。
  double get waveBreakRatio => _waves.announcementProgress;

  /// 战况条的一行短语，波次由独立的标签展示。
  String get brief {
    if (status == BattleStatus.won) return '阵地守住了';
    if (status == BattleStatus.lost) return '阵地失守';
    if (status == BattleStatus.paused) return '已暂停';
    if (status == BattleStatus.ready) return '准备战斗';
    if (waveBreak > 0) return _waves.phaseBrief;
    if (bossActive) return '头目战 · 剩余 $remainingEnemies';
    if (waveName.isEmpty) return '剩余敌军 $remainingEnemies';
    return '$waveName · 剩余敌军 $remainingEnemies';
  }

  double get comboMultiplier {
    final tier = math.min(combo ~/ kComboStep, 8);
    return math.min(1 + tier * kComboStepBonus, kMaxComboMultiplier);
  }

  double get grenadeCooldownLeft => math.max(0, player.grenadeReadyAt - time);

  double get coverCooldownLeft => math.max(0, player.coverReadyAt - time);

  double get airstrikeCooldownLeft =>
      math.max(0, player.airstrikeReadyAt - time);

  int get coverCount => _covers.count;
  int get coverLimit => CoverField.limit;

  /// 玩家是否蹲在工事后方的掩护范围内。
  bool get sheltering => _covers.shelteredAt(player.x, player.y);

  double get weaponSecondsLeft => player.weapon == WeaponKind.pistol
      ? 0
      : math.max(0, player.weaponUntil - time);

  bool get shieldActive => time < player.shieldUntil;

  /// 开始一波新的战斗。
  void start() {
    if (status != BattleStatus.ready) return;
    status = BattleStatus.running;
    player.airstrikeReadyAt = time + kAirstrikeInitialDelay;
    _covers.layStarting();
    _beginWave(1);
  }

  void pause() {
    if (status == BattleStatus.running) status = BattleStatus.paused;
  }

  void resume() {
    if (status == BattleStatus.paused) status = BattleStatus.running;
  }

  void restart() {
    status = BattleStatus.ready;
    time = 0;
    score = 0;
    kills = 0;
    combo = 0;
    maxCombo = 0;
    comboTimer = 0;
    enemies.clear();
    playerShots.clear();
    enemyShots.clear();
    hazards.clear();
    pickups.clear();
    _covers.clear();
    _feedback.clear();
    _waves.reset();
    player = PlayerSoldier(x: Field.width / 2, y: Field.playerStartY);
    start();
  }

  /// 推进一个逻辑步。
  void update(double dt) {
    if (dt <= 0) return;
    if (status != BattleStatus.running) {
      if (status != BattleStatus.paused) _updateDecorations(dt);
      return;
    }
    time += dt;
    _updateDecorations(dt);
    _updatePlayer(dt);
    // 子弹、手雷与补给在波次间也继续推进，集结期间打出的子弹不会堆在枪口。
    _updateBullets(dt);
    _updateHazards(dt);
    _updatePickups(dt);
    _updateCovers(dt);

    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) combo = 0;
    }

    if (waveBreak > 0) {
      _waves.tick(dt);
      return;
    }

    _spawnDue();
    _updateEnemies(dt);
    _resolveBulletHits();
    _resolvePickupGrab();
    _flushDeadEnemies();
    _advanceWave();

    if (player.hp <= 0) _lose();
  }

  void _updateDecorations(double dt) {
    _feedback.tick(dt);
    _waves.tickAnnouncement(dt);
  }

  void _updatePlayer(double dt) {
    player.muzzle = math.max(0, player.muzzle - dt);
    if (player.weapon != WeaponKind.pistol && time >= player.weaponUntil) {
      player.weapon = WeaponKind.pistol;
      player.weaponUntil = 0;
      _feedback.popup('弹药耗尽', player.x, player.y - 20, const Color(0xFFBFC7C9));
    }
    final spec = player.weaponSpec;
    player.fireCooldown -= dt;
    if (player.fireCooldown <= 0) {
      _fire(spec);
      player.fireCooldown = spec.interval;
    }
  }

  void _fire(WeaponSpec spec) {
    final spread = spec.spread;
    for (var i = 0; i < spec.pellets; i++) {
      final offset = spec.pellets == 1
          ? (_random.nextDouble() - 0.5) * spread
          : -spread / 2 + spread * i / (spec.pellets - 1);
      final angle = -math.pi / 2 + offset;
      playerShots.add(
        BattleBullet(
          x: player.x + math.cos(angle) * 7,
          y: player.y - 12 + math.sin(angle) * 7,
          vx: math.cos(angle) * spec.speed,
          vy: math.sin(angle) * spec.speed,
          damage: spec.damage,
          radius: 2.4,
          fromPlayer: true,
          color: spec.color,
        ),
      );
    }
    player.muzzle = 0.07;
    _feedback.effect(
      EffectKind.muzzle,
      player.x,
      player.y - 14,
      radius: 8,
      duration: 0.08,
    );
    _feedback.cue(BattleCue.shot);
    _feedback.kick(1.2);
  }

  void _beginWave(int index) {
    _feedback.cue(_waves.begin(index, time));
  }

  void _spawnDue() {
    for (final order in _waves.takeDue(time)) {
      _spawn(order);
    }
  }

  double get _enemyHpScale => difficulty.hpScale * _waves.hpMultiplier;

  void _spawn(SpawnOrder order) {
    _addEnemy(order.kind, x: order.x, y: Field.enemyTop, holdY: order.holdY);
  }

  void _addEnemy(
    EnemyKind kind, {
    required double x,
    required double y,
    required double holdY,
    double hpFactor = 1,
  }) {
    final spec = EnemySpec.specs[kind]!;
    final hp = spec.hp * _enemyHpScale * hpFactor;
    enemies.add(
      EnemyUnit(
        kind: kind,
        x: x.clamp(24.0, Field.width - 24).toDouble(),
        y: y,
        hp: hp,
        maxHp: hp,
        holdY: holdY,
      )..bobSeed = _random.nextDouble() * math.pi * 2,
    );
  }

  void _updateEnemies(double dt) {
    for (final enemy in enemies) {
      enemy.timer += dt;
      enemy.hitFlash = math.max(0, enemy.hitFlash - dt * 4);
      enemy.spawnGuard = math.max(0, enemy.spawnGuard - dt);
      switch (enemy.kind) {
        case EnemyKind.infantry:
          _advanceInfantry(enemy, dt);
        case EnemyKind.rifleman:
          _holdAndAttack(enemy, dt, interval: 1.5);
        case EnemyKind.grenadier:
          _holdAndAttack(enemy, dt, interval: 2.4);
        case EnemyKind.armoredCar:
          _holdAndAttack(
            enemy,
            dt,
            interval: 2.2,
            strafe: 46,
            strafeSpeed: 0.7,
          );
        case EnemyKind.boss:
          _updateBoss(enemy, dt);
      }
      enemy.x = enemy.x.clamp(20.0, Field.width - 20).toDouble();
      _resolveContact(enemy);
    }
  }

  /// 步兵推进：撞上工事就停下挖沙袋，把工事当成一道门槛。
  void _advanceInfantry(EnemyUnit enemy, double dt) {
    final cover = _covers.blockingAt(enemy.x, enemy.y);
    if (cover == null) {
      _marchDown(enemy, dt, sway: 15, swaySpeed: 2.6);
      return;
    }
    _covers.gnaw(cover, dt);
    if (effects.length < 24 && _random.nextDouble() < dt * 2.5) {
      _feedback.effect(
        EffectKind.dust,
        cover.x + (enemy.x - cover.x) * 0.6,
        cover.y - 4,
        radius: 10,
        duration: 0.4,
      );
    }
  }

  void _marchDown(
    EnemyUnit enemy,
    double dt, {
    double sway = 0,
    double swaySpeed = 1,
  }) {
    enemy.y += enemy.spec.speed * dt;
    if (sway > 0) {
      enemy.x += math.cos(enemy.timer * swaySpeed + enemy.bobSeed) * sway * dt;
    }
    if (enemy.y > Field.height + 24) {
      enemy.escaped = true;
      _damagePlayer(6, silent: true);
    }
  }

  void _holdAndAttack(
    EnemyUnit enemy,
    double dt, {
    required double interval,
    double strafe = 22,
    double strafeSpeed = 0.9,
  }) {
    final spec = enemy.spec;
    if (!enemy.stopped) {
      enemy.y = math.min(enemy.holdY, enemy.y + spec.speed * dt);
      return;
    }
    enemy.x +=
        math.sin(enemy.timer * strafeSpeed + enemy.bobSeed) * strafe * dt;
    enemy.attackTimer -= dt;
    if (enemy.attackTimer > 0) return;
    enemy.attackTimer = interval * (0.85 + _random.nextDouble() * 0.35);
    _enemyAttack(enemy);
  }

  /// 敌军开火：不同兵种使用不同的弹道。
  void _enemyAttack(EnemyUnit enemy) {
    final scale = difficulty.damageScale;
    switch (enemy.kind) {
      case EnemyKind.infantry:
        return;
      case EnemyKind.rifleman:
        _shootAt(
          enemy,
          player.x,
          player.y,
          speed: 152,
          damage: 11 * scale,
          radius: 3,
          spread: 0.04,
          color: const Color(0xFFFF8A5B),
        );
      case EnemyKind.grenadier:
        hazards.add(
          GrenadeHazard(
            fromX: enemy.x,
            fromY: enemy.y - 6,
            toX: player.x,
            toY: player.y,
            duration: 1.2,
            damage: 22 * scale,
            radius: 44,
            fromPlayer: false,
          ),
        );
        _feedback.cue(BattleCue.enemyShot);
      case EnemyKind.armoredCar:
        for (var i = -1; i <= 1; i++) {
          _shootAt(
            enemy,
            player.x,
            player.y,
            speed: 170,
            damage: 11 * scale,
            radius: 3.4,
            spread: 0.10 * i,
            color: const Color(0xFFFFB066),
          );
        }
      case EnemyKind.boss:
        _bossAttack(enemy, scale);
    }
    _feedback.effect(
      EffectKind.muzzle,
      enemy.x,
      enemy.y + 8,
      radius: enemy.isBoss ? 16 : 8,
      duration: 0.1,
    );
  }

  void _shootAt(
    EnemyUnit enemy,
    double targetX,
    double targetY, {
    required double speed,
    required double damage,
    required double radius,
    double spread = 0,
    required Color color,
  }) {
    final base = math.atan2(targetY - enemy.y, targetX - enemy.x) + spread;
    enemyShots.add(
      BattleBullet(
        x: enemy.x + math.cos(base) * (enemy.spec.radius + 4),
        y: enemy.y + math.sin(base) * (enemy.spec.radius + 4),
        vx: math.cos(base) * speed,
        vy: math.sin(base) * speed,
        damage: damage,
        radius: radius,
        fromPlayer: false,
        color: color,
      ),
    );
    _feedback.cue(BattleCue.enemyShot);
  }

  void _updateBoss(EnemyUnit enemy, double dt) {
    if (!enemy.stopped) {
      enemy.y = math.min(enemy.holdY, enemy.y + enemy.spec.speed * dt);
      return;
    }
    enemy.x = 150 + math.sin(enemy.timer * 0.55) * 74;
    enemy.attackTimer -= dt;
    if (enemy.attackTimer > 0) return;
    enemy.attackTimer = 2.1;
    _enemyAttack(enemy);
    enemy.pattern = (enemy.pattern + 1) % 4;
  }

  void _bossAttack(EnemyUnit enemy, double damageScale) {
    switch (enemy.pattern) {
      case 0:
        for (var i = 0; i < 9; i++) {
          final angle = math.pi / 2 - 0.55 + 1.1 * i / 8;
          enemyShots.add(
            BattleBullet(
              x: enemy.x,
              y: enemy.y + 12,
              vx: math.cos(angle) * 128,
              vy: math.sin(angle) * 128,
              damage: 10 * damageScale,
              radius: 3.6,
              fromPlayer: false,
              color: const Color(0xFFFF9A56),
            ),
          );
        }
        _feedback.cue(BattleCue.enemyShot);
      case 1:
        for (var i = -1; i <= 1; i++) {
          _shootAt(
            enemy,
            player.x,
            player.y,
            speed: 176,
            damage: 12 * damageScale,
            radius: 3.6,
            spread: 0.075 * i,
            color: const Color(0xFFFF7043),
          );
        }
      case 2:
        for (var i = -1; i <= 1; i += 2) {
          _addEnemy(
            EnemyKind.infantry,
            x: enemy.x + i * 34,
            y: enemy.y + 18,
            holdY: 0,
            hpFactor: 0.8,
          );
        }
        _feedback.cue(BattleCue.enemyShot);
      case 3:
        _shootAt(
          enemy,
          player.x,
          player.y,
          speed: 138,
          damage: 22 * damageScale,
          radius: 6,
          color: const Color(0xFFFF5A3C),
        );
    }
  }

  void _resolveContact(EnemyUnit enemy) {
    if (enemy.spawnGuard > 0 || enemy.dead) return;
    final limit = enemy.spec.radius + kPlayerRadius;
    if (!circleOverlap(enemy.x, enemy.y, player.x, player.y, limit)) return;
    _damagePlayer(enemy.spec.contactDamage * difficulty.damageScale);
    if (enemy.kind == EnemyKind.infantry) {
      enemy.hp = 0;
      enemy.dead = true;
    }
  }

  void _updateBullets(double dt) {
    var write = 0;
    for (final bullet in playerShots) {
      bullet.prevX = bullet.x;
      bullet.prevY = bullet.y;
      bullet.x += bullet.vx * dt;
      bullet.y += bullet.vy * dt;
      if (bullet.y < -16 || bullet.x < -12 || bullet.x > Field.width + 12) {
        continue;
      }
      playerShots[write++] = bullet;
    }
    if (write != playerShots.length) playerShots.length = write;

    write = 0;
    for (final bullet in enemyShots) {
      bullet.prevX = bullet.x;
      bullet.prevY = bullet.y;
      bullet.x += bullet.vx * dt;
      bullet.y += bullet.vy * dt;
      if (bullet.y > Field.height + 16 ||
          bullet.y < -16 ||
          bullet.x < -16 ||
          bullet.x > Field.width + 16) {
        continue;
      }
      enemyShots[write++] = bullet;
    }
    if (write != enemyShots.length) enemyShots.length = write;
  }

  void _updateHazards(double dt) {
    for (final hazard in hazards) {
      hazard.elapsed += dt;
    }
    for (var i = hazards.length - 1; i >= 0; i--) {
      final hazard = hazards[i];
      if (hazard.progress < 1) continue;
      hazards.removeAt(i);
      _explode(hazard);
    }
  }

  void _explode(GrenadeHazard hazard) {
    _feedback.effect(
      EffectKind.explosion,
      hazard.toX,
      hazard.toY,
      radius: hazard.radius,
      duration: 0.5,
    );
    _feedback.burst(hazard.toX, hazard.toY, hazard.radius, 10);
    _feedback.cue(BattleCue.explosion);
    _feedback.kick(hazard.kind == HazardKind.bomb ? 11 : 8);
    // 任何一次落点爆炸都会削掉附近的沙袋。
    _covers.blast(hazard.toX, hazard.toY, hazard.radius, hazard.damage * 0.5);
    if (hazard.fromPlayer) {
      for (final enemy in enemies) {
        if (enemy.dead) continue;
        final limit = hazard.radius + enemy.spec.radius;
        if (circleOverlap(enemy.x, enemy.y, hazard.toX, hazard.toY, limit)) {
          _damageEnemy(enemy, hazard.damage);
        }
      }
    } else if (circleOverlap(
      player.x,
      player.y,
      hazard.toX,
      hazard.toY,
      hazard.radius + kPlayerRadius,
    )) {
      _damagePlayer(hazard.damage);
    }
  }

  void _updatePickups(double dt) {
    var write = 0;
    for (final pickup in pickups) {
      pickup.life -= dt;
      pickup.bob += dt * 2.4;
      if (pickup.life <= 0) continue;
      pickups[write++] = pickup;
    }
    if (write != pickups.length) pickups.length = write;
  }

  /// 工事寿命与受击抖动；挖穿或到期后留下扬起的沙尘。
  void _updateCovers(double dt) {
    _covers.tick(dt, onRuined: _ruinCover);
  }

  void _ruinCover(CoverWall cover) {
    _feedback.effect(
      EffectKind.dust,
      cover.x,
      cover.y,
      radius: 26,
      duration: 0.55,
    );
    _feedback.burst(cover.x, cover.y, 16, 6);
    _feedback.cue(BattleCue.cover);
  }

  void _resolveBulletHits() {
    for (final bullet in playerShots) {
      if (!bullet.fromPlayer) continue;
      for (final enemy in enemies) {
        if (enemy.dead) continue;
        final limit = enemy.spec.radius + bullet.radius;
        if (!segmentHitsCircle(
          bullet.prevX,
          bullet.prevY,
          bullet.x,
          bullet.y,
          enemy.x,
          enemy.y,
          limit,
        )) {
          continue;
        }
        _damageEnemy(enemy, bullet.damage);
        bullet.damage = 0;
        break;
      }
    }
    _dropSpent(playerShots);

    for (final bullet in enemyShots) {
      // 敌军俯射会先撞上沙袋；己方子弹从沙袋上方越过，不受影响。
      if (_absorbByCover(bullet)) continue;
      final limit = kPlayerRadius + bullet.radius;
      if (!segmentHitsCircle(
        bullet.prevX,
        bullet.prevY,
        bullet.x,
        bullet.y,
        player.x,
        player.y,
        limit,
      )) {
        continue;
      }
      if (_damagePlayer(bullet.damage)) bullet.damage = 0;
    }
    _dropSpent(enemyShots);
  }

  /// 原地压缩掉已经命中或被沙袋吸收的子弹，不创建迭代器与闭包。
  void _dropSpent(List<BattleBullet> shots) {
    var write = 0;
    for (final bullet in shots) {
      if (bullet.damage <= 0) continue;
      shots[write++] = bullet;
    }
    if (write != shots.length) shots.length = write;
  }

  bool _absorbByCover(BattleBullet bullet) {
    final cover = _covers.absorb(bullet);
    if (cover == null) return false;
    _feedback.effect(
      EffectKind.dust,
      bullet.x,
      bullet.y,
      radius: 7,
      duration: 0.22,
    );
    bullet.damage = 0;
    return true;
  }

  void _resolvePickupGrab() {
    for (var i = pickups.length - 1; i >= 0; i--) {
      final pickup = pickups[i];
      if (!circleOverlap(pickup.x, pickup.y, player.x, player.y, 16)) continue;
      pickups.removeAt(i);
      _applyPickup(pickup);
    }
  }

  void _applyPickup(PickupItem pickup) {
    _feedback.cue(BattleCue.pickup);
    _feedback.effect(
      EffectKind.pickup,
      pickup.x,
      pickup.y,
      radius: 18,
      duration: 0.35,
    );
    switch (pickup.kind) {
      case PickupKind.medkit:
        player.hp = math.min(kPlayerMaxHp, player.hp + 30);
        _feedback.popup('急救 +30', pickup.x, pickup.y, const Color(0xFF8FD16A));
      case PickupKind.shield:
        player.shieldUntil = time + kPlayerMaxShieldSeconds;
        _feedback.popup('钢盔 6s', pickup.x, pickup.y, const Color(0xFF7FC4E8));
      case PickupKind.ammo:
        final next = _random.nextBool() ? WeaponKind.smg : WeaponKind.shotgun;
        player.weapon = next;
        player.weaponUntil = time + WeaponSpec.specs[next]!.duration;
        _feedback.popup(
          next.label,
          pickup.x,
          pickup.y,
          const Color(0xFFFFD166),
        );
    }
  }

  void _damageEnemy(EnemyUnit enemy, double damage) {
    if (enemy.dead) return;
    enemy.hp -= damage;
    enemy.hitFlash = 1;
    _feedback.effect(
      EffectKind.hit,
      enemy.x,
      enemy.y,
      radius: 7,
      duration: 0.18,
    );
    if (enemy.hp > 0) {
      _feedback.cue(BattleCue.hit);
      return;
    }
    enemy.dead = true;
    _feedback.effect(
      enemy.isBoss ? EffectKind.bossDown : EffectKind.boom,
      enemy.x,
      enemy.y,
      radius: enemy.spec.radius * 2.2,
      duration: enemy.isBoss ? 1.1 : 0.45,
    );
    _feedback.burst(
      enemy.x,
      enemy.y,
      enemy.spec.radius * 1.8,
      enemy.isBoss ? 26 : 8,
    );
    _feedback.cue(BattleCue.explosion);
    _feedback.kick(enemy.isBoss ? 14 : 5);
  }

  bool _damagePlayer(double damage, {bool silent = false}) {
    if (status != BattleStatus.running || damage <= 0) return false;
    if (time < player.invulnerableUntil) return false;
    if (shieldActive) {
      _feedback.effect(
        EffectKind.shieldBreak,
        player.x,
        player.y,
        radius: 22,
        duration: 0.3,
      );
      player.invulnerableUntil = time + 0.35;
      return true;
    }
    // 蹲在工事后面时，擦过沙袋的弹片与直射威力都被削弱。
    if (sheltering) damage *= 1 - kCoverShelterReduction;
    player.hp -= damage;
    player.invulnerableUntil = time + 0.9;
    _feedback.kick(9);
    if (!silent) _feedback.cue(BattleCue.hurt);
    if (player.hp <= 0) {
      player.hp = 0;
      _lose();
    }
    return true;
  }

  void _flushDeadEnemies() {
    for (var i = enemies.length - 1; i >= 0; i--) {
      final enemy = enemies[i];
      if (enemy.dead) {
        enemies.removeAt(i);
        _rewardKill(enemy);
      } else if (enemy.escaped) {
        enemies.removeAt(i);
      }
    }
  }

  void _rewardKill(EnemyUnit enemy) {
    kills++;
    combo++;
    maxCombo = math.max(maxCombo, combo);
    comboTimer = kComboWindow;
    final points = (enemy.spec.score * comboMultiplier).round();
    score += points;
    _feedback.popup('+$points', enemy.x, enemy.y, const Color(0xFFFFD166));
    if (enemy.isBoss) {
      score += 1500;
      _feedback.popup(
        '头目击破 +1500',
        Field.width / 2,
        160,
        const Color(0xFFFFB74D),
      );
    }
    pickups.addAll(
      rollDrops(enemy, playerHpRatio: player.hpRatio, random: _random),
    );
  }

  void _advanceWave() {
    if (!_waves.allSpawned) return;
    if (enemies.isNotEmpty) return;
    if (mode == BattleMode.campaign && wave >= kCampaignWaves) {
      _win();
      return;
    }
    final bonus = 200 * wave;
    score += bonus;
    _feedback.popup(
      '第 $wave 波清除 +$bonus',
      Field.width / 2,
      190,
      const Color(0xFF9AD1A0),
    );
    _beginWave(wave + 1);
  }

  void _win() {
    if (finished) return;
    status = BattleStatus.won;
    score += 3000;
    _feedback.cue(BattleCue.victory);
    _feedback.effect(
      EffectKind.bossDown,
      Field.width / 2,
      180,
      radius: 120,
      duration: 1.2,
    );
  }

  void _lose() {
    if (finished) return;
    status = BattleStatus.lost;
    _feedback.cue(BattleCue.defeat);
    _feedback.effect(
      EffectKind.explosion,
      player.x,
      player.y,
      radius: 46,
      duration: 0.7,
    );
    _feedback.burst(player.x, player.y, 40, 18);
  }

  /// 玩家位移（触屏拖动或键盘方向），自动限制在战场下半段。
  void movePlayer(double dx, double dy) {
    if (status != BattleStatus.running) return;
    player.x = (player.x + dx).clamp(
      Field.playerMarginX,
      Field.width - Field.playerMarginX,
    );
    player.y = (player.y + dy).clamp(Field.playerMinY, Field.playerMaxY);
  }

  /// 投掷手雷：朝最近的敌军飞去，没有敌军时落在正前方。
  bool throwGrenade() {
    if (status != BattleStatus.running) return false;
    if (time < player.grenadeReadyAt) return false;
    player.grenadeReadyAt = time + kGrenadeCooldown;
    final target = nearestEnemy(enemies, player.x, player.y);
    final targetX = target?.x ?? player.x;
    final targetY = target?.y ?? player.y - 110;
    hazards.add(
      GrenadeHazard(
        fromX: player.x,
        fromY: player.y - 8,
        toX: targetX,
        toY: targetY,
        duration: 0.72,
        damage: kGrenadeDamage,
        radius: kGrenadeRadius,
        fromPlayer: true,
      ),
    );
    _feedback.cue(BattleCue.enemyShot);
    return true;
  }

  /// 布置沙袋工事：堆在身前 56 单位处，冷却与数量都有上限。
  bool deployCover() {
    if (status != BattleStatus.running) return false;
    if (time < player.coverReadyAt) return false;
    if (_covers.count >= CoverField.limit) return false;
    final x = player.x
        .clamp(kCoverHalfWidth + 12, Field.width - kCoverHalfWidth - 12)
        .toDouble();
    final y = player.y - 56;
    if (!_covers.place(CoverWall(x: x, y: y))) return false;
    player.coverReadyAt = time + kCoverCooldown;
    _feedback.effect(EffectKind.dust, x, y, radius: 20, duration: 0.4);
    _feedback.cue(BattleCue.cover);
    return true;
  }

  /// 呼叫空袭：以敌军最密集处为中心投下三枚炸弹，落点先有预警。
  bool callAirstrike() {
    if (status != BattleStatus.running) return false;
    if (time < player.airstrikeReadyAt) return false;
    player.airstrikeReadyAt = time + kAirstrikeCooldown;
    hazards.addAll(planAirstrike(enemies));
    _feedback.effect(EffectKind.plane, 0, 44, radius: 0, duration: 1.6);
    _feedback.cue(BattleCue.airstrike);
    return true;
  }

  /// 一局的战果，供结算与战绩记录使用。
  BattleResult get result => BattleResult(
    mode: mode,
    difficulty: difficulty,
    scene: scene,
    won: status == BattleStatus.won,
    score: score,
    kills: kills,
    wave: wave,
    maxCombo: maxCombo,
    seconds: time,
  );
}

/// 一局战斗的结算数据。
class BattleResult {
  const BattleResult({
    required this.mode,
    required this.difficulty,
    this.scene = BattleScene.zhabei,
    required this.won,
    required this.score,
    required this.kills,
    required this.wave,
    required this.maxCombo,
    required this.seconds,
  });

  final BattleMode mode;
  final Difficulty difficulty;
  final BattleScene scene;
  final bool won;
  final int score;
  final int kills;
  final int wave;
  final int maxCombo;
  final double seconds;
}

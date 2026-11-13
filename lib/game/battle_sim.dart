import 'dart:math' as math;
import 'dart:ui' show Color;

import '../utils/constants.dart';
import 'battle_config.dart';
import 'entities.dart';
import 'wave_plan.dart';

/// 战场模拟：纯 Dart 的固定步长逻辑，不依赖 Flutter 渲染与平台能力。
///
/// 渲染层只读取实体列表，输入通过 [movePlayer] / [throwGrenade] 进入，
/// 声音等反馈以 [cues] 队列交给控制器。这样逻辑可以在测试里直接推进。
class BattleSim {
  BattleSim({
    required this.mode,
    required this.difficulty,
    math.Random? random,
  }) : _random = random ?? math.Random() {
    player = PlayerSoldier(x: Field.width / 2, y: Field.playerStartY);
  }

  final BattleMode mode;
  final Difficulty difficulty;
  final math.Random _random;

  late PlayerSoldier player;

  BattleStatus status = BattleStatus.ready;
  double time = 0;
  int score = 0;
  int kills = 0;
  int combo = 0;
  int maxCombo = 0;
  double comboTimer = 0;
  double shake = 0;

  int wave = 0;
  double waveBreak = 0;

  final List<EnemyUnit> enemies = [];
  final List<BattleBullet> playerShots = [];
  final List<BattleBullet> enemyShots = [];
  final List<GrenadeHazard> hazards = [];
  final List<PickupItem> pickups = [];
  final List<BattleEffect> effects = [];
  final List<ScorePopup> popups = [];
  final List<Particle> particles = [];

  /// 待消费的播放提示，控制器取走后清空。
  final List<BattleCue> cues = [];

  WavePlan? _plan;
  List<SpawnOrder> _queue = const [];
  int _nextSpawn = 0;
  double _spawnBase = 0;
  double _announceTimer = 0;

  bool get running => status == BattleStatus.running;
  bool get finished => status == BattleStatus.won || status == BattleStatus.lost;

  /// 战役模式的总波数，无尽模式返回 0。
  int get waveCount => mode == BattleMode.campaign ? kCampaignWaves : 0;

  bool get bossActive => enemies.any((enemy) => enemy.isBoss);
  EnemyUnit? get boss {
    for (final enemy in enemies) {
      if (enemy.isBoss) return enemy;
    }
    return null;
  }

  /// 尚未清完的敌军数量（含还没进场的）。
  int get remainingEnemies => enemies.length + (_queue.length - _nextSpawn);

  bool get bossWarning => _plan?.boss == true && waveBreak > 0;

  bool get announcing => _announceTimer > 0;

  /// 波次开始时的大字提示。
  String get announcement {
    final plan = _plan;
    if (plan == null) return '';
    if (plan.boss) return '警告 · 敌军头目接近';
    return '第 $wave 波 · 敌军逼近';
  }

  /// 战况条的一行短语，波次由独立的标签展示。
  String get brief {
    if (status == BattleStatus.won) return '阵地守住了';
    if (status == BattleStatus.lost) return '阵地失守';
    if (status == BattleStatus.paused) return '已暂停';
    if (status == BattleStatus.ready) return '准备战斗';
    if (waveBreak > 0) {
      return _plan?.boss == true ? '头目正在逼近' : '敌军集结中';
    }
    if (bossActive) return '头目战 · 剩余 $remainingEnemies';
    return '剩余敌军 $remainingEnemies';
  }

  double get comboMultiplier {
    final tier = math.min(combo ~/ kComboStep, 8);
    return math.min(1 + tier * kComboStepBonus, kMaxComboMultiplier);
  }

  double get grenadeCooldownLeft =>
      math.max(0, player.grenadeReadyAt - time);

  double get weaponSecondsLeft =>
      player.weapon == WeaponKind.pistol
      ? 0
      : math.max(0, player.weaponUntil - time);

  bool get shieldActive => time < player.shieldUntil;

  /// 开始一波新的战斗。
  void start() {
    if (status != BattleStatus.ready) return;
    status = BattleStatus.running;
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
    shake = 0;
    wave = 0;
    waveBreak = 0;
    enemies.clear();
    playerShots.clear();
    enemyShots.clear();
    hazards.clear();
    pickups.clear();
    effects.clear();
    popups.clear();
    particles.clear();
    cues.clear();
    _queue = const [];
    _nextSpawn = 0;
    _plan = null;
    _announceTimer = 0;
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

    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) combo = 0;
    }

    if (waveBreak > 0) {
      waveBreak -= dt;
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
    for (final effect in effects) {
      effect.age += dt;
    }
    effects.removeWhere((effect) => effect.done);
    for (final popup in popups) {
      popup.age += dt;
    }
    popups.removeWhere((popup) => popup.done);
    for (final particle in particles) {
      particle.life -= dt;
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.vx *= 0.98;
      particle.vy += 42 * dt;
    }
    particles.removeWhere((particle) => particle.life <= 0);
    if (_announceTimer > 0) _announceTimer -= dt;
  }

  void _updatePlayer(double dt) {
    final spec = WeaponSpec.specs[player.weapon]!;
    player.muzzle = math.max(0, player.muzzle - dt);
    if (player.weapon != WeaponKind.pistol && time >= player.weaponUntil) {
      player.weapon = WeaponKind.pistol;
      _popup('弹药耗尽', player.x, player.y - 20, const Color(0xFFBFC7C9));
    }
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
    effects.add(
      BattleEffect(
        kind: EffectKind.muzzle,
        x: player.x,
        y: player.y - 14,
        radius: 8,
        duration: 0.08,
      ),
    );
    cues.add(BattleCue.shot);
    shake = math.max(shake, 1.2);
  }

  void _beginWave(int index) {
    wave = index;
    _plan = mode == BattleMode.campaign
        ? campaignWaves(difficulty)[index - 1]
        : endlessWave(index, difficulty, random: _random);
    _queue = List.of(_plan!.orders)
      ..sort((a, b) => a.at.compareTo(b.at));
    _nextSpawn = 0;
    waveBreak = _plan!.boss ? 2.4 : 1.5;
    _spawnBase = time + waveBreak;
    _announceTimer = waveBreak;
    cues.add(_plan!.boss ? BattleCue.boss : BattleCue.wave);
  }

  void _spawnDue() {
    final plan = _plan;
    if (plan == null) return;
    final elapsed = time - _spawnBase;
    while (_nextSpawn < _queue.length && _queue[_nextSpawn].at <= elapsed) {
      _spawn(_queue[_nextSpawn]);
      _nextSpawn++;
    }
  }

  void _spawn(SpawnOrder order) {
    final spec = EnemySpec.specs[order.kind]!;
    final hp = spec.hp * difficulty.hpScale * (_plan?.hpMultiplier ?? 1);
    enemies.add(
      EnemyUnit(
        kind: order.kind,
        x: order.x.clamp(24.0, Field.width - 24),
        y: Field.enemyTop,
        hp: hp,
        maxHp: hp,
        holdY: order.holdY,
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
          _marchDown(enemy, dt, sway: 15, swaySpeed: 2.6);
        case EnemyKind.rifleman:
          _holdAndAttack(enemy, dt, interval: 1.5);
        case EnemyKind.grenadier:
          _holdAndAttack(enemy, dt, interval: 2.4);
        case EnemyKind.armoredCar:
          _holdAndAttack(enemy, dt, interval: 2.2, strafe: 46, strafeSpeed: 0.7);
        case EnemyKind.boss:
          _updateBoss(enemy, dt);
      }
      enemy.x = enemy.x.clamp(20.0, Field.width - 20);
      _resolveContact(enemy);
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
    enemy.x += math.sin(enemy.timer * strafeSpeed + enemy.bobSeed) * strafe * dt;
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
        cues.add(BattleCue.enemyShot);
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
    effects.add(
      BattleEffect(
        kind: EffectKind.muzzle,
        x: enemy.x,
        y: enemy.y + 8,
        radius: enemy.isBoss ? 16 : 8,
        duration: 0.1,
      ),
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
    cues.add(BattleCue.enemyShot);
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
        cues.add(BattleCue.enemyShot);
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
          final hp = EnemySpec.specs[EnemyKind.infantry]!.hp *
              difficulty.hpScale *
              (_plan?.hpMultiplier ?? 1) *
              0.8;
          enemies.add(
            EnemyUnit(
              kind: EnemyKind.infantry,
              x: enemy.x + i * 34,
              y: enemy.y + 18,
              hp: hp,
              maxHp: hp,
              holdY: 0,
            )..bobSeed = _random.nextDouble() * math.pi * 2,
          );
        }
        cues.add(BattleCue.enemyShot);
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
    final dx = enemy.x - player.x;
    final dy = enemy.y - player.y;
    final limit = enemy.spec.radius + kPlayerRadius;
    if (dx * dx + dy * dy > limit * limit) return;
    _damagePlayer(enemy.spec.contactDamage * difficulty.damageScale);
    if (enemy.kind == EnemyKind.infantry) {
      enemy.hp = 0;
      enemy.dead = true;
    }
  }

  void _updateBullets(double dt) {
    for (final bullet in playerShots) {
      bullet.prevX = bullet.x;
      bullet.prevY = bullet.y;
      bullet.x += bullet.vx * dt;
      bullet.y += bullet.vy * dt;
    }
    playerShots.removeWhere(
      (bullet) =>
          bullet.y < -16 || bullet.x < -12 || bullet.x > Field.width + 12,
    );
    for (final bullet in enemyShots) {
      bullet.prevX = bullet.x;
      bullet.prevY = bullet.y;
      bullet.x += bullet.vx * dt;
      bullet.y += bullet.vy * dt;
    }
    enemyShots.removeWhere(
      (bullet) =>
          bullet.y > Field.height + 16 ||
          bullet.y < -16 ||
          bullet.x < -16 ||
          bullet.x > Field.width + 16,
    );
  }

  void _updateHazards(double dt) {
    for (final hazard in hazards) {
      hazard.elapsed += dt;
    }
    final exploded = hazards.where((hazard) => hazard.progress >= 1).toList();
    for (final hazard in exploded) {
      hazards.remove(hazard);
      _explode(hazard);
    }
  }

  void _explode(GrenadeHazard hazard) {
    effects.add(
      BattleEffect(
        kind: EffectKind.explosion,
        x: hazard.toX,
        y: hazard.toY,
        radius: hazard.radius,
        duration: 0.5,
      ),
    );
    _spawnParticles(hazard.toX, hazard.toY, hazard.radius, 10);
    cues.add(BattleCue.explosion);
    shake = math.max(shake, 8);
    if (hazard.fromPlayer) {
      for (final enemy in enemies) {
        if (enemy.dead) continue;
        final dx = enemy.x - hazard.toX;
        final dy = enemy.y - hazard.toY;
        final limit = hazard.radius + enemy.spec.radius;
        if (dx * dx + dy * dy <= limit * limit) {
          _damageEnemy(enemy, hazard.damage);
        }
      }
    } else {
      final dx = player.x - hazard.toX;
      final dy = player.y - hazard.toY;
      if (dx * dx + dy * dy <=
          (hazard.radius + kPlayerRadius) * (hazard.radius + kPlayerRadius)) {
        _damagePlayer(hazard.damage);
      }
    }
  }

  void _updatePickups(double dt) {
    for (final pickup in pickups) {
      pickup.life -= dt;
      pickup.bob += dt * 2.4;
    }
    pickups.removeWhere((pickup) => pickup.life <= 0);
  }

  void _resolveBulletHits() {
    for (final bullet in playerShots) {
      if (!bullet.fromPlayer) continue;
      for (final enemy in enemies) {
        if (enemy.dead) continue;
        final limit = enemy.spec.radius + bullet.radius;
        if (!_segmentHitsCircle(
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
    playerShots.removeWhere((bullet) => bullet.damage <= 0);

    for (final bullet in enemyShots) {
      final limit = kPlayerRadius + bullet.radius;
      if (!_segmentHitsCircle(
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
    enemyShots.removeWhere((bullet) => bullet.damage <= 0);
  }

  /// 线段与圆是否相交：用上一位置到当前位置的轨迹判定命中。
  bool _segmentHitsCircle(
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
    final offsetX = cx - px;
    final offsetY = cy - py;
    return offsetX * offsetX + offsetY * offsetY <= radius * radius;
  }

  void _resolvePickupGrab() {
    for (final pickup in pickups.toList()) {
      final dx = pickup.x - player.x;
      final dy = pickup.y - player.y;
      if (dx * dx + dy * dy > 16 * 16) continue;
      pickups.remove(pickup);
      _applyPickup(pickup);
    }
  }

  void _applyPickup(PickupItem pickup) {
    cues.add(BattleCue.pickup);
    effects.add(
      BattleEffect(
        kind: EffectKind.pickup,
        x: pickup.x,
        y: pickup.y,
        radius: 18,
        duration: 0.35,
      ),
    );
    switch (pickup.kind) {
      case PickupKind.medkit:
        player.hp = math.min(kPlayerMaxHp, player.hp + 30);
        _popup('急救 +30', pickup.x, pickup.y, const Color(0xFF8FD16A));
      case PickupKind.shield:
        player.shieldUntil = time + kPlayerMaxShieldSeconds;
        _popup('钢盔 6s', pickup.x, pickup.y, const Color(0xFF7FC4E8));
      case PickupKind.ammo:
        final next = _random.nextBool() ? WeaponKind.smg : WeaponKind.shotgun;
        player.weapon = next;
        player.weaponUntil = time + WeaponSpec.specs[next]!.duration;
        _popup(next.label, pickup.x, pickup.y, const Color(0xFFFFD166));
    }
  }

  void _damageEnemy(EnemyUnit enemy, double damage) {
    if (enemy.dead) return;
    enemy.hp -= damage;
    enemy.hitFlash = 1;
    effects.add(
      BattleEffect(
        kind: EffectKind.hit,
        x: enemy.x,
        y: enemy.y,
        radius: 7,
        duration: 0.18,
      ),
    );
    if (enemy.hp > 0) {
      cues.add(BattleCue.hit);
      return;
    }
    enemy.dead = true;
    effects.add(
      BattleEffect(
        kind: enemy.isBoss ? EffectKind.bossDown : EffectKind.boom,
        x: enemy.x,
        y: enemy.y,
        radius: enemy.spec.radius * 2.2,
        duration: enemy.isBoss ? 1.1 : 0.45,
      ),
    );
    _spawnParticles(enemy.x, enemy.y, enemy.spec.radius * 1.8, enemy.isBoss ? 26 : 8);
    cues.add(BattleCue.explosion);
    shake = math.max(shake, enemy.isBoss ? 14 : 5);
  }

  bool _damagePlayer(double damage, {bool silent = false}) {
    if (status != BattleStatus.running || damage <= 0) return false;
    if (time < player.invulnerableUntil) return false;
    if (shieldActive) {
      effects.add(
        BattleEffect(
          kind: EffectKind.shieldBreak,
          x: player.x,
          y: player.y,
          radius: 22,
          duration: 0.3,
        ),
      );
      player.invulnerableUntil = time + 0.35;
      return true;
    }
    player.hp -= damage;
    player.invulnerableUntil = time + 0.9;
    shake = math.max(shake, 9);
    if (!silent) cues.add(BattleCue.hurt);
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
    _popup('+$points', enemy.x, enemy.y, const Color(0xFFFFD166));
    if (enemy.isBoss) {
      score += 1500;
      _popup('头目击破 +1500', Field.width / 2, 160, const Color(0xFFFFB74D));
    }
    _dropPickup(enemy);
  }

  void _dropPickup(EnemyUnit enemy) {
    // 头目必掉双补给，其余的精英必掉一件，普通敌兵按概率掉落。
    if (enemy.isBoss) {
      pickups.addAll([
        PickupItem(kind: PickupKind.medkit, x: 120, y: 200),
        PickupItem(kind: PickupKind.ammo, x: 180, y: 200),
      ]);
      return;
    }
    final chance = enemy.isElite ? 1.0 : 0.15;
    if (_random.nextDouble() > chance) return;
    pickups.add(
      PickupItem(
        kind: _rollPickupKind(),
        x: enemy.x.clamp(20.0, Field.width - 20),
        y: enemy.y.clamp(60.0, Field.height - 40),
      ),
    );
  }

  PickupKind _rollPickupKind() {
    final roll = _random.nextDouble();
    if (player.hp < kPlayerMaxHp * 0.55) {
      if (roll < 0.55) return PickupKind.medkit;
      if (roll < 0.80) return PickupKind.ammo;
      return PickupKind.shield;
    }
    if (roll < 0.40) return PickupKind.ammo;
    if (roll < 0.75) return PickupKind.shield;
    return PickupKind.medkit;
  }

  void _spawnParticles(double x, double y, double radius, int count) {
    for (var i = 0; i < count; i++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 24 + _random.nextDouble() * radius * 3.2;
      particles.add(
        Particle(
          x: x,
          y: y,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 12,
          life: 0.35 + _random.nextDouble() * 0.45,
          color: _random.nextBool()
              ? const Color(0xFFFFB347)
              : const Color(0xFFFF6B3D),
          size: 1.4 + _random.nextDouble() * 2.2,
        ),
      );
    }
  }

  void _popup(String text, double x, double y, Color color) {
    popups.add(ScorePopup(text: text, x: x, y: y, color: color));
  }

  void _advanceWave() {
    if (_nextSpawn < _queue.length) return;
    if (enemies.isNotEmpty) return;
    if (mode == BattleMode.campaign && wave >= kCampaignWaves) {
      _win();
      return;
    }
    final bonus = 200 * wave;
    score += bonus;
    _popup('第 $wave 波清除 +$bonus', Field.width / 2, 190, const Color(0xFF9AD1A0));
    _beginWave(wave + 1);
  }

  void _win() {
    if (finished) return;
    status = BattleStatus.won;
    score += 3000;
    cues.add(BattleCue.victory);
    effects.add(
      BattleEffect(
        kind: EffectKind.bossDown,
        x: Field.width / 2,
        y: 180,
        radius: 120,
        duration: 1.2,
      ),
    );
  }

  void _lose() {
    if (finished) return;
    status = BattleStatus.lost;
    cues.add(BattleCue.defeat);
    effects.add(
      BattleEffect(
        kind: EffectKind.explosion,
        x: player.x,
        y: player.y,
        radius: 46,
        duration: 0.7,
      ),
    );
    _spawnParticles(player.x, player.y, 40, 18);
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
    var targetX = player.x;
    var targetY = player.y - 110;
    var best = double.infinity;
    for (final enemy in enemies) {
      if (enemy.dead) continue;
      final dx = enemy.x - player.x;
      final dy = enemy.y - player.y;
      final distance = dx * dx + dy * dy;
      if (distance < best) {
        best = distance;
        targetX = enemy.x;
        targetY = enemy.y;
      }
    }
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
    cues.add(BattleCue.enemyShot);
    return true;
  }

  /// 一局的战果，供结算与战绩记录使用。
  BattleResult get result => BattleResult(
    mode: mode,
    difficulty: difficulty,
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
    required this.won,
    required this.score,
    required this.kills,
    required this.wave,
    required this.maxCombo,
    required this.seconds,
  });

  final BattleMode mode;
  final Difficulty difficulty;
  final bool won;
  final int score;
  final int kills;
  final int wave;
  final int maxCombo;
  final double seconds;
}

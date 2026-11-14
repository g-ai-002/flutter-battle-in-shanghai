import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/battle_config.dart';
import '../game/battle_sim.dart';
import '../game/entities.dart';
import '../theme/battle_painting.dart';
import '../theme/paint_kit.dart';
import '../utils/constants.dart';
import 'label_cache.dart';
import 'path_batch.dart';
import 'scene_cache.dart';

/// 战斗层绘制：工事、落点、补给、敌军、守军、弹道与反馈。
///
/// 只读取 [BattleSim] 的状态，不推进逻辑；背景与前景街垒由
/// [BattleScenePainter] 负责，这里专注「会动的东西」。
class BattleCombatPainter {
  BattleCombatPainter({
    required this.sim,
    required this.labels,
    required this.cache,
  });

  final BattleSim sim;
  final BattleLabelCache labels;
  final SceneCache cache;

  /// 敌军按纵向排序用的复用缓冲，避免每帧新建列表。
  final List<EnemyUnit> _sortedEnemies = [];

  /// 弹道与粒子的合批缓冲：一帧内同色几何只留少量 drawPath。
  final PathBatch _batch = PathBatch();

  /// 粒子透明度量化后的颜色，避免每颗碎屑每帧新建一个 Color。
  final Map<int, Color> _tints = {};

  /// 固定的比较器：不必每帧创建闭包。
  static int _byDepth(EnemyUnit a, EnemyUnit b) => a.y.compareTo(b.y);

  double _clock = 0;

  /// 本帧参与合批的组数，测试用来确认绘制调用被压到个位数。
  @visibleForTesting
  int get batchGroups => _batch.groupCount;

  void paint(Canvas canvas, double clock) {
    _clock = clock;
    _paintCovers(canvas);
    _paintHazards(canvas);
    _paintPickups(canvas);

    _sortedEnemies
      ..clear()
      ..addAll(sim.enemies);
    if (_sortedEnemies.length > 1 && !_depthSorted()) {
      _sortedEnemies.sort(_byDepth);
    }
    for (final enemy in _sortedEnemies) {
      _paintEnemy(canvas, enemy);
    }

    _paintPlayer(canvas);
    _paintBullets(canvas);
    _paintEffects(canvas);
    _paintParticles(canvas);
    _paintPopups(canvas);
  }

  /// 敌军大多按推进顺序排在列表里，已有序时跳过排序。
  bool _depthSorted() {
    for (var i = 1; i < _sortedEnemies.length; i++) {
      if (_sortedEnemies[i - 1].y > _sortedEnemies[i].y) return false;
    }
    return true;
  }

  void _paintCovers(Canvas canvas) {
    for (final cover in sim.covers) {
      // 快要塌的工事淡出提示，避免玩家把掩体当永久防线。
      final fade = cover.life < 2 ? (cover.life / 2).clamp(0.0, 1.0) : 1.0;
      // 沙袋本体按磨损档位贴图，血量条与淡出圈仍然逐帧绘制。
      final painted = cache.drawCover(
        canvas,
        Offset(cover.x, cover.y),
        cover.hpRatio,
        _clock,
        cover.shake,
      );
      if (!painted) {
        paintCoverWall(
          canvas,
          Offset(cover.x, cover.y),
          cover.hpRatio,
          _clock,
          cover.shake,
        );
      }
      if (cover.hpRatio < 1) {
        const width = kCoverHalfWidth * 1.7;
        final left = cover.x - width / 2;
        final top = cover.bottom + 3;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, width, 2.6),
            const Radius.circular(1.3),
          ),
          fillPaint(const Color(0xAA160F0A)),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, width * cover.hpRatio, 2.6),
            const Radius.circular(1.3),
          ),
          fillPaint(
            cover.hpRatio > 0.45
                ? const Color(0xFFC6A46A)
                : const Color(0xFFE2604A),
          ),
        );
      }
      if (fade < 1) {
        canvas.drawCircle(
          Offset(cover.x, cover.y),
          kCoverHalfWidth,
          strokePaint(const Color(0x55FFD9A0), 0.8),
        );
      }
    }
  }

  void _paintHazards(Canvas canvas) {
    for (final hazard in sim.hazards) {
      final bomb = hazard.kind == HazardKind.bomb;
      final pulse = 0.4 + 0.4 * math.sin(_clock * 10).abs();
      final color = hazard.fromPlayer
          ? (bomb ? const Color(0xFFFF7043) : const Color(0xFFFFD166))
          : const Color(0xFFFF6B3D);
      // 落点预警圈：炸弹的落点更大、更显眼。
      canvas.drawCircle(
        Offset(hazard.toX, hazard.toY),
        hazard.radius * (0.55 + hazard.progress * 0.45),
        strokePaint(
          color.withValues(alpha: (bomb ? 0.32 : 0.22) + pulse * 0.35),
          bomb ? 1.8 : 1.2,
        ),
      );
      // 影子
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(hazard.toX, hazard.toY),
          width: bomb ? 16 : 12,
          height: bomb ? 8 : 6,
        ),
        fillPaint(const Color(0x55000000)),
      );
      // 手雷走抛物线，航弹从天上垂直落下。
      final center = bomb
          ? Offset(hazard.x, hazard.y)
          : Offset(hazard.x, hazard.y - hazard.lift);
      if (bomb) {
        // 航弹：细长弹体 + 尾翼
        canvas.drawOval(
          Rect.fromCenter(center: center, width: 6, height: 12),
          fillPaint(const Color(0xFF2C2A24)),
        );
        canvas.drawRect(
          Rect.fromLTWH(center.dx - 3.4, center.dy - 8, 6.8, 2.4),
          fillPaint(const Color(0xFF514B3C)),
        );
        canvas.drawCircle(
          Offset(center.dx, center.dy + 5),
          1,
          fillPaint(const Color(0xFFFFC46B)),
        );
      } else {
        canvas.drawCircle(center, 2.6, fillPaint(const Color(0xFF3C3A2C)));
        canvas.drawCircle(
          Offset(center.dx - 0.8, center.dy - 0.8),
          0.9,
          fillPaint(const Color(0xFFB9AF8E)),
        );
      }
    }
  }

  void _paintPickups(Canvas canvas) {
    for (final pickup in sim.pickups) {
      final fade = pickup.life < 1.5
          ? (pickup.life / 1.5).clamp(0.0, 1.0)
          : 1.0;
      paintPickup(
        canvas,
        Offset(pickup.x, pickup.y),
        pickup.kind,
        pickup.bob,
        fade: fade,
      );
    }
  }

  void _paintEnemy(Canvas canvas, EnemyUnit enemy) {
    final flash = enemy.hitFlash.clamp(0.0, 1.0);
    switch (enemy.kind) {
      case EnemyKind.infantry:
      case EnemyKind.rifleman:
      case EnemyKind.grenadier:
      case EnemyKind.raider:
      case EnemyKind.shield:
        final look = enemyLooks[enemy.kind]!;
        paintSoldier(
          canvas,
          Offset(enemy.x, enemy.y),
          radius: enemy.spec.radius,
          uniform: look.uniform,
          helmet: look.helmet,
          accent: look.accent,
          aim: look.aimAtPlayer
              ? math.atan2(sim.player.y - enemy.y, sim.player.x - enemy.x)
              : math.pi / 2,
          walk: enemy.timer * look.walk + enemy.bobSeed,
          flash: flash,
          hostile: true,
          shield: look.shield,
          blade: look.blade,
        );
      case EnemyKind.armoredCar:
        final center = Offset(enemy.x, enemy.y);
        // 车体贴预渲染位图，车灯与白闪仍然逐帧绘制。
        if (!cache.drawArmoredCar(canvas, center, enemy.spec.radius)) {
          paintArmoredCarBody(canvas, center, radius: enemy.spec.radius);
        }
        paintArmoredCarLamp(
          canvas,
          center: center,
          radius: enemy.spec.radius,
          time: _clock,
        );
        paintArmoredCarFlash(
          canvas,
          center: center,
          radius: enemy.spec.radius,
          flash: flash,
        );
      case EnemyKind.boss:
        final center = Offset(enemy.x, enemy.y);
        if (!cache.drawBoss(canvas, center, enemy.spec.radius)) {
          paintBossBody(canvas, center, radius: enemy.spec.radius);
        }
        paintBossBeacon(
          canvas,
          center: center,
          radius: enemy.spec.radius,
          time: _clock,
        );
        paintBossFlash(
          canvas,
          center: center,
          radius: enemy.spec.radius,
          flash: flash,
        );
    }
    if (enemy.isElite) _paintHealthBar(canvas, enemy);
    if (enemy.spawnGuard > 0) {
      canvas.drawCircle(
        Offset(enemy.x, enemy.y),
        enemy.spec.radius + 4,
        strokePaint(const Color(0x66FFD9A0), 0.9),
      );
    }
  }

  void _paintHealthBar(Canvas canvas, EnemyUnit enemy) {
    final width = enemy.spec.radius * 1.8;
    final y = enemy.y - enemy.spec.radius - 8;
    final left = enemy.x - width / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, y, width, 3),
        const Radius.circular(1.5),
      ),
      fillPaint(const Color(0xCC160F0A)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, y, width * enemy.hpRatio, 3),
        const Radius.circular(1.5),
      ),
      fillPaint(
        enemy.isBoss ? const Color(0xFFFF5A3C) : const Color(0xFFFFB347),
      ),
    );
  }

  void _paintPlayer(Canvas canvas) {
    final player = sim.player;
    final blinking = sim.time < player.invulnerableUntil && _clock * 12 % 2 < 1;
    final center = Offset(player.x, player.y);
    paintAimBeam(canvas, Offset(player.x, player.y - 16), 150, 0.8);
    if (sim.shieldActive) {
      canvas.drawCircle(
        center,
        kPlayerRadius + 7 + math.sin(_clock * 5) * 1.2,
        strokePaint(const Color(0xFF7FC4E8).withValues(alpha: 0.55), 1.6),
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.drawCircle(
        Offset.zero,
        kPlayerRadius + 7,
        radialPaint(
          0x40001,
          kPlayerRadius + 7,
          const [Color(0x007FC4E8), Color(0x337FC4E8)],
          const [0, 1],
        ),
      );
      canvas.restore();
    }
    if (!blinking) {
      paintSoldier(
        canvas,
        center,
        radius: kPlayerRadius,
        uniform: const Color(0xFF6F7F5E),
        helmet: const Color(0xFF4A5540),
        accent: const Color(0xFFC2452F),
      );
    }
    if (player.muzzle > 0) {
      paintMuzzle(
        canvas,
        Offset(player.x, player.y - 18),
        10 + player.muzzle * 30,
        player.muzzle / 0.07,
      );
    }
  }

  void _paintBullets(Canvas canvas) {
    // 一屏几十发子弹，同色尾焰合成一条路径，不再逐发设置画笔。
    _batch.begin();
    for (final bullet in sim.enemyShots) {
      final head = Offset(bullet.x, bullet.y);
      _batch.line(
        bullet.trailColor,
        bullet.radius * 2.2,
        Offset(bullet.x - bullet.vx * 0.018, bullet.y - bullet.vy * 0.018),
        head,
      );
      _batch.dot(bullet.color, head, bullet.radius);
    }
    for (final bullet in sim.playerShots) {
      final head = Offset(bullet.x, bullet.y);
      _batch.line(
        bullet.trailColor,
        bullet.radius * 2,
        Offset(bullet.x - bullet.vx * 0.016, bullet.y - bullet.vy * 0.016),
        head,
      );
      _batch.line(
        const Color(0xFFFFF3D0),
        bullet.radius,
        head,
        Offset(bullet.x, bullet.y - 3),
      );
    }
    _batch.flush(canvas);
  }

  void _paintEffects(Canvas canvas) {
    for (final effect in sim.effects) {
      final progress = effect.progress;
      switch (effect.kind) {
        case EffectKind.explosion:
          paintExplosion(
            canvas,
            Offset(effect.x, effect.y),
            effect.radius,
            progress,
          );
        case EffectKind.boom:
        case EffectKind.bossDown:
          paintExplosion(
            canvas,
            Offset(effect.x, effect.y),
            effect.radius,
            progress,
          );
          if (effect.kind == EffectKind.bossDown) {
            canvas.drawCircle(
              Offset(effect.x, effect.y),
              effect.radius * progress,
              strokePaint(
                const Color(0xFFFFD9A0).withValues(alpha: (1 - progress) * 0.5),
                2.4,
              ),
            );
          }
        case EffectKind.hit:
          canvas.drawCircle(
            Offset(effect.x, effect.y),
            effect.radius * (0.5 + progress),
            fillPaint(
              const Color(0xFFFFF0C0).withValues(alpha: (1 - progress) * 0.85),
            ),
          );
        case EffectKind.muzzle:
          paintMuzzle(
            canvas,
            Offset(effect.x, effect.y),
            effect.radius * (1 + progress),
            (1 - progress) * 0.9,
          );
        case EffectKind.pickup:
          canvas.drawCircle(
            Offset(effect.x, effect.y),
            effect.radius * (0.4 + progress * 1.4),
            strokePaint(
              const Color(0xFFFFD166).withValues(alpha: (1 - progress) * 0.5),
              1.4,
            ),
          );
        case EffectKind.shieldBreak:
          canvas.drawCircle(
            Offset(effect.x, effect.y),
            effect.radius * (1 + progress * 0.6),
            strokePaint(
              const Color(0xFF7FC4E8).withValues(alpha: (1 - progress) * 0.8),
              2,
            ),
          );
        case EffectKind.dust:
          canvas.drawCircle(
            Offset(effect.x, effect.y - progress * 6),
            effect.radius * (0.5 + progress * 1.1),
            fillPaint(
              const Color(0xFFC0A87C).withValues(alpha: (1 - progress) * 0.3),
            ),
          );
        case EffectKind.plane:
          paintAirstrikePlane(
            canvas,
            const Size(Field.width, Field.height),
            progress,
          );
      }
    }
  }

  void _paintParticles(Canvas canvas) {
    // 碎屑按「颜色 + 透明度档位」合批：满屏爆炸从上百次圆形绘制降到十几次。
    _batch.begin();
    for (final particle in sim.particles) {
      _batch.dot(
        _tint(particle.color.toARGB32(), particle.ratio),
        Offset(particle.x, particle.y),
        particle.size * particle.ratio,
      );
    }
    _batch.flush(canvas);
    // 夜空余烬：持续上飘，给静止画面一点空气感；颜色同样按档位复用。
    for (var i = 0; i < 10; i++) {
      final seed = i * 37.3;
      final x = (seed * 11) % Field.width;
      final y = Field.height - ((seed * 17 + _clock * 26) % Field.height);
      final twinkle = 0.25 + 0.35 * math.sin(_clock * 2 + i);
      canvas.drawCircle(
        Offset(x, y),
        0.8,
        fillPaint(_tint(0xFFFFA24A, twinkle)),
      );
    }
  }

  /// 把透明度量化到固定档位并缓存颜色：碎屑与余烬每帧都在变淡，
  /// 但档位有限，同一颜色不会每帧新建对象。
  static const int _tintSteps = 16;

  Color _tint(int argb, double alpha) {
    final step = (alpha * _tintSteps).round().clamp(0, _tintSteps);
    final key = argb * 32 + step;
    final cached = _tints[key];
    if (cached != null) return cached;
    if (_tints.length > 256) _tints.clear();
    return _tints[key] = Color(argb).withValues(alpha: step / _tintSteps);
  }

  void _paintPopups(Canvas canvas) {
    for (final popup in sim.popups) {
      final progress = popup.age / ScorePopup.duration;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final color = BattleLabelCache.steady(
        popup.color.withValues(alpha: alpha),
      );
      final painter = labels.painter(
        popup.text,
        10,
        color,
        weight: FontWeight.w700,
        spacing: 0.4,
      );
      painter.paint(
        canvas,
        Offset(popup.x - painter.width / 2, popup.y - 18 - progress * 14),
      );
    }
  }
}

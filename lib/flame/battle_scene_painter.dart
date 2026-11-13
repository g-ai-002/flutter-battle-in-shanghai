import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/battle_config.dart';
import '../game/battle_sim.dart';
import '../game/entities.dart';
import '../theme/battle_painting.dart';
import '../theme/paint_kit.dart';
import '../utils/constants.dart';
import 'scene_cache.dart';

/// 战场场景绘制：只读取模拟状态，把街道、单位、弹道与提示画到 Canvas 上。
///
/// 与 Flame 组件解耦后，绘制逻辑可以在任意 Canvas 上复用，组件只负责
/// 缩放、抖动与生命周期。
class BattleScenePainter {
  BattleScenePainter({required this.sim, SceneCache? cache})
    : _cache = cache ?? SceneCache();

  final BattleSim sim;
  final SceneCache _cache;

  final Map<String, TextPainter> _textPainters = {};

  /// 敌军按纵向排序用的复用缓冲，避免每帧新建列表。
  final List<EnemyUnit> _sortedEnemies = [];

  /// 固定的比较器：不必每帧创建闭包。
  static int _byDepth(EnemyUnit a, EnemyUnit b) => a.y.compareTo(b.y);

  double _clock = 0;

  static const int _maxCachedText = 96;

  /// 浮动文字的透明度按 10 档量化，缓存命中率足够高且肉眼几乎无差别。
  static const int _alphaSteps = 10;

  /// 在第一帧之前预生成静态图层，避免把位图创建放进绘制回调。
  void prepare() => _cache.ensure();

  void paint(Canvas canvas, double clock) {
    _clock = clock;
    _cache.ensure();
    const field = Size(Field.width, Field.height);
    if (_cache.ready) {
      _cache.drawBase(canvas);
      _cache.drawRoofs(canvas, clock);
      // 车道线与碎石逐帧滚动，探照灯与街垒贴预渲染好的位图。
      paintStreetScroll(canvas, field, clock);
      _cache.drawSearchlight(canvas, clock);
      _cache.drawGlow(canvas, Offset(sim.player.x, sim.player.y - 40));
    } else {
      paintStreet(canvas, field, clock);
      _paintAmbientLight(canvas);
    }
    _paintCovers(canvas);
    _paintHazards(canvas);
    _paintPickups(canvas);

    _sortedEnemies
      ..clear()
      ..addAll(sim.enemies);
    if (_sortedEnemies.length > 1) {
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
    if (_cache.ready) {
      _cache.drawBarricade(canvas);
      paintBarricadeEmbers(canvas, field, clock);
    } else {
      paintBarricade(canvas, field, clock);
    }
    _paintAnnouncement(canvas);

    if (_cache.ready) {
      _cache.drawVignette(canvas);
    } else {
      paintVignette(canvas, field);
    }
    final lowHp = 1 - sim.player.hpRatio;
    if (lowHp > 0.55) paintDamageWash(canvas, field, (lowHp - 0.55) / 0.45);
  }

  void dispose() {
    for (final painter in _textPainters.values) {
      painter.dispose();
    }
    _textPainters.clear();
    _cache.dispose();
  }

  /// 缓存不可用时的回退：直接画径向渐变环境光。
  void _paintAmbientLight(Canvas canvas) {
    final center = Offset(sim.player.x, sim.player.y - 40);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    paintPlayerGlow(canvas, SceneCache.glowRadius);
    canvas.restore();
  }

  void _paintCovers(Canvas canvas) {
    for (final cover in sim.covers) {
      // 快要塌的工事淡出提示，避免玩家把掩体当永久防线。
      final fade = cover.life < 2 ? (cover.life / 2).clamp(0.0, 1.0) : 1.0;
      // 沙袋本体按磨损档位贴图，血量条与淡出圈仍然逐帧绘制。
      final painted = _cache.drawCover(
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
        paintSoldier(
          canvas,
          Offset(enemy.x, enemy.y),
          radius: enemy.spec.radius,
          uniform: const Color(0xFF595142),
          helmet: const Color(0xFF403A30),
          aim: math.pi / 2,
          walk: enemy.timer * 7 + enemy.bobSeed,
          flash: flash,
          hostile: true,
        );
      case EnemyKind.rifleman:
        paintSoldier(
          canvas,
          Offset(enemy.x, enemy.y),
          radius: enemy.spec.radius,
          uniform: const Color(0xFF4C473C),
          helmet: const Color(0xFF363229),
          accent: const Color(0xFF7A2A20),
          aim: math.atan2(sim.player.y - enemy.y, sim.player.x - enemy.x),
          walk: enemy.timer * 2,
          flash: flash,
          hostile: true,
        );
      case EnemyKind.grenadier:
        paintSoldier(
          canvas,
          Offset(enemy.x, enemy.y),
          radius: enemy.spec.radius,
          uniform: const Color(0xFF5C543D),
          helmet: const Color(0xFF453E30),
          accent: const Color(0xFF9C5A2A),
          aim: math.atan2(sim.player.y - enemy.y, sim.player.x - enemy.x),
          walk: enemy.timer * 2.4,
          flash: flash,
          hostile: true,
        );
      case EnemyKind.armoredCar:
        paintArmoredCar(
          canvas,
          Offset(enemy.x, enemy.y),
          radius: enemy.spec.radius,
          flash: flash,
          time: _clock,
        );
      case EnemyKind.boss:
        paintBoss(
          canvas,
          Offset(enemy.x, enemy.y),
          radius: enemy.spec.radius,
          flash: flash,
          time: _clock,
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
    for (final bullet in sim.enemyShots) {
      final tail = Offset(
        bullet.x - bullet.vx * 0.018,
        bullet.y - bullet.vy * 0.018,
      );
      canvas.drawLine(
        tail,
        Offset(bullet.x, bullet.y),
        strokePaint(
          bullet.trailColor,
          bullet.radius * 2.2,
          cap: StrokeCap.round,
        ),
      );
      canvas.drawCircle(
        Offset(bullet.x, bullet.y),
        bullet.radius,
        fillPaint(bullet.color),
      );
    }
    for (final bullet in sim.playerShots) {
      final tail = Offset(
        bullet.x - bullet.vx * 0.016,
        bullet.y - bullet.vy * 0.016,
      );
      canvas.drawLine(
        tail,
        Offset(bullet.x, bullet.y),
        strokePaint(
          bullet.trailColor,
          bullet.radius * 2,
          cap: StrokeCap.round,
        ),
      );
      canvas.drawLine(
        Offset(bullet.x, bullet.y),
        Offset(bullet.x, bullet.y - 3),
        strokePaint(
          const Color(0xFFFFF3D0),
          bullet.radius,
          cap: StrokeCap.round,
        ),
      );
    }
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
    for (final particle in sim.particles) {
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size * particle.ratio,
        fillPaint(particle.color.withValues(alpha: particle.ratio)),
      );
    }
    // 夜空余烬：持续上飘，给静止画面一点空气感。
    for (var i = 0; i < 10; i++) {
      final seed = i * 37.3;
      final x = (seed * 11) % Field.width;
      final y = Field.height - ((seed * 17 + _clock * 26) % Field.height);
      final twinkle = 0.25 + 0.35 * math.sin(_clock * 2 + i);
      canvas.drawCircle(
        Offset(x, y),
        0.8,
        fillPaint(const Color(0xFFFFA24A).withValues(alpha: twinkle)),
      );
    }
  }

  void _paintPopups(Canvas canvas) {
    for (final popup in sim.popups) {
      final progress = popup.age / ScorePopup.duration;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final color = _steadyColor(popup.color.withValues(alpha: alpha));
      final painter = _painter(
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

  void _paintAnnouncement(Canvas canvas) {
    if (!sim.announcing) return;
    final text = sim.announcement;
    if (text.isEmpty) return;
    final progress = sim.waveBreakRatio;
    final alpha = (progress * 1.4).clamp(0.0, 1.0);
    final color = _steadyColor(
      (sim.bossWarning ? const Color(0xFFFF7A52) : const Color(0xFFF6E4C6))
          .withValues(alpha: alpha),
    );
    final painter = _painter(
      text,
      19,
      color,
      weight: FontWeight.w700,
      spacing: 2.2,
    );
    painter.paint(canvas, Offset((Field.width - painter.width) / 2, 128));
    if (sim.bossWarning) {
      final sub = _painter(
        '坚守阵地 · 集中火力',
        9,
        color.withValues(alpha: color.a * 0.8),
        weight: FontWeight.w500,
        spacing: 2.4,
      );
      sub.paint(canvas, Offset((Field.width - sub.width) / 2, 154));
    }
  }

  /// 把透明度量化到固定档位，缓存 key 不再逐帧变化。
  Color _steadyColor(Color color) =>
      color.withValues(alpha: (color.a * _alphaSteps).round() / _alphaSteps);

  /// 文本按内容与样式缓存，最近使用保留，超限淘汰最旧的一条。
  TextPainter _painter(
    String text,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w600,
    double spacing = 0,
  }) {
    final key = '$text|$size|${color.toARGB32()}|${weight.value}|$spacing';
    final cached = _textPainters.remove(key);
    if (cached != null) {
      _textPainters[key] = cached;
      return cached;
    }
    if (_textPainters.length >= _maxCachedText) {
      final oldest = _textPainters.keys.first;
      _textPainters.remove(oldest)?.dispose();
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: battlefieldLabelStyle(
          fontSize: size,
          color: color,
          weight: weight,
          letterSpacing: spacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _textPainters[key] = painter;
    return painter;
  }
}

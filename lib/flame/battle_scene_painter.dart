import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/battle_config.dart';
import '../game/battle_sim.dart';
import '../game/entities.dart';
import '../theme/battle_painting.dart';
import '../utils/constants.dart';

/// 战场场景绘制：只读取模拟状态，把街道、单位、弹道与提示画到 Canvas 上。
///
/// 与 Flame 组件解耦后，绘制逻辑可以在任意 Canvas 上复用，组件只负责
/// 缩放、抖动与生命周期。
class BattleScenePainter {
  BattleScenePainter({required this.sim});

  final BattleSim sim;

  final Map<String, TextPainter> _textPainters = {};
  double _clock = 0;

  void paint(Canvas canvas, double clock) {
    _clock = clock;
    const field = Size(Field.width, Field.height);
    paintStreet(canvas, field, clock);
    _paintAmbientLight(canvas);
    _paintHazards(canvas);
    _paintPickups(canvas);

    final enemies = List<EnemyUnit>.of(sim.enemies)
      ..sort((a, b) => a.y.compareTo(b.y));
    for (final enemy in enemies) {
      _paintEnemy(canvas, enemy);
    }

    _paintPlayer(canvas);
    _paintBullets(canvas);
    _paintEffects(canvas);
    _paintParticles(canvas);
    _paintPopups(canvas);
    paintBarricade(canvas, field, clock);
    _paintAnnouncement(canvas);

    paintVignette(canvas, field);
    final lowHp = 1 - sim.player.hpRatio;
    if (lowHp > 0.55) paintDamageWash(canvas, field, (lowHp - 0.55) / 0.45);
  }

  void dispose() {
    for (final painter in _textPainters.values) {
      painter.dispose();
    }
    _textPainters.clear();
  }

  /// 玩家周围的暖色环境光：夜里也能把视线收拢到守军附近。
  void _paintAmbientLight(Canvas canvas) {
    final center = Offset(sim.player.x, sim.player.y - 40);
    canvas.drawCircle(
      center,
      138,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          138,
          [const Color(0x1FFFD9A0), const Color(0x00FFD9A0)],
        ),
    );
  }

  void _paintHazards(Canvas canvas) {
    for (final hazard in sim.hazards) {
      final pulse = 0.4 + 0.4 * math.sin(_clock * 10).abs();
      final color = hazard.fromPlayer
          ? const Color(0xFFFFD166)
          : const Color(0xFFFF6B3D);
      // 落点预警圈
      canvas.drawCircle(
        Offset(hazard.toX, hazard.toY),
        hazard.radius * (0.55 + hazard.progress * 0.45),
        Paint()
          ..color = color.withValues(alpha: 0.22 + pulse * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      // 影子
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(hazard.toX, hazard.toY),
          width: 12,
          height: 6,
        ),
        Paint()..color = const Color(0x55000000),
      );
      // 飞行中的手雷
      final center = Offset(hazard.x, hazard.y - hazard.lift);
      canvas.drawCircle(
        center,
        2.6,
        Paint()..color = const Color(0xFF3C3A2C),
      );
      canvas.drawCircle(
        Offset(center.dx - 0.8, center.dy - 0.8),
        0.9,
        Paint()..color = const Color(0xFFB9AF8E),
      );
    }
  }

  void _paintPickups(Canvas canvas) {
    for (final pickup in sim.pickups) {
      final fade = pickup.life < 1.5 ? (pickup.life / 1.5).clamp(0.0, 1.0) : 1.0;
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
          aim: math.atan2(
            sim.player.y - enemy.y,
            sim.player.x - enemy.x,
          ),
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
          aim: math.atan2(
            sim.player.y - enemy.y,
            sim.player.x - enemy.x,
          ),
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
        Paint()
          ..color = const Color(0x66FFD9A0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
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
      Paint()..color = const Color(0xCC160F0A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, y, width * enemy.hpRatio, 3),
        const Radius.circular(1.5),
      ),
      Paint()
        ..color = enemy.isBoss
            ? const Color(0xFFFF5A3C)
            : const Color(0xFFFFB347),
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
        Paint()
          ..color = const Color(0xFF7FC4E8).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      canvas.drawCircle(
        center,
        kPlayerRadius + 7,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            kPlayerRadius + 7,
            [const Color(0x007FC4E8), const Color(0x337FC4E8)],
          ),
      );
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
        Paint()
          ..color = bullet.color.withValues(alpha: 0.35)
          ..strokeWidth = bullet.radius * 2.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(bullet.x, bullet.y),
        bullet.radius,
        Paint()..color = bullet.color,
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
        Paint()
          ..color = bullet.color.withValues(alpha: 0.4)
          ..strokeWidth = bullet.radius * 2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(bullet.x, bullet.y),
        Offset(bullet.x, bullet.y - 3),
        Paint()
          ..color = const Color(0xFFFFF3D0)
          ..strokeWidth = bullet.radius
          ..strokeCap = StrokeCap.round,
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
              Paint()
                ..color = const Color(0xFFFFD9A0)
                    .withValues(alpha: (1 - progress) * 0.5)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.4,
            );
          }
        case EffectKind.hit:
          canvas.drawCircle(
            Offset(effect.x, effect.y),
            effect.radius * (0.5 + progress),
            Paint()
              ..color = const Color(0xFFFFF0C0)
                  .withValues(alpha: (1 - progress) * 0.85),
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
            Paint()
              ..color = const Color(0xFFFFD166)
                  .withValues(alpha: (1 - progress) * 0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4,
          );
        case EffectKind.shieldBreak:
          canvas.drawCircle(
            Offset(effect.x, effect.y),
            effect.radius * (1 + progress * 0.6),
            Paint()
              ..color = const Color(0xFF7FC4E8)
                  .withValues(alpha: (1 - progress) * 0.8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
      }
    }
  }

  void _paintParticles(Canvas canvas) {
    for (final particle in sim.particles) {
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        particle.size * particle.ratio,
        Paint()..color = particle.color.withValues(alpha: particle.ratio),
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
        Paint()..color = const Color(0xFFFFA24A).withValues(alpha: twinkle),
      );
    }
  }

  void _paintPopups(Canvas canvas) {
    for (final popup in sim.popups) {
      final progress = popup.age / ScorePopup.duration;
      final alpha = (1 - progress).clamp(0.0, 1.0);
      final painter = _painter(
        popup.text,
        10,
        popup.color.withValues(alpha: alpha),
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
    final color = sim.bossWarning
        ? const Color(0xFFFF7A52)
        : const Color(0xFFF6E4C6);
    final painter = _painter(
      text,
      19,
      color.withValues(alpha: alpha),
      weight: FontWeight.w700,
      spacing: 2.2,
    );
    painter.paint(
      canvas,
      Offset((Field.width - painter.width) / 2, 128),
    );
    if (sim.bossWarning) {
      final sub = _painter(
        '坚守阵地 · 集中火力',
        9,
        color.withValues(alpha: alpha * 0.8),
        weight: FontWeight.w500,
        spacing: 2.4,
      );
      sub.paint(canvas, Offset((Field.width - sub.width) / 2, 154));
    }
  }

  /// 文本按内容与样式缓存，避免每帧重新排版。
  TextPainter _painter(
    String text,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w600,
    double spacing = 0,
  }) {
    final key = '$text|$size|${color.toARGB32()}|${weight.value}|$spacing';
    // 浮动分数会不断产生新文本，缓存超过上限时整体清空，避免无界增长。
    if (_textPainters.length > 64) dispose();
    return _textPainters.putIfAbsent(key, () {
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
      return painter;
    });
  }
}

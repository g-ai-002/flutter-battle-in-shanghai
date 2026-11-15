import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../game/battle_sim.dart';
import '../theme/battle_painting.dart';
import '../utils/constants.dart';
import 'battle_combat_painter.dart';
import 'label_cache.dart';
import 'scene_cache.dart';

/// 战场场景绘制：只读取模拟状态，把街景、单位、弹道与提示画到 Canvas 上。
///
/// 背景与前景街垒在这里合成，会动的单位与反馈交给 [BattleCombatPainter]；
/// 与 Flame 组件解耦后，绘制逻辑可以在任意 Canvas 上复用，组件只负责
/// 缩放、抖动与生命周期。
class BattleScenePainter {
  BattleScenePainter({required this.sim, SceneCache? cache})
    : _cache = cache ?? SceneCache.shared(sim.scene),
      _sharedCache = cache == null {
    _combat = BattleCombatPainter(sim: sim, labels: _labels, cache: _cache);
  }

  final BattleSim sim;
  final SceneCache _cache;
  final bool _sharedCache;
  final BattleLabelCache _labels = BattleLabelCache();
  late final BattleCombatPainter _combat;

  static const Size _field = Size(Field.width, Field.height);

  /// 在第一帧之前预生成静态图层与渐变，避免把位图与 shader 创建放进战斗帧。
  void prepare() {
    _cache.ensure();
    prewarmExplosionPaints();
    // 低血量警示的十档渐变也提前建好，残血时不会突然卡一帧。
    final recorder = ui.PictureRecorder();
    final probe = Canvas(recorder);
    for (var step = 1; step <= 10; step++) {
      paintDamageWash(probe, _field, step / 10);
    }
    recorder.endRecording().dispose();
  }

  void paint(Canvas canvas, double clock) {
    _cache.ensure();
    _paintBackground(canvas, clock);
    _combat.paint(canvas, clock);
    if (_cache.ready) {
      _cache.drawBarricade(canvas);
      paintBarricadeEmbers(canvas, _field, clock, _cache.palette);
    } else {
      paintBarricade(canvas, _field, clock, _cache.palette);
    }
    _paintAnnouncement(canvas);

    if (_cache.ready) {
      _cache.drawVignette(canvas);
    } else {
      paintVignette(canvas, _field);
    }
    final lowHp = 1 - sim.player.hpRatio;
    if (lowHp > 0.55) paintDamageWash(canvas, _field, (lowHp - 0.55) / 0.45);
  }

  void dispose() {
    _labels.dispose();
    if (!_sharedCache) _cache.dispose();
  }

  void _paintBackground(Canvas canvas, double clock) {
    if (_cache.ready) {
      _cache.drawBase(canvas);
      _cache.drawRoofs(canvas, clock);
      _cache.drawProps(canvas);
      // 车道线与碎石逐帧滚动，探照灯与街垒贴预渲染好的位图。
      paintStreetScroll(canvas, _field, clock, _cache.palette);
      _cache.drawSearchlight(canvas, clock);
      _cache.drawGlow(canvas, Offset(sim.player.x, sim.player.y - 40));
    } else {
      paintStreet(canvas, _field, clock, _cache.palette);
      paintSceneProps(canvas, _field, sim.scene, _cache.palette);
      _paintAmbientLight(canvas);
    }
  }

  /// 缓存不可用时的回退：直接画径向渐变环境光。
  void _paintAmbientLight(Canvas canvas) {
    final center = Offset(sim.player.x, sim.player.y - 40);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    paintPlayerGlow(canvas, SceneCache.glowRadius, _cache.palette);
    canvas.restore();
  }

  void _paintAnnouncement(Canvas canvas) {
    if (!sim.announcing) return;
    final text = sim.announcement;
    if (text.isEmpty) return;
    final progress = sim.waveBreakRatio;
    final alpha = (progress * 1.4).clamp(0.0, 1.0);
    final color = BattleLabelCache.steady(
      (sim.bossWarning ? const Color(0xFFFF7A52) : const Color(0xFFF6E4C6))
          .withValues(alpha: alpha),
    );
    final painter = _labels.painter(
      text,
      19,
      color,
      weight: FontWeight.w700,
      spacing: 2.2,
    );
    painter.paint(canvas, Offset((Field.width - painter.width) / 2, 128));
    if (sim.bossWarning) {
      final sub = _labels.painter(
        '坚守阵地 · 集中火力',
        9,
        color.withValues(alpha: color.a * 0.8),
        weight: FontWeight.w500,
        spacing: 2.4,
      );
      sub.paint(canvas, Offset((Field.width - sub.width) / 2, 154));
    }
  }
}

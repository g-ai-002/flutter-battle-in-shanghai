import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:battle_in_shanghai/flame/battle_combat_painter.dart';
import 'package:battle_in_shanghai/flame/battle_scene_painter.dart';
import 'package:battle_in_shanghai/flame/label_cache.dart';
import 'package:battle_in_shanghai/flame/scene_cache.dart';
import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:battle_in_shanghai/theme/battle_painting.dart';
import 'package:battle_in_shanghai/theme/paint_kit.dart';
import 'package:battle_in_shanghai/theme/scene_palette.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 只统计绘制调用次数的画布：所有方法经 noSuchMethod 计数后丢弃。
class _CountingCanvas implements Canvas {
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    return null;
  }
}

Future<Uint8List> _render(
  void Function(Canvas canvas) draw, {
  double zoom = 1,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(zoom);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (Field.width * zoom).round(),
    (Field.height * zoom).round(),
  );
  picture.dispose();
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

/// 返回最大通道差与明显不同的像素数。
(int, int) _compare(Uint8List a, Uint8List b) {
  var maxDiff = 0;
  var differing = 0;
  for (var i = 0; i < a.length; i += 4) {
    var pixelDiff = 0;
    for (var c = 0; c < 4; c++) {
      final diff = (a[i + c] - b[i + c]).abs();
      if (diff > pixelDiff) pixelDiff = diff;
    }
    if (pixelDiff > maxDiff) maxDiff = pixelDiff;
    if (pixelDiff > 8) differing++;
  }
  return (maxDiff, differing);
}

/// 旧版逐条绘制滚动街景的实现，作为合批后的像素基准。
void _paintScrollDirect(Canvas canvas, Size size, double time) {
  const palette = ScenePalette.zhabei;
  const dash = 26.0;
  const gap = 30.0;
  final dashShift = (time * 132) % (dash + gap);
  final dashPaint = fillPaint(palette.lane);
  for (var y = -dash - gap + dashShift; y < size.height; y += dash + gap) {
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - 2.4, y, 4.8, dash),
      dashPaint,
    );
  }
  final lanePaint = fillPaint(palette.lane.withValues(alpha: 0.55));
  for (final x in [27.0 + 34, size.width - 27.0 - 34]) {
    for (var y = -40 + dashShift * 0.6; y < size.height; y += 70) {
      canvas.drawRect(Rect.fromLTWH(x, y, 1.6, 22), lanePaint);
    }
  }
  final rubble = fillPaint(palette.rubble);
  for (var i = 0; i < 14; i++) {
    final seed = i * 73.7;
    final baseY = (seed * 13) % size.height;
    final y = (baseY + time * 30) % (size.height + 30) - 15;
    final x = 46 + (seed * 7) % (size.width - 92);
    canvas.drawCircle(Offset(x, y), 1.4 + (seed % 3), rubble);
  }
  final scorch = fillPaint(const Color(0x22000000));
  for (var i = 0; i < 4; i++) {
    final y = ((i * 137.0) + time * 30) % (size.height + 80) - 40;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(70 + i * 55, y), width: 34, height: 18),
      scorch,
    );
  }
}

/// 旧版爆炸：渐变半径跟随火球半径，光环与放射碎屑与新实现相同。
void _paintExplosionDirect(
  Canvas canvas,
  Offset center,
  double radius,
  double progress,
) {
  final ease = 1 - math.pow(1 - progress, 2.4).toDouble();
  final alpha = (1 - progress).clamp(0.0, 1.0);
  final r = radius * (0.35 + ease * 0.95);
  final alphaStep = (alpha * kExplosionAlphaSteps).round();
  final alphaValue = alphaStep / kExplosionAlphaSteps;
  final core = Paint()
    ..shader = ui.Gradient.radial(Offset.zero, r, [
      Color.fromRGBO(255, 226, 168, alphaValue * 0.95),
      Color.fromRGBO(255, 138, 61, alphaValue * 0.7),
      Color.fromRGBO(194, 69, 47, alphaValue * 0.25),
      const Color(0x00C2452F),
    ], const [0, 0.35, 0.72, 1]);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.drawCircle(Offset.zero, r, core);
  canvas.drawCircle(
    Offset.zero,
    r * (0.9 + progress * 0.4),
    strokePaint(const Color(0xFFFFD9A0).withValues(alpha: alpha * 0.35), 1.6),
  );
  final ray = strokePaint(
    const Color(0xFFFFC46B).withValues(alpha: alpha * 0.7),
    1.4,
  )..strokeCap = StrokeCap.round;
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4 + progress * 0.6;
    final inner = r * 0.35;
    final outer = r * (1.05 + (i.isEven ? 0.35 : 0.15));
    canvas.drawLine(
      Offset(math.cos(angle) * inner, math.sin(angle) * inner),
      Offset(math.cos(angle) * outer, math.sin(angle) * outer),
      ray,
    );
  }
  canvas.restore();
}

BattleSim _busySim() {
  final sim = BattleSim(
    mode: BattleMode.campaign,
    difficulty: Difficulty.veteran,
  )..start();
  for (var i = 0; i < 12; i++) {
    sim.enemies.add(
      EnemyUnit(
        kind: i.isEven ? EnemyKind.infantry : EnemyKind.rifleman,
        x: 30.0 + i * 20,
        y: 110.0 + i * 16,
        hp: 30,
        maxHp: 30,
        holdY: 160,
      ),
    );
  }
  sim.enemies.add(
    EnemyUnit(
      kind: EnemyKind.armoredCar,
      x: 90,
      y: 120,
      hp: 320,
      maxHp: 320,
      holdY: 120,
    ),
  );
  sim.enemies.add(
    EnemyUnit(
      kind: EnemyKind.boss,
      x: 150,
      y: 80,
      hp: 900,
      maxHp: 900,
      holdY: 80,
    ),
  );
  for (var i = 0; i < 20; i++) {
    sim.playerShots.add(
      BattleBullet(
        x: 20.0 + i * 13,
        y: 200.0 + i * 9,
        vx: 0,
        vy: -520,
        damage: 10,
        radius: 2.4,
        fromPlayer: true,
        color: const Color(0xFFFFE1A1),
      ),
    );
    sim.enemyShots.add(
      BattleBullet(
        x: 30.0 + i * 11,
        y: 150.0 + i * 7,
        vx: 0,
        vy: 152,
        damage: 10,
        radius: 3,
        fromPlayer: false,
        color: const Color(0xFFFF8A5B),
      ),
    );
  }
  for (var i = 0; i < 120; i++) {
    sim.particles.add(
      Particle(
        x: 20.0 + i,
        y: 120.0 + i * 2,
        life: 0.4,
        color: i.isEven ? const Color(0xFFFFB347) : const Color(0xFFFF6B3D),
        size: 2,
      ),
    );
  }
  return sim;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const field = Size(Field.width, Field.height);

  setUp(resetGradientCache);

  test('滚动街景合批后与逐条绘制逐像素一致', () async {
    for (final time in [0.0, 0.37, 1.2, 3.5, 8.9]) {
      final direct = await _render(
        (canvas) => _paintScrollDirect(canvas, field, time),
        zoom: 2,
      );
      final batched = await _render(
        (canvas) => paintStreetScroll(canvas, field, time),
        zoom: 2,
      );
      final (maxDiff, differing) = _compare(direct, batched);
      // 合批的路径走另一条光栅化分支，只有一像素宽边缘的抗锯齿覆盖率略有差别。
      expect(maxDiff, lessThanOrEqualTo(80), reason: 't=$time');
      expect(differing, lessThan(400), reason: 't=$time');
    }
  });

  test('重装单位贴图与直接绘制逐像素一致', () async {
    final cache = SceneCache()..ensure();
    for (final (draw, radius) in [
      (cache.drawArmoredCar, kArmoredCarArtRadius),
      (cache.drawBoss, kBossArtRadius),
    ]) {
      final direct = await _render(
        (canvas) => radius == kArmoredCarArtRadius
            ? paintArmoredCarBody(
                canvas,
                const Offset(150, 200),
                radius: radius,
              )
            : paintBossBody(canvas, const Offset(150, 200), radius: radius),
        zoom: 2,
      );
      final sprite = await _render(
        (canvas) => draw(canvas, const Offset(150, 200), radius),
        zoom: 2,
      );
      final (maxDiff, differing) = _compare(direct, sprite);
      expect(maxDiff, lessThanOrEqualTo(4), reason: '半径 $radius');
      expect(differing, lessThan(400), reason: '半径 $radius');
    }
    cache.dispose();
  });

  test('爆炸火球归一化渐变与按实际半径建渐变一致', () async {
    for (final progress in [0.1, 0.45, 0.8]) {
      final direct = await _render(
        (canvas) => _paintExplosionDirect(
          canvas,
          const Offset(150, 200),
          44,
          progress,
        ),
      );
      final normalized = await _render(
        (canvas) => paintExplosion(
          canvas,
          const Offset(150, 200),
          44,
          progress,
        ),
      );
      final (maxDiff, differing) = _compare(direct, normalized);
      expect(maxDiff, lessThanOrEqualTo(3), reason: 'progress $progress');
      expect(differing, lessThan(400), reason: 'progress $progress');
    }
  });

  test('一次爆炸动画的渐变数量有上限，重放不再新建', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < 31; i++) {
      paintExplosion(canvas, const Offset(150, 200), 44, i / 30);
    }
    final first = gradientBuildCount;
    expect(first, lessThanOrEqualTo(kExplosionAlphaSteps + 1));
    for (var i = 0; i < 31; i++) {
      paintExplosion(canvas, const Offset(150, 200), 90, i / 30);
    }
    expect(gradientBuildCount, first);
    recorder.endRecording().dispose();
  });

  test('预热后爆炸与残血警示不再新建渐变', () {
    final sim = BattleSim(
      mode: BattleMode.endless,
      difficulty: Difficulty.recruit,
    )..start();
    final painter = BattleScenePainter(sim: sim);
    painter.prepare();
    final warm = gradientBuildCount;
    expect(warm, greaterThanOrEqualTo(kExplosionAlphaSteps + 1));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < 40; i++) {
      paintExplosion(canvas, const Offset(150, 200), 58, i / 40);
      paintDamageWash(canvas, field, (i % 10 + 1) / 10);
    }
    recorder.endRecording().dispose();
    expect(gradientBuildCount, warm);
    painter.dispose();
  });

  test('静态图层数包含两张重装单位精灵且只录一次', () {
    final cache = SceneCache()..ensure();
    expect(SceneCache.layerCount, 14);
    expect(cache.layerBuilds, SceneCache.layerCount);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < 30; i++) {
      expect(cache.drawArmoredCar(canvas, const Offset(90, 200), 20), isTrue);
      expect(cache.drawBoss(canvas, const Offset(150, 160), 30), isTrue);
    }
    recorder.endRecording().dispose();
    expect(cache.layerBuilds, SceneCache.layerCount);
    cache.dispose();
  });

  test('弹道与碎屑合批后组数远少于实体数', () {
    final sim = _busySim();
    final cache = SceneCache()..ensure();
    final painter = BattleCombatPainter(
      sim: sim,
      labels: BattleLabelCache(),
      cache: cache,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, 1.2);
    // 40 发子弹分属两种颜色，120 颗碎屑分属两种颜色；合批组数不超过 32。
    expect(painter.batchGroups, greaterThan(0));
    expect(painter.batchGroups, lessThanOrEqualTo(32));
    recorder.endRecording().dispose();
    cache.dispose();
  });

  test('稳态战斗帧的绘制指令数可控', () {
    final sim = _busySim();
    final painter = BattleScenePainter(sim: sim);
    painter.prepare();
    final canvas = _CountingCanvas();
    for (var i = 0; i < 3; i++) {
      painter.paint(canvas, 1 + i / 60);
    }
    canvas.calls = 0;
    painter.paint(canvas, 2);
    // 12 名步兵/枪手、装甲车、头目、40 发子弹与 120 颗粒子同屏时约 260 条。
    expect(canvas.calls, lessThan(320));
    painter.dispose();
  });
}

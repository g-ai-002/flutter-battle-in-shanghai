import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:battle_in_shanghai/flame/scene_cache.dart';
import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/theme/battle_painting.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// 只统计绘制调用次数的画布：所有方法经 noSuchMethod 计数后丢弃。
class _CountingCanvas implements Canvas {
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    return null;
  }
}

Future<Uint8List> _render(void Function(Canvas canvas) draw, {double zoom = 2}) async {
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

double _walk(int frame) => frame * 2 * math.pi / SceneCache.soldierWalkFrames;

/// 旧版枪线：在平移后的画布上用相对坐标落笔，作为绝对坐标的像素基准。
void _paintGunTranslated(Canvas canvas, Offset center, double radius, double aim) {
  final s = radius / 9;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  final start = Offset(math.cos(aim) * 3 * s, math.sin(aim) * 3 * s);
  canvas.drawLine(
    start,
    Offset(math.cos(aim) * 15 * s, math.sin(aim) * 15 * s),
    Paint()
      ..color = const Color(0xFF1A1512)
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    Offset(
      start.dx + math.cos(aim + 1.2) * 3,
      start.dy + math.sin(aim + 1.2) * 3,
    ),
    Offset(
      start.dx + math.cos(aim - 1.4) * 2,
      start.dy + math.sin(aim - 1.4) * 3,
    ),
    Paint()
      ..color = const Color(0xFF1A1512)
      ..strokeWidth = 1.6 * s,
  );
  canvas.restore();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('士兵精灵与直接绘制像素一致，仅边缘抗锯齿略有差别', () async {
    final cache = SceneCache()..ensure();
    const center = Offset(150, 200);
    final cases = <(SoldierLook, double, int, double, bool, double)>[
      (enemyLooks[EnemyKind.infantry]!, 9, 5, math.pi / 2, true, 0),
      (enemyLooks[EnemyKind.rifleman]!, 9, 11, 1.2, true, 0.7),
      (enemyLooks[EnemyKind.shield]!, 10, 3, math.pi / 2, true, 0),
      (enemyLooks[EnemyKind.raider]!, 8, 14, 2.3, true, 0),
      (playerLook, 8, 0, -math.pi / 2, false, 0),
    ];
    for (final (look, radius, frame, aim, hostile, flash) in cases) {
      final direct = await _render(
        (canvas) => paintSoldier(
          canvas,
          center,
          radius: radius,
          uniform: look.uniform,
          helmet: look.helmet,
          accent: look.accent,
          aim: aim,
          walk: _walk(frame),
          flash: flash,
          hostile: hostile,
          shield: look.shield,
          blade: look.blade,
        ),
      );
      final sprite = await _render(
        (canvas) => cache.drawSoldier(
          canvas,
          center,
          look: look,
          radius: radius,
          walk: _walk(frame),
          aim: aim,
          hostile: hostile,
          flash: flash,
        ),
      );
      final (maxDiff, differing) = _compare(direct, sprite);
      expect(maxDiff, lessThanOrEqualTo(96), reason: '半径 $radius 帧 $frame');
      expect(differing, lessThan(320), reason: '半径 $radius 帧 $frame');
    }
    cache.dispose();
  });

  test('士兵精灵按步伐帧复用，稳态帧不再录制', () {
    final cache = SceneCache()..ensure();
    expect(cache.layerBuilds, SceneCache.layerCount);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final look = enemyLooks[EnemyKind.infantry]!;
    for (var frame = 0; frame < SceneCache.soldierWalkFrames; frame++) {
      expect(
        cache.drawSoldier(
          canvas,
          const Offset(90, 160),
          look: look,
          radius: 9,
          walk: _walk(frame),
          aim: math.pi / 2,
          hostile: true,
        ),
        isTrue,
      );
    }
    // 第 0 帧已在开局预热，其余步伐帧按需补齐；后续循环不再新增。
    final built = cache.soldierBuilds;
    expect(built, lessThanOrEqualTo(12 + SceneCache.soldierWalkFrames - 1));
    for (var pass = 0; pass < 2; pass++) {
      for (var frame = 0; frame < SceneCache.soldierWalkFrames; frame++) {
        cache.drawSoldier(
          canvas,
          const Offset(90, 160),
          look: look,
          radius: 9,
          walk: _walk(frame),
          aim: math.pi / 2,
          hostile: true,
        );
      }
    }
    recorder.endRecording().dispose();
    expect(cache.soldierBuilds, built);
    expect(cache.layerBuilds, SceneCache.layerCount);
    cache.dispose();
  });

  test('缓存士兵只用贴图加两道枪线，枪线不再包裹画布状态', () {
    final cache = SceneCache()..ensure();
    final look = enemyLooks[EnemyKind.rifleman]!;
    final direct = _CountingCanvas();
    paintSoldier(
      direct,
      const Offset(150, 200),
      radius: 9,
      uniform: look.uniform,
      helmet: look.helmet,
      accent: look.accent,
      aim: math.pi / 2,
      walk: _walk(4),
      hostile: true,
    );
    final cached = _CountingCanvas();
    cache.drawSoldier(
      cached,
      const Offset(150, 200),
      look: look,
      radius: 9,
      walk: _walk(4),
      aim: math.pi / 2,
      hostile: true,
    );
    // 上下半身各一张贴图 + 两道枪线；绝对坐标落笔省掉 save/translate/restore。
    expect(cached.calls, 4);
    expect(cached.calls, lessThan(direct.calls));
    cache.dispose();
  });

  test('枪线绝对坐标绘制与旧版平移画布逐像素一致', () async {
    const center = Offset(150, 200);
    for (final aim in [-math.pi / 2, 0.3, 1.2, 2.7]) {
      final direct = await _render(
        (canvas) => _paintGunTranslated(canvas, center, 9, aim),
      );
      final absolute = await _render(
        (canvas) => paintSoldierGun(canvas, center, radius: 9, aim: aim),
      );
      final (maxDiff, differing) = _compare(direct, absolute);
      expect(maxDiff, 0, reason: 'aim $aim');
      expect(differing, 0, reason: 'aim $aim');
    }
  });

  test('枪线不再切换画布状态，单次只留两道 drawLine', () {
    final canvas = _CountingCanvas();
    paintSoldierGun(canvas, const Offset(120, 200), radius: 9, aim: 0.7);
    expect(canvas.calls, 2);
  });
}

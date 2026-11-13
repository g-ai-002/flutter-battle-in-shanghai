import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:battle_in_shanghai/flame/scene_cache.dart';
import 'package:battle_in_shanghai/theme/battle_painting.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 逐像素对照：缓存贴图必须和直接绘制的画面一致，边缘允许 1~2 级差异。
Future<Uint8List> _render(
  void Function(Canvas canvas) draw, {
  required double zoom,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const field = Size(Field.width, Field.height);
  late SceneCache cache;

  setUp(() {
    cache = SceneCache()..ensure();
  });

  tearDown(() => cache.dispose());

  test('街垒缓存与直接绘制逐像素一致', () async {
    final direct = await _render(
      (canvas) => paintBarricadeBase(canvas, field),
      zoom: 2,
    );
    final cached = await _render(cache.drawBarricade, zoom: 2);
    final (maxDiff, differing) = _compare(direct, cached);
    expect(maxDiff, lessThanOrEqualTo(2));
    expect(differing, lessThan(200));
  });

  test('探索灯缓存与直接绘制逐像素一致', () async {
    final direct = await _render(
      (canvas) => paintSearchlight(canvas, field, 0),
      zoom: 1,
    );
    final cached = await _render(
      (canvas) => cache.drawSearchlight(canvas, 0),
      zoom: 1,
    );
    final (maxDiff, differing) = _compare(direct, cached);
    expect(maxDiff, lessThanOrEqualTo(4));
    expect(differing, lessThan(200));
  });

  test('工事磨损贴图与直接绘制逐像素一致', () async {
    for (final hpRatio in [1.0, 0.75, 0.5, 0.25, 0.0]) {
      final direct = await _render(
        (canvas) => paintCoverWall(
          canvas,
          const Offset(150, 262),
          hpRatio,
          0,
          0,
        ),
        zoom: 2,
      );
      final cached = await _render(
        (canvas) => cache.drawCover(
          canvas,
          const Offset(150, 262),
          hpRatio,
          0,
          0,
        ),
        zoom: 2,
      );
      final (maxDiff, differing) = _compare(direct, cached);
      expect(maxDiff, lessThanOrEqualTo(2), reason: '血量 $hpRatio');
      expect(differing, lessThan(200), reason: '血量 $hpRatio');
    }
  });
}

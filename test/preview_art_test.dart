import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:battle_in_shanghai/game/battle_scenes.dart';
import 'package:battle_in_shanghai/theme/battle_painting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 按首页缩略图的实际尺寸渲染一张位图。
Future<Uint8List> _renderPreview(
  BattleScene scene, {
  double width = 150,
}) async {
  final size = Size(width, width * 4 / 3);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintBattlefieldPreview(canvas, size, scene);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  picture.dispose();
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('首页缩略图随阵地切换街景，三处画面互不相同', () async {
    final zhabei = await _renderPreview(BattleScene.zhabei);
    final bund = await _renderPreview(BattleScene.bund);
    final warehouse = await _renderPreview(BattleScene.warehouse);
    expect(zhabei, isNot(equals(bund)));
    expect(bund, isNot(equals(warehouse)));
    expect(zhabei, isNot(equals(warehouse)));
  });

  test('缩略图按画布尺寸作画，结束后画布状态复原', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintBattlefieldPreview(canvas, const Size(240, 320), BattleScene.bund);
    // save / scale / restore 成对，缩略图不会把缩放泄漏给后续绘制。
    expect(
      canvas.getTransform(),
      equals(
        Float64List.fromList([
          1, 0, 0, 0, //
          0, 1, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1, //
        ]),
      ),
    );
    recorder.endRecording().dispose();
  });
}

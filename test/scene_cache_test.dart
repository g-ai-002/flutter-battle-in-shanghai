import 'dart:ui' as ui;

import 'package:battle_in_shanghai/flame/battle_scene_painter.dart';
import 'package:battle_in_shanghai/flame/scene_cache.dart';
import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('静态图层缓存生成位图并可释放', () {
    final cache = SceneCache();
    cache.ensure();
    expect(cache.ready, isTrue);
    expect(cache.unavailable, isFalse);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    cache.drawBase(canvas);
    cache.drawRoofs(canvas, 1.4);
    cache.drawGlow(canvas, const Offset(150, 320));
    cache.drawVignette(canvas);
    recorder.endRecording().dispose();

    cache.dispose();
    expect(cache.ready, isFalse);
  });

  test('战场走缓存路径绘制不抛异常', () {
    final sim = BattleSim(
      mode: BattleMode.endless,
      difficulty: Difficulty.veteran,
    );
    sim.start();
    for (var i = 0; i < 60; i++) {
      sim.update(1 / 60);
    }

    final painter = BattleScenePainter(sim: sim);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    expect(() => painter.paint(canvas, 1.2), returnsNormally);
    recorder.endRecording().dispose();
    painter.dispose();
  });
}

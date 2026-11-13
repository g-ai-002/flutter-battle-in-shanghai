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

  test('工事、航弹与空袭飞机同时出现时也能正常绘制', () {
    final sim = BattleSim(
      mode: BattleMode.campaign,
      difficulty: Difficulty.veteran,
    )..start();
    for (var i = 0; i < 540; i++) {
      sim.update(1 / 60);
    }
    expect(sim.covers, isNotEmpty);
    expect(sim.callAirstrike(), isTrue);
    sim.update(1 / 60);
    sim.deployCover();

    final painter = BattleScenePainter(sim: sim);
    for (var frame = 0; frame < 40; frame++) {
      sim.update(1 / 30);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painter.paint(canvas, frame / 30), returnsNormally);
      recorder.endRecording().dispose();
    }
    painter.dispose();
  });
}

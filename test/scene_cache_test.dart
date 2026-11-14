import 'dart:ui' as ui;

import 'package:battle_in_shanghai/flame/battle_scene_painter.dart';
import 'package:battle_in_shanghai/flame/scene_cache.dart';
import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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
    cache.drawProps(canvas);
    cache.drawGlow(canvas, const Offset(150, 320));
    cache.drawVignette(canvas);
    recorder.endRecording().dispose();

    cache.dispose();
    expect(cache.ready, isFalse);
  });

  test('街垒、探照灯与五档工事图形在首帧前一次录好', () {
    final cache = SceneCache();
    cache.ensure();
    // 路面、屋顶、暗角、环境光、探照灯、街垒与五档工事。
    expect(cache.layerBuilds, SceneCache.layerCount);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var frame = 0; frame < 90; frame++) {
      cache.drawBase(canvas);
      cache.drawRoofs(canvas, frame / 60);
      cache.drawProps(canvas);
      cache.drawSearchlight(canvas, frame / 60);
      cache.drawBarricade(canvas);
      cache.drawVignette(canvas);
      cache.drawGlow(canvas, const Offset(150, 320));
      // 血量在 100% / 75% / 50% / 25% / 0% 之间循环，五档全部命中。
      final hpRatio = 1 - frame % 5 / 4;
      expect(
        cache.drawCover(
          canvas,
          const Offset(90, 262),
          hpRatio,
          frame / 60,
          0,
        ),
        isTrue,
      );
    }
    recorder.endRecording().dispose();
    expect(cache.layerBuilds, SceneCache.layerCount);
    cache.dispose();
  });

  test('缓存释放后工事贴图不可用，调用方回退直接绘制', () {
    final cache = SceneCache();
    cache.ensure();
    cache.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    expect(
      cache.drawCover(canvas, const Offset(90, 262), 1, 0, 0),
      isFalse,
    );
    recorder.endRecording().dispose();
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

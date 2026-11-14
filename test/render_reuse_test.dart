import 'dart:ui' as ui;

import 'package:battle_in_shanghai/flame/battle_scene_painter.dart';
import 'package:battle_in_shanghai/flame/scene_cache.dart';
import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:battle_in_shanghai/theme/battle_painting.dart';
import 'package:battle_in_shanghai/theme/paint_kit.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetGradientCache);

  test('爆炸的径向渐变按档位复用，第二遍动画不再新建', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < 31; i++) {
      paintExplosion(canvas, const Offset(150, 200), 44, i / 30);
    }
    final firstPass = gradientBuildCount;
    expect(firstPass, greaterThan(0));
    expect(firstPass, lessThanOrEqualTo(31));

    for (var i = 0; i < 31; i++) {
      paintExplosion(canvas, const Offset(150, 200), 44, i / 30);
    }
    expect(gradientBuildCount, firstPass);
    recorder.endRecording().dispose();
  });

  test('准星线、补给光晕与探照灯的渐变只创建一次', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < 60; i++) {
      paintAimBeam(canvas, const Offset(150, 320), 150, 0.8);
      paintPickup(canvas, const Offset(90, 200), PickupKind.ammo, i / 10);
      paintSearchlight(
        canvas,
        const Size(Field.width, Field.height),
        i / 60,
      );
    }
    // 准星线、补给光晕与探照灯各一支渐变。
    expect(gradientBuildCount, 3);
    recorder.endRecording().dispose();
  });

  test('低血量警示按强度档位缓存，回落后直接命中', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const field = Size(Field.width, Field.height);
    for (var i = 1; i <= 10; i++) {
      paintDamageWash(canvas, field, i / 10);
    }
    final firstPass = gradientBuildCount;
    expect(firstPass, 10);
    for (var i = 10; i >= 1; i--) {
      paintDamageWash(canvas, field, i / 10);
    }
    expect(gradientBuildCount, firstPass);
    recorder.endRecording().dispose();
  });

  test('战场稳态绘制不再新建渐变或静态图层', () {
    final sim = BattleSim(
      mode: BattleMode.endless,
      difficulty: Difficulty.recruit,
    )..start();
    sim.player.shieldUntil = 10;
    final effect = BattleEffect(
      kind: EffectKind.explosion,
      x: 150,
      y: 200,
      radius: 44,
      duration: 0.5,
    );
    sim.effects.add(effect);

    final cache = SceneCache()..ensure();
    final painter = BattleScenePainter(sim: sim, cache: cache);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    for (var i = 0; i < 30; i++) {
      effect.age = i / 60;
      painter.paint(canvas, i / 60);
    }
    final warmGradients = gradientBuildCount;
    final layers = cache.layerBuilds;
    expect(warmGradients, greaterThan(0));

    for (var i = 0; i < 30; i++) {
      effect.age = i / 60;
      painter.paint(canvas, i / 60);
    }
    expect(gradientBuildCount, warmGradients);
    expect(cache.layerBuilds, layers);

    recorder.endRecording().dispose();
    painter.dispose();
  });
}

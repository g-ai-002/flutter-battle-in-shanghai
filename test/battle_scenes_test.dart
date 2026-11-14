import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:battle_in_shanghai/flame/scene_cache.dart';
import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_scenes.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:battle_in_shanghai/game/boss_patterns.dart';
import 'package:battle_in_shanghai/game/campaign_waves.dart';
import 'package:battle_in_shanghai/providers/settings_provider.dart';
import 'package:battle_in_shanghai/services/storage_service.dart';
import 'package:battle_in_shanghai/theme/scene_palette.dart';
import 'package:battle_in_shanghai/theme/scene_props.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Uint8List> _renderBase(BattleScene scene) async {
  final cache = SceneCache(scene: scene)..ensure();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  cache.drawBase(canvas);
  cache.drawProps(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (Field.width * 2).round(),
    (Field.height * 2).round(),
  );
  picture.dispose();
  cache.dispose();
  final data = await image.toByteData();
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  group('阵地定义', () {
    test('四处阵地按闸北、外滩、四行仓库、苏州河顺序解锁', () {
      expect(BattleScene.values.map((scene) => scene.label), [
        '闸北',
        '外滩',
        '四行仓库',
        '苏州河',
      ]);
      expect(BattleScene.zhabei.next, BattleScene.bund);
      expect(BattleScene.bund.next, BattleScene.warehouse);
      expect(BattleScene.warehouse.next, BattleScene.suzhou);
      expect(BattleScene.suzhou.next, isNull);
      expect(BattleScene.suzhou.previous, BattleScene.warehouse);
      expect(BattleScene.byName('bund'), BattleScene.bund);
      expect(BattleScene.byName('unknown'), BattleScene.zhabei);
    });

    test('越靠后的阵地敌军生命倍率越高', () {
      final scales = BattleScene.values.map((scene) => scene.hpScale).toList();
      for (var i = 1; i < scales.length; i++) {
        expect(scales[i], greaterThan(scales[i - 1]));
      }
    });

    test('每处阵地都有配色、景物绘制器与头目弹幕表项', () {
      for (final scene in BattleScene.values) {
        expect(scenePalettes.containsKey(scene), isTrue, reason: scene.label);
        expect(
          scenePropsPainters.containsKey(scene),
          isTrue,
          reason: scene.label,
        );
        expect(bossKits.containsKey(scene), isTrue, reason: scene.label);
      }
      expect(
        scenePalettes.values.map((palette) => palette.id).toSet(),
        hasLength(BattleScene.values.length),
      );
    });

    test('静态图层缓存按阵地取配色', () {
      for (final scene in BattleScene.values) {
        final cache = SceneCache(scene: scene);
        expect(cache.palette, same(paletteOf(scene)), reason: scene.label);
        cache.dispose();
      }
    });
  });

  group('关卡波次', () {
    test('每处阵地都是五波，最后一波是头目', () {
      for (final scene in BattleScene.values) {
        final waves = sceneWaves(scene, Difficulty.veteran);
        expect(waves, hasLength(kCampaignWaves), reason: scene.label);
        expect(waves.last.boss, isTrue, reason: scene.label);
        expect(waves.last.hpMultiplier, scene.hpScale);
        for (var i = 0; i < waves.length; i++) {
          expect(waves[i].index, i + 1, reason: scene.label);
          expect(waves[i].boss, i == waves.length - 1, reason: scene.label);
        }
      }
    });

    test('四处阵地的阵型名称互不重复', () {
      final names = <String>[];
      for (final scene in BattleScene.values) {
        final waves = sceneWaves(scene, Difficulty.veteran);
        names.addAll(waves.map((wave) => wave.name));
        expect(waves.map((wave) => wave.name).toSet(), hasLength(waves.length));
      }
      expect(names.toSet(), hasLength(names.length));
    });

    test('每个刷怪点都落在战场内，远程兵有停靠高度', () {
      for (final scene in BattleScene.values) {
        for (final difficulty in Difficulty.values) {
          for (final wave in sceneWaves(scene, difficulty)) {
            expect(wave.orders, isNotEmpty);
            for (final order in wave.orders) {
              expect(order.x, inInclusiveRange(20, Field.width - 20));
              expect(order.at, greaterThanOrEqualTo(0));
              if (order.kind == EnemyKind.infantry ||
                  order.kind == EnemyKind.raider ||
                  order.kind == EnemyKind.shield) {
                expect(order.holdY, 0);
              } else {
                expect(order.holdY, greaterThan(0));
              }
            }
          }
        }
      }
    });

    test('苏州河是第四处阵地，铁桥头目与五波阵型齐备', () {
      expect(BattleScene.suzhou.title, '苏州河 · 铁桥');
      expect(BattleScene.suzhou.bossName, '九四式装甲炮艇');
      final waves = sceneWaves(BattleScene.suzhou, Difficulty.veteran);
      expect(waves.map((wave) => wave.name), [
        '桥头遭遇',
        '铁桥封锁',
        '河面炮火',
        '装甲登陆',
        '桥心决战',
      ]);
      final kinds = waves
          .expand((wave) => wave.orders)
          .map((order) => order.kind)
          .toSet();
      expect(kinds, containsAll(EnemyKind.values));
    });

    test('同一阵地同一难度稳定复现', () {
      final first = sceneWaves(BattleScene.warehouse, Difficulty.ace);
      final second = sceneWaves(BattleScene.warehouse, Difficulty.ace);
      for (var i = 0; i < first.length; i++) {
        expect(
          first[i].orders.map((order) => order.holdY).toList(),
          second[i].orders.map((order) => order.holdY).toList(),
        );
      }
    });

    test('战斗模拟按所选阵地选用波次表', () {
      final sim = BattleSim(
        mode: BattleMode.campaign,
        difficulty: Difficulty.veteran,
        scene: BattleScene.bund,
        random: math.Random(3),
      )..start();
      expect(sim.scene, BattleScene.bund);
      expect(sim.waveName, '江岸登陆');
      expect(sim.result.scene, BattleScene.bund);
    });
  });

  group('阵地进度', () {
    test('选择与通关记录写入本机并读回', () async {
      final storage = await StorageService.instance;
      expect(storage.scene, BattleScene.zhabei);
      expect(storage.clearedScenes, isEmpty);

      await storage.setScene(BattleScene.bund);
      await storage.markSceneCleared(BattleScene.zhabei);
      await storage.markSceneCleared(BattleScene.zhabei);

      expect(storage.scene, BattleScene.bund);
      expect(storage.clearedScenes, {BattleScene.zhabei});
    });

    test('通关上一处阵地才能解锁下一处', () async {
      final storage = await StorageService.instance;
      final settings = SettingsProvider(storage);
      expect(settings.isSceneUnlocked(BattleScene.zhabei), isTrue);
      expect(settings.isSceneUnlocked(BattleScene.bund), isFalse);
      expect(settings.isSceneUnlocked(BattleScene.warehouse), isFalse);
      expect(settings.isSceneUnlocked(BattleScene.suzhou), isFalse);

      await settings.markSceneCleared(BattleScene.zhabei);
      expect(settings.isSceneUnlocked(BattleScene.bund), isTrue);
      expect(settings.isSceneUnlocked(BattleScene.warehouse), isFalse);

      await settings.markSceneCleared(BattleScene.bund);
      expect(settings.isSceneUnlocked(BattleScene.warehouse), isTrue);
      expect(settings.isSceneUnlocked(BattleScene.suzhou), isFalse);

      await settings.markSceneCleared(BattleScene.warehouse);
      expect(settings.isSceneUnlocked(BattleScene.suzhou), isTrue);
    });

    test('未知的阵地名称回退到闸北且不计入通关', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.prefKeyScene: 'nanjing',
        AppConstants.prefKeyClearedScenes: ['nanjing', 'bund'],
      });
      StorageService.resetForTests();
      final storage = await StorageService.instance;
      expect(storage.scene, BattleScene.zhabei);
      expect(storage.clearedScenes, {BattleScene.bund});
    });
  });

  test('四处阵地的街景与景物逐像素不同', () async {
    final images = <Uint8List>[];
    for (final scene in BattleScene.values) {
      images.add(await _renderBase(scene));
    }
    for (var i = 0; i < images.length; i++) {
      for (var j = i + 1; j < images.length; j++) {
        expect(
          images[i],
          isNot(equals(images[j])),
          reason:
              '${BattleScene.values[i].label} vs ${BattleScene.values[j].label}',
        );
      }
    }
  });
}

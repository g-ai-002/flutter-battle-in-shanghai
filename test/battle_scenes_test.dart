import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:battle_in_shanghai/flame/scene_cache.dart';
import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/battle_scenes.dart';
import 'package:battle_in_shanghai/game/battle_sim.dart';
import 'package:battle_in_shanghai/game/campaign_waves.dart';
import 'package:battle_in_shanghai/providers/settings_provider.dart';
import 'package:battle_in_shanghai/services/storage_service.dart';
import 'package:battle_in_shanghai/theme/scene_palette.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Uint8List> _renderBase(BattleScene scene) async {
  final cache = SceneCache(
    palette: paletteOf(scene),
    scene: scene,
  )..ensure();
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
    test('三处阵地按闸北、外滩、四行仓库顺序解锁', () {
      expect(BattleScene.values.map((scene) => scene.label), [
        '闸北',
        '外滩',
        '四行仓库',
      ]);
      expect(BattleScene.zhabei.next, BattleScene.bund);
      expect(BattleScene.bund.next, BattleScene.warehouse);
      expect(BattleScene.warehouse.next, isNull);
      expect(BattleScene.byName('bund'), BattleScene.bund);
      expect(BattleScene.byName('unknown'), BattleScene.zhabei);
    });

    test('越靠后的阵地敌军生命倍率越高', () {
      expect(
        BattleScene.bund.hpScale,
        greaterThan(BattleScene.zhabei.hpScale),
      );
      expect(
        BattleScene.warehouse.hpScale,
        greaterThan(BattleScene.bund.hpScale),
      );
    });
  });

  group('关卡波次', () {
    test('每处阵地都是五波，最后一波是头目', () {
      for (final scene in BattleScene.values) {
        final waves = sceneWaves(scene, Difficulty.veteran);
        expect(waves, hasLength(kCampaignWaves), reason: scene.label);
        expect(waves.last.boss, isTrue, reason: scene.label);
        expect(waves.last.hpMultiplier, scene.hpScale);
        for (final wave in waves.take(waves.length - 1)) {
          expect(wave.boss, isFalse, reason: scene.label);
        }
      }
    });

    test('三处阵地的阵型名称互不重复', () {
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

      await settings.markSceneCleared(BattleScene.zhabei);
      expect(settings.isSceneUnlocked(BattleScene.bund), isTrue);
      expect(settings.isSceneUnlocked(BattleScene.warehouse), isFalse);

      await settings.markSceneCleared(BattleScene.bund);
      expect(settings.isSceneUnlocked(BattleScene.warehouse), isTrue);
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

  test('三处阵地的街景与景物逐像素不同', () async {
    final zhabei = await _renderBase(BattleScene.zhabei);
    final bund = await _renderBase(BattleScene.bund);
    final warehouse = await _renderBase(BattleScene.warehouse);
    expect(zhabei, isNot(equals(bund)));
    expect(bund, isNot(equals(warehouse)));
    expect(zhabei, isNot(equals(warehouse)));
  });
}

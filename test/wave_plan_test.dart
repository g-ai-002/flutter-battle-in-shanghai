import 'dart:math' as math;

import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/wave_plan.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('战役波次', () {
    test('固定五波，最后一波是头目', () {
      final waves = campaignWaves(Difficulty.veteran);
      expect(waves, hasLength(kCampaignWaves));
      expect(waves.last.boss, isTrue);
      expect(
        waves.last.orders.any((order) => order.kind == EnemyKind.boss),
        isTrue,
      );
      for (var i = 0; i < waves.length - 1; i++) {
        expect(waves[i].boss, isFalse);
      }
    });

    test('每个刷怪点都落在战场横向范围内', () {
      for (final difficulty in Difficulty.values) {
        final waves = campaignWaves(difficulty);
        for (final wave in waves) {
          expect(wave.orders, isNotEmpty);
          for (final order in wave.orders) {
            expect(order.x, inInclusiveRange(20, Field.width - 20));
            expect(order.at, greaterThanOrEqualTo(0));
          }
        }
      }
    });

    test('远程兵种有停下的纵坐标，步兵一直推进', () {
      final waves = campaignWaves(Difficulty.veteran);
      for (final wave in waves) {
        for (final order in wave.orders) {
          switch (order.kind) {
            case EnemyKind.infantry:
              expect(order.holdY, 0);
            case EnemyKind.rifleman:
            case EnemyKind.grenadier:
            case EnemyKind.armoredCar:
            case EnemyKind.boss:
              expect(order.holdY, greaterThan(0));
          }
        }
      }
    });

    test('王牌难度的出怪节奏更快', () {
      final recruit = campaignWaves(Difficulty.recruit).first.orders;
      final ace = campaignWaves(Difficulty.ace).first.orders;
      expect(ace.length, recruit.length);
      expect(ace.first.at, lessThan(recruit.first.at));
    });
  });

  group('无尽波次', () {
    test('每五波出现一个头目', () {
      for (var index = 1; index <= 12; index++) {
        final wave = endlessWave(index, Difficulty.veteran, random: math.Random(index));
        expect(wave.boss, index % kEndlessBossEvery == 0);
        if (wave.boss) {
          expect(
            wave.orders.any((order) => order.kind == EnemyKind.boss),
            isTrue,
          );
        }
      }
    });

    test('敌军数量与强度随波次增长', () {
      final first = endlessWave(1, Difficulty.veteran, random: math.Random(1));
      final tenth = endlessWave(10, Difficulty.veteran, random: math.Random(10));
      expect(tenth.orders.length, greaterThan(first.orders.length));
      expect(tenth.hpMultiplier, greaterThan(first.hpMultiplier));
    });

    test('头目血量随轮次显著提高', () {
      final firstBoss = endlessWave(5, Difficulty.veteran, random: math.Random(5));
      final thirdBoss = endlessWave(15, Difficulty.veteran, random: math.Random(15));
      expect(thirdBoss.hpMultiplier, greaterThan(firstBoss.hpMultiplier * 1.3));
    });
  });

  test('波次时长覆盖所有刷怪点', () {
    const wave = WavePlan(
      index: 1,
      orders: [
        SpawnOrder(at: 1, kind: EnemyKind.infantry, x: 100),
        SpawnOrder(at: 3.5, kind: EnemyKind.rifleman, x: 200, holdY: 120),
      ],
    );
    expect(wave.duration, greaterThanOrEqualTo(5.5));
    expect(const WavePlan(index: 1, orders: []).duration, 0);
  });
}

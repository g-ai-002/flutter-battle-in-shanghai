import 'dart:math' as math;

import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/wave_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('波次编排', () {
    test('横向铺开一队敌军，停靠高度落在给定区间', () {
      final builder = WaveBuilder(
        difficulty: Difficulty.veteran,
        random: math.Random(9),
      );
      builder.line(
        EnemyKind.rifleman,
        5,
        1,
        0.5,
        fromX: 60,
        toX: 240,
        holdMin: 80,
        holdMax: 120,
      );
      final orders = builder.flush();
      expect(orders, hasLength(5));
      expect(orders.first.x, 60);
      expect(orders.last.x, 240);
      expect(orders.map((order) => order.at), [1, 1.5, 2, 2.5, 3]);
      for (final order in orders) {
        expect(order.kind, EnemyKind.rifleman);
        expect(order.holdY, inInclusiveRange(80, 120));
      }
    });

    test('flush 之后重新从空表开始', () {
      final builder = WaveBuilder(
        difficulty: Difficulty.veteran,
        random: math.Random(1),
      );
      builder.add(EnemyKind.infantry, 0.2, 100);
      expect(builder.flush(), hasLength(1));
      expect(builder.flush(), isEmpty);
    });

    test('难度节奏按倍率缩放刷怪时间', () {
      SpawnOrder firstOrder(Difficulty difficulty) {
        final builder = WaveBuilder(
          difficulty: difficulty,
          random: math.Random(2),
        )..add(EnemyKind.infantry, 2, 100);
        return builder.flush().single;
      }

      expect(firstOrder(Difficulty.veteran).at, 2);
      expect(firstOrder(Difficulty.recruit).at, greaterThan(2));
      expect(firstOrder(Difficulty.ace).at, lessThan(2));
    });

    test('战役波次对同一难度稳定复现', () {
      final first = campaignWaves(Difficulty.veteran);
      final second = campaignWaves(Difficulty.veteran);
      for (var i = 0; i < first.length; i++) {
        expect(
          second[i].orders.map((order) => order.holdY).toList(),
          first[i].orders.map((order) => order.holdY).toList(),
        );
      }
    });
  });
}

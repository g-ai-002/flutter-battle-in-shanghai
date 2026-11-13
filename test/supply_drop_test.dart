import 'dart:math' as math;

import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:battle_in_shanghai/game/supply_drop.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

EnemyUnit enemyOf(EnemyKind kind, {double x = 150, double y = 200}) =>
    EnemyUnit(kind: kind, x: x, y: y, hp: 100, maxHp: 100, holdY: 0);

void main() {
  group('掉落规则', () {
    test('头目必掉急救包与弹药箱各一件', () {
      final drops = rollDrops(
        enemyOf(EnemyKind.boss),
        playerHpRatio: 1,
        random: math.Random(1),
      );
      expect(drops, hasLength(2));
      expect(
        drops.map((drop) => drop.kind),
        containsAll([PickupKind.medkit, PickupKind.ammo]),
      );
    });

    test('精英必掉一件补给', () {
      for (var seed = 0; seed < 8; seed++) {
        final drops = rollDrops(
          enemyOf(EnemyKind.armoredCar),
          playerHpRatio: 1,
          random: math.Random(seed),
        );
        expect(drops, hasLength(1));
      }
    });

    test('普通敌兵按概率掉落，可能空手', () {
      final counts = [
        for (var seed = 0; seed < 60; seed++)
          rollDrops(
            enemyOf(EnemyKind.infantry),
            playerHpRatio: 1,
            random: math.Random(seed),
          ).length,
      ];
      expect(counts, contains(0));
      expect(counts, contains(1));
      expect(counts.every((count) => count <= 1), isTrue);
    });

    test('掉落点被收进战场范围', () {
      final drops = rollDrops(
        enemyOf(EnemyKind.armoredCar, x: -40, y: 900),
        playerHpRatio: 1,
        random: math.Random(3),
      );
      final drop = drops.single;
      expect(drop.x, 20);
      expect(drop.y, Field.height - 40);
    });
  });

  group('补给类型权重', () {
    int countOf(PickupKind kind, double hpRatio, int samples) {
      final random = math.Random(11);
      var count = 0;
      for (var i = 0; i < samples; i++) {
        if (rollPickupKind(hpRatio, random) == kind) count++;
      }
      return count;
    }

    test('残血时更偏向急救包', () {
      final low = countOf(PickupKind.medkit, 0.2, 400);
      final full = countOf(PickupKind.medkit, 1, 400);
      expect(low, greaterThan(full));
    });

    test('三档补给都会出现', () {
      final random = math.Random(5);
      final kinds = <PickupKind>{
        for (var i = 0; i < 200; i++) rollPickupKind(0.8, random),
      };
      expect(kinds, containsAll(PickupKind.values));
    });
  });
}

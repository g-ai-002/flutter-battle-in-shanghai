import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/combat_math.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:flutter_test/flutter_test.dart';

EnemyUnit enemyAt(double x, double y, {bool dead = false}) {
  final enemy = EnemyUnit(
    kind: EnemyKind.infantry,
    x: x,
    y: y,
    hp: 10,
    maxHp: 10,
    holdY: 0,
  );
  enemy.dead = dead;
  return enemy;
}

void main() {
  group('圆形重叠', () {
    test('相切算命中，超出半径不算', () {
      expect(circleOverlap(0, 0, 10, 0, 10), isTrue);
      expect(circleOverlap(0, 0, 10.01, 0, 10), isFalse);
      expect(circleOverlap(0, 0, 0, 0, 0), isTrue);
    });
  });

  group('扫掠命中', () {
    test('线段穿过圆心时命中，即使两端都在圆外', () {
      expect(segmentHitsCircle(0, 50, 100, 50, 50, 50, 3), isTrue);
    });

    test('线段擦过圆边按半径判定', () {
      expect(segmentHitsCircle(0, 0, 100, 0, 50, 9, 10), isTrue);
      expect(segmentHitsCircle(0, 0, 100, 0, 50, 11, 10), isFalse);
    });

    test('线段背向圆时不命中', () {
      expect(segmentHitsCircle(0, 0, 40, 0, 80, 0, 5), isFalse);
    });

    test('零长度线段退化为点判定', () {
      expect(segmentHitsCircle(50, 50, 50, 50, 52, 50, 2), isTrue);
      expect(segmentHitsCircle(50, 50, 50, 50, 53, 50, 2), isFalse);
    });
  });

  group('最近敌军', () {
    test('忽略已死亡单位，返回距离最近的一个', () {
      final near = enemyAt(110, 300);
      final deadNear = enemyAt(105, 300, dead: true);
      final far = enemyAt(200, 300);
      final target = nearestEnemy([far, deadNear, near], 100, 300);
      expect(target, same(near));
    });

    test('没有存活敌军时返回 null', () {
      expect(nearestEnemy([enemyAt(10, 10, dead: true)], 0, 0), isNull);
      expect(nearestEnemy(const [], 0, 0), isNull);
    });
  });
}

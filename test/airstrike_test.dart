import 'package:battle_in_shanghai/game/airstrike.dart';
import 'package:battle_in_shanghai/game/battle_config.dart';
import 'package:battle_in_shanghai/game/entities.dart';
import 'package:battle_in_shanghai/utils/constants.dart';
import 'package:flutter_test/flutter_test.dart';

EnemyUnit enemyAt(double x, double y, {bool dead = false}) => EnemyUnit(
  kind: EnemyKind.infantry,
  x: x,
  y: y,
  hp: 100,
  maxHp: 100,
  holdY: 0,
)..dead = dead;

void main() {
  group('集群选择', () {
    test('空场返回 null，单个敌军返回它自己', () {
      expect(densestCluster(const []), isNull);
      final solo = enemyAt(80, 90);
      expect(densestCluster([solo]), same(solo));
    });

    test('优先选择周围同伴最多的位置，忽略已阵亡单位', () {
      final lonely = enemyAt(40, 80);
      final cluster = [enemyAt(200, 120), enemyAt(210, 126), enemyAt(196, 132)];
      expect(densestCluster([lonely, ...cluster]), same(cluster.first));

      final dead = enemyAt(60, 100, dead: true);
      expect(densestCluster([dead]), isNull);
    });
  });

  group('落点规划', () {
    test('以最密集处为中心铺开三枚航弹，落点有预警时长', () {
      final target = enemyAt(200, 120);
      final bombs = planAirstrike([
        target,
        enemyAt(206, 124),
        enemyAt(196, 128),
      ]);
      expect(bombs, hasLength(kAirstrikeBombs));
      expect(bombs.every((bomb) => bomb.kind == HazardKind.bomb), isTrue);
      expect(bombs.every((bomb) => bomb.fromPlayer), isTrue);
      expect(bombs.every((bomb) => bomb.fromY == -40), isTrue);
      expect(bombs.every((bomb) => bomb.toY == 120), isTrue);
      expect(bombs.every((bomb) => bomb.damage == kAirstrikeDamage), isTrue);
      expect(bombs.every((bomb) => bomb.radius == kAirstrikeRadius), isTrue);
      // 中间的炸弹正落在目标上，两侧各偏一个间距。
      final xs = bombs.map((bomb) => bomb.toX).toList();
      expect(xs[1], closeTo(200, 1e-9));
      expect(xs[1] - xs[0], closeTo(kAirstrikeSpacing, 1e-9));
      expect(xs[2] - xs[1], closeTo(kAirstrikeSpacing, 1e-9));
      // 三枚炸弹依次落下，留出连爆的节奏。
      expect(bombs[1].duration, greaterThan(bombs[0].duration));
      expect(bombs[2].duration, greaterThan(bombs[1].duration));
    });

    test('没有敌军时落在战场中上部，且不越界', () {
      final bombs = planAirstrike(const []);
      expect(bombs, hasLength(kAirstrikeBombs));
      expect(bombs.every((bomb) => bomb.toX > 0), isTrue);
      expect(bombs.every((bomb) => bomb.toX < Field.width), isTrue);
      expect(bombs.every((bomb) => bomb.toY == 150), isTrue);
    });

    test('贴边集群的落点会被收进战场内', () {
      final bombs = planAirstrike([enemyAt(2, 5)]);
      expect(bombs.every((bomb) => bomb.toX >= 24), isTrue);
      expect(bombs.every((bomb) => bomb.toY >= 90), isTrue);
      expect(bombs.every((bomb) => bomb.toY <= Field.height - 90), isTrue);
    });
  });
}

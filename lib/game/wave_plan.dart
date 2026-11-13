import 'dart:math' as math;

import 'battle_config.dart';

/// 单个刷怪指令：波次开始后 [at] 秒在 [x] 处出现。
class SpawnOrder {
  const SpawnOrder({required this.at, required this.kind, required this.x, this.holdY = 0});

  final double at;
  final EnemyKind kind;
  final double x;

  /// 枪手、掷弹兵与装甲车停下的纵向位置，0 表示一直向下推进。
  final double holdY;
}

/// 一波敌军的完整刷怪时间表。
class WavePlan {
  const WavePlan({
    required this.index,
    required this.orders,
    this.boss = false,
    this.hpMultiplier = 1,
  });

  final int index;
  final List<SpawnOrder> orders;
  final bool boss;
  final double hpMultiplier;

  /// 波次持续时间，用于估算进度与刷怪节奏。
  double get duration => orders.isEmpty
      ? 0
      : orders.map((order) => order.at).reduce(math.max) + 2;
}

/// 战役固定五波，难度只影响敌军生命与出怪节奏。
List<WavePlan> campaignWaves(Difficulty difficulty, {math.Random? random}) {
  final pace = difficulty.paceScale;
  final rng = random ?? math.Random(0x5A17);
  double hold(double min, double max) =>
      min + rng.nextDouble() * (max - min);

  SpawnOrder order(
    double at,
    EnemyKind kind,
    double x, {
    double holdY = 0,
  }) => SpawnOrder(at: at * pace, kind: kind, x: x, holdY: holdY);

  List<SpawnOrder> line(
    EnemyKind kind,
    int count,
    double start,
    double gap, {
    double fromX = 46,
    double toX = 254,
    double holdMin = 0,
    double holdMax = 0,
  }) {
    final orders = <SpawnOrder>[];
    for (var i = 0; i < count; i++) {
      final ratio = count == 1 ? 0.5 : i / (count - 1);
      final x = fromX + (toX - fromX) * ratio;
      final holdY = holdMax > 0 ? hold(holdMin, holdMax) : 0.0;
      orders.add(order(start + i * gap, kind, x, holdY: holdY));
    }
    return orders;
  }

  return [
    WavePlan(
      index: 1,
      orders: line(EnemyKind.infantry, 6, 0.2, 0.55),
    ),
    WavePlan(
      index: 2,
      orders: [
        ...line(EnemyKind.infantry, 5, 0.2, 0.5, toX: 220),
        ...line(
          EnemyKind.rifleman,
          2,
          2.4,
          1.1,
          fromX: 70,
          toX: 230,
          holdMin: 80,
          holdMax: 150,
        ),
        ...line(EnemyKind.infantry, 2, 4.0, 0.7, fromX: 120, toX: 190),
      ],
    ),
    WavePlan(
      index: 3,
      orders: [
        ...line(EnemyKind.infantry, 6, 0.2, 0.45),
        ...line(
          EnemyKind.rifleman,
          3,
          1.8,
          0.9,
          fromX: 60,
          toX: 240,
          holdMin: 70,
          holdMax: 140,
        ),
        ...line(
          EnemyKind.grenadier,
          1,
          3.2,
          1,
          fromX: 150,
          holdMin: 100,
          holdMax: 150,
        ),
      ],
    ),
    WavePlan(
      index: 4,
      orders: [
        ...line(EnemyKind.infantry, 7, 0.2, 0.4),
        ...line(
          EnemyKind.rifleman,
          3,
          1.2,
          0.9,
          fromX: 55,
          toX: 245,
          holdMin: 70,
          holdMax: 130,
        ),
        ...line(
          EnemyKind.grenadier,
          2,
          2.6,
          1.2,
          fromX: 90,
          toX: 210,
          holdMin: 95,
          holdMax: 145,
        ),
        order(4.6, EnemyKind.armoredCar, 150, holdY: 95),
      ],
    ),
    WavePlan(
      index: 5,
      boss: true,
      orders: [
        order(0.2, EnemyKind.infantry, 70),
        order(0.9, EnemyKind.infantry, 230),
        order(2.2, EnemyKind.boss, 150, holdY: 78),
      ],
    ),
  ];
}

/// 无尽模式的第 [index] 波：数量与强度逐波增长，每五波一个头目。
WavePlan endlessWave(int index, Difficulty difficulty, {math.Random? random}) {
  final rng = random ?? math.Random(index * 7919);
  final pace = difficulty.paceScale;
  final bossWave = index % kEndlessBossEvery == 0;
  final orders = <SpawnOrder>[];
  final baseScale = 1 + math.max(0, index - 1) * 0.07;
  final hpMultiplier = bossWave
      ? baseScale * (1 + (index ~/ kEndlessBossEvery - 1) * 0.5)
      : baseScale;

  double hold(double min, double max) =>
      min + rng.nextDouble() * (max - min);

  SpawnOrder push(EnemyKind kind, double at, double x, {double holdY = 0}) {
    final order = SpawnOrder(at: at * pace, kind: kind, x: x, holdY: holdY);
    orders.add(order);
    return order;
  }

  final infantry = math.min(4 + index, 14);
  for (var i = 0; i < infantry; i++) {
    push(EnemyKind.infantry, 0.2 + i * 0.42, 40 + rng.nextDouble() * 220);
  }
  final riflemen = math.min(1 + index ~/ 2, 6);
  for (var i = 0; i < riflemen; i++) {
    push(
      EnemyKind.rifleman,
      1.4 + i * 0.85,
      50 + rng.nextDouble() * 200,
      holdY: hold(70, 145),
    );
  }
  final grenadiers = math.min(index ~/ 3, 4);
  for (var i = 0; i < grenadiers; i++) {
    push(
      EnemyKind.grenadier,
      3.0 + i * 1.1,
      70 + rng.nextDouble() * 160,
      holdY: hold(95, 150),
    );
  }
  if (index >= 4) {
    final cars = 1 + (index - 4) ~/ 3;
    for (var i = 0; i < math.min(cars, 3); i++) {
      push(EnemyKind.armoredCar, 4.5 + i * 1.4, 90 + rng.nextDouble() * 120,
          holdY: hold(80, 115));
    }
  }
  if (bossWave) {
    push(
      EnemyKind.boss,
      1.2,
      150,
      holdY: 78,
    );
  }
  return WavePlan(
    index: index,
    orders: orders,
    boss: bossWave,
    hpMultiplier: hpMultiplier,
  );
}
